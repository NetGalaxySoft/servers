#!/usr/bin/env bash
# hestia-fm-speedfix.sh
# Оптимизация на скоростта на качване/сваляне във файловия мениджър на Hestia.
# Тествано за Debian/Ubuntu с HestiaCP. Работи без интеракция.

set -euo pipefail

# Пътища на панелния Nginx/PHP в Hestia
NGINX_MAIN="/usr/local/hestia/nginx/conf/nginx.conf"
NGINX_SITES_DIR="/usr/local/hestia/nginx/conf"
PHP_INI="/usr/local/hestia/php/etc/php.ini"
PHP_FPM_POOL="/usr/local/hestia/php/etc/php-fpm.d/www.conf"

ts="$(date +%Y%m%d-%H%M%S)"

backup_file() {
  local f="$1"
  if [ -f "$f" ]; then
    sudo cp -a "$f" "${f}.bak-${ts}"
  fi
}

echo "[*] Създавам резервни копия..."
backup_file "$NGINX_MAIN"
backup_file "$PHP_INI"
backup_file "$PHP_FPM_POOL"

# 1) Тунинг на панелния Nginx (глобален http{} и server на 8083)
echo "[*] Прилагам настройки към панелния Nginx..."

# Уверяваме се, че в http{} има ключови производителни директиви
sudo awk '
BEGIN{in_http=0}
{
  if ($0 ~ /^\s*http\s*{/) in_http=1
  if (in_http && $0 ~ /^\s*}/) in_http=0
  print $0
  if ($0 ~ /^\s*http\s*{/ && !done){
    print "    # --- speedfix (Hestia FM) ---"
    print "    sendfile on;"
    print "    tcp_nopush on;"
    print "    tcp_nodelay on;"
    print "    keepalive_timeout 65;"
    print "    types_hash_max_size 4096;"
    print "    client_max_body_size 4g;"
    print "    client_body_buffer_size 512k;"
    print "    client_body_timeout 300s;"
    print "    client_header_timeout 60s;"
    print "    send_timeout 300s;"
    print "    aio on;"
    print "    directio 4m;"
    print "    # --- end speedfix ---"
    done=1
  }
}' "$NGINX_MAIN" | sudo tee "$NGINX_MAIN.tmp" > /dev/null

sudo mv "$NGINX_MAIN.tmp" "$NGINX_MAIN"

# В server {} на 8083 добавяме специфичните директиви
# (често е дефиниран в същия nginx.conf на Hestia)
if ! grep -q "server_name _; # hestia-panel" "$NGINX_MAIN" 2>/dev/null; then
  echo "[i] Не намерих маркер за server{} на панела; все пак ще инжектирам директивите в първия server{} на 8083."
fi

sudo awk '
BEGIN{in_server=0; matched=0}
/server\s*{/ { if (!in_server) { in_server=1 } }
/}/ { if (in_server) { in_server=0 } }
{
  print $0
  if (in_server && $0 ~ /listen\s+.*8083/) {
    if (!matched) {
      print "    # --- speedfix (Hestia FM, server:8083) ---"
      print "    client_max_body_size 4g;"
      print "    client_body_buffer_size 512k;"
      print "    gzip off;"
      print "    # За fastcgi към php-fpm на панела:"
      print "    fastcgi_read_timeout 300s;"
      print "    fastcgi_request_buffering off;"
      print "    # Забраняваме излишно буфериране при големи качвания"
      print "    proxy_buffering off;"
      print "    proxy_request_buffering off;"
      print "    # --- end speedfix ---"
      matched=1
    }
  }
}' "$NGINX_MAIN" | sudo tee "$NGINX_MAIN.tmp" > /dev/null

sudo mv "$NGINX_MAIN.tmp" "$NGINX_MAIN"

# 2) Тунинг на PHP (панелния php на Hestia)
echo "[*] Прилагам настройки към Hestia PHP..."

apply_php_ini() {
  local key="$1" val="$2"
  if sudo grep -qE "^\s*${key}\s*=" "$PHP_INI"; then
    sudo sed -i -E "s#^\s*${key}\s*=.*#${key} = ${val}#g" "$PHP_INI"
  else
    echo "${key} = ${val}" | sudo tee -a "$PHP_INI" > /dev/null
  fi
}
apply_php_ini "upload_max_filesize" "2048M"
apply_php_ini "post_max_size"      "2048M"
apply_php_ini "max_execution_time" "300"
apply_php_ini "max_input_time"     "300"
apply_php_ini "memory_limit"       "512M"
apply_php_ini "output_buffering"   "Off"

# 3) Тунинг на PHP-FPM пула (панела) – повече процеси и по-големи заявки
if [ -f "$PHP_FPM_POOL" ]; then
  sudo sed -i -E '
    s/^;?\s*pm\s*=\s*\w+/pm = dynamic/g;
    s/^;?\s*pm\.max_children\s*=.*/pm.max_children = 40/g;
    s/^;?\s*pm\.start_servers\s*=.*/pm.start_servers = 6/g;
    s/^;?\s*pm\.min_spare_servers\s*=.*/pm.min_spare_servers = 4/g;
    s/^;?\s*pm\.max_spare_servers\s*=.*/pm.max_spare_servers = 12/g;
    s/^;?\s*request_terminate_timeout\s*=.*/request_terminate_timeout = 300s/g;
    s/^;?\s*request_slowlog_timeout\s*=.*/request_slowlog_timeout = 10s/g;
  ' "$PHP_FPM_POOL"
fi

# 4) Рестарт на панела
echo "[*] Рестартирам панела на Hestia..."
sudo systemctl restart hestia-php-fpm 2>/dev/null || true
sudo systemctl restart hestia-php 2>/dev/null || true
sudo systemctl restart hestia-nginx 2>/dev/null || true
sudo systemctl restart hestia 2>/dev/null || true

echo "✅ Готово. Настройките са приложени."
echo "   При нужда от rollback върни .bak-${ts} файловете и рестартирай hestia."
