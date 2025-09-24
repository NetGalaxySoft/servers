#!/usr/bin/env bash
# hestia-fm-speedfix.sh (fixed, idempotent)
set -euo pipefail

# --- Пътища / двоични ---
NGINX_CONF="/usr/local/hestia/nginx/conf/nginx.conf"
NGINX_BIN="/usr/local/hestia/nginx/sbin/hestia-nginx"
PHP_BIN="/usr/local/hestia/php/bin/php"
PHP_POOL="/usr/local/hestia/php/etc/php-fpm.d/www.conf"   # може да липсва на някои версии
TS="$(date +%Y%m%d-%H%M%S)"

# --- Проверки ---
[ -x "$NGINX_BIN" ] || { echo "❌ Няма $NGINX_BIN"; exit 1; }
[ -x "$PHP_BIN" ]   || { echo "❌ Няма $PHP_BIN";   exit 1; }
[ -f "$NGINX_CONF" ] || { echo "❌ Липсва $NGINX_CONF"; exit 1; }

# --- Бекапи (само веднъж на файл) ---
backup_once() { f="$1"; [ -f "$f" ] && [ ! -f "${f}.bak-${TS}" ] && sudo cp -a "$f" "${f}.bak-${TS}" || true; }
backup_once "$NGINX_CONF"
[ -f "$PHP_POOL" ] && backup_once "$PHP_POOL" || true

# --- Авто-откриване/създаване на php.ini на панелния PHP ---
PHP_INI="$("$PHP_BIN" -i | awk -F'=> ' '/^Loaded Configuration File/ {print $2}')"
if [ "$PHP_INI" = "(none)" ] || [ -z "$PHP_INI" ]; then
  PHP_INI_DIR="$("$PHP_BIN" -i | awk -F'=> ' '/^Configuration File \(php.ini\) Path/ {print $2}')"
  PHP_INI="${PHP_INI_DIR%/}/php.ini"
fi
sudo mkdir -p "$(dirname "$PHP_INI")"
if [ ! -f "$PHP_INI" ]; then
  if [ -f "$(dirname "$PHP_INI")/php.ini-production" ]; then
    sudo cp "$(dirname "$PHP_INI")/php.ini-production" "$PHP_INI"
  else
    sudo install -m0644 /dev/null "$PHP_INI"
  fi
fi
backup_once "$PHP_INI"

# --- Помощници ---
set_ini () { # set_ini key value
  local k="$1" v="$2"
  if sudo grep -qE "^[[:space:]]*${k}[[:space:]]*=" "$PHP_INI"; then
    sudo sed -i -E "s#^[[:space:]]*${k}[[:space:]]*=.*#${k} = ${v}#g" "$PHP_INI"
  else
    echo "${k} = ${v}" | sudo tee -a "$PHP_INI" >/dev/null
  fi
}

# --- Nginx: почисти стари блокове (ако скриптът е пускан преди) ---
# http{} маркери
sudo sed -i '/# --- speedfix (Hestia FM) ---/,/# --- end speedfix ---/d' "$NGINX_CONF"
# server:8083 маркери
sudo sed -i '/# --- speedfix (Hestia FM, server:8083) ---/,/# --- end speedfix ---/d' "$NGINX_CONF"

# --- Nginx: инжектиране в server{} който слуша 8083 ---
sudo awk '
  BEGIN{in_srv=0; added=0}
  /server\s*{/ {in_srv=1}
  in_srv && /listen[ \t].*8083/ && !added {
      print $0
      print "    # --- speedfix (Hestia FM, server:8083) ---"
      print "    client_max_body_size 4g;"
      print "    client_body_buffer_size 512k;"
      print "    gzip off;"
      print "    fastcgi_read_timeout 300s;"
      print "    fastcgi_request_buffering off;"
      print "    proxy_buffering off;"
      print "    proxy_request_buffering off;"
      print "    # --- end speedfix ---"
      next
  }
  /}/ && in_srv {in_srv=0}
  {print}
' "$NGINX_CONF" | sudo tee "${NGINX_CONF}.tmp" >/dev/null && sudo mv "${NGINX_CONF}.tmp" "$NGINX_CONF"

# --- PHP (панелен) лимити ---
set_ini upload_max_filesize 2048M
set_ini post_max_size      2048M
set_ini max_execution_time 300
set_ini max_input_time     300
set_ini memory_limit       512M
set_ini output_buffering   Off

# --- PHP-FPM pool (ако го има) ---
if [ -f "$PHP_POOL" ]; then
  sudo sed -i -E '
    s/^;?[[:space:]]*pm[[:space:]]*=[[:space:]]*\w+/pm = dynamic/g;
    s/^;?[[:space:]]*pm\.max_children[[:space:]]*=.*/pm.max_children = 40/g;
    s/^;?[[:space:]]*pm\.start_servers[[:space:]]*=.*/pm.start_servers = 6/g;
    s/^;?[[:space:]]*pm\.min_spare_servers[[:space:]]*=.*/pm.min_spare_servers = 4/g;
    s/^;?[[:space:]]*pm\.max_spare_servers[[:space:]]*=.*/pm.max_spare_servers = 12/g;
    s/^;?[[:space:]]*request_terminate_timeout[[:space:]]*=.*/request_terminate_timeout = 300s/g;
    s/^;?[[:space:]]*request_slowlog_timeout[[:space:]]*=.*/request_slowlog_timeout = 10s/g;
  ' "$PHP_POOL"
fi

# --- Тест и рестарт ---
sudo "$NGINX_BIN" -t
sudo systemctl restart hestia

echo "✅ Hestia FM speedfix приложен. Бекапи: *.bak-${TS}"
rm -- "$0"
