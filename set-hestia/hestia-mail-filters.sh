#!/usr/bin/env bash
# v1.2 — Roundcube Filters на чист сървър (Ubuntu 24.04 + Hestia)
# Инсталира Dovecot Sieve/ManageSieve и активира Roundcube "Filters"
# Без въпроси (noninteractive), минимални и предсказуеми промени.

set -euo pipefail

ts() { date +%F-%H%M%S; }
say(){ printf '==> %s\n' "$*"; }

export DEBIAN_FRONTEND=noninteractive

# --- Пътища ---
DOVECOT_CONF="/etc/dovecot/dovecot.conf"
DOVECOT_DIR="/etc/dovecot/conf.d"
SIEVE90="${DOVECOT_DIR}/90-sieve.conf"
MSV_LOCAL="${DOVECOT_DIR}/21-managesieve-local.conf"

RC_MAIN="/etc/roundcube/config.inc.php"
RC_PLUG="/etc/roundcube/plugins/managesieve/config.inc.php"
RC_PLUG_DIST="/usr/share/roundcube/plugins/managesieve/config.inc.php.dist"

# --- Изчакай APT lock (ако apt-daily върви) ---
say "Чакам APT lock (ако има)..."
while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 2; done
while sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1; do sleep 2; done

# --- Пакети (тихо, пази локалните конфиги) ---
say "Инсталирам пакети (без въпроси)..."
sudo apt-get -yq update
sudo apt-get -yq install \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confold" \
  dovecot-sieve dovecot-managesieved roundcube-plugins

# --- Dovecot: plugin пътища (90-sieve.conf) ---
say "Пиша ${SIEVE90} ..."
[[ -f "$SIEVE90" ]] && sudo cp -a "$SIEVE90" "${SIEVE90}.bak.$(ts)"
sudo tee "$SIEVE90" >/dev/null <<'EOF'
plugin {
  sieve = ~/.dovecot.sieve
  sieve_dir = ~/sieve
}
EOF

# --- Dovecot: локален ManageSieve listener (21-managesieve-local.conf) ---
say "Пиша ${MSV_LOCAL} ..."
[[ -f "$MSV_LOCAL" ]] && sudo cp -a "$MSV_LOCAL" "${MSV_LOCAL}.bak.$(ts)"
sudo tee "$MSV_LOCAL" >/dev/null <<'EOF'
service managesieve {
  inet_listener sieve {
    port = 4190
  }
}
EOF

# --- Dovecot: добави 'sieve' в protocols (точно веднъж) ---
say "Добавям 'sieve' в protocols..."
if grep -q '^[[:space:]]*protocols[[:space:]]*=' "$DOVECOT_CONF"; then
  sudo sed -E -i 's/\bsieve\b//g; s/  +/ /g' "$DOVECOT_CONF"
  sudo sed -E -i 's/^([[:space:]]*protocols[[:space:]]*=[[:space:]]*.*)$/\1 sieve/' "$DOVECOT_CONF"
else
  echo 'protocols = $protocols sieve' | sudo tee -a "$DOVECOT_CONF" >/dev/null
fi

# --- Валидирай Dovecot конфигурацията ---
say "Валидирам Dovecot конфигурацията..."
sudo doveconf -n >/dev/null

# --- Roundcube: активирай плъгина managesieve ---
say "Активирам Roundcube плъгина 'managesieve'..."
if [[ -f "$RC_MAIN" ]]; then
  sudo cp -a "$RC_MAIN" "${RC_MAIN}.bak.$(ts)"
  if ! grep -qE "\$config\['plugins'\].*managesieve" "$RC_MAIN"; then
    printf "\n\$config['plugins'][] = 'managesieve';\n" | sudo tee -a "$RC_MAIN" >/dev/null
  fi
fi

# --- Roundcube: конфиг на плъгина (localhost:4190, без TLS за локална връзка) ---
say "Настройвам плъгина 'managesieve'..."
if [[ -f "$RC_PLUG_DIST" && ! -f "$RC_PLUG" ]]; then
  sudo install -m 0644 "$RC_PLUG_DIST" "$RC_PLUG"
fi
if [[ -f "$RC_PLUG" ]]; then
  sudo cp -a "$RC_PLUG" "${RC_PLUG}.bak.$(ts)"
  sudo sed -i "s/^\$config\['managesieve_host'\].*/\$config['managesieve_host'] = 'localhost';/" "$RC_PLUG" || true
  sudo sed -i "s/^\$config\['managesieve_port'\].*/\$config['managesieve_port'] = 4190;/" "$RC_PLUG" || true
  if grep -q "managesieve_usetls" "$RC_PLUG"; then
    sudo sed -i "s/^\$config\['managesieve_usetls'\].*/\$config['managesieve_usetls'] = false;/" "$RC_PLUG"
  else
    echo "\$config['managesieve_usetls'] = false;" | sudo tee -a "$RC_PLUG" >/dev/null
  fi
fi

# --- Рестарти ---
say "Рестартирам Dovecot и презареждам web/PHP..."
sudo systemctl restart dovecot
sudo systemctl reload nginx 2>/dev/null || true
sudo systemctl reload apache2 2>/dev/null || true
for svc in $(systemctl list-units --type=service --all | awk '/php.*-fpm\.service/ {print $1}'); do
  sudo systemctl reload "$svc" || true
done

# --- Проверки ---
say "Проверки:"
sudo ss -lntp | awk 'NR==1||/:4190/ {print}'
sudo doveconf -n | grep -i sieve || true
say "Готово. Roundcube → Settings → Filters."

# Самоизтриване
rm -- "$0"
