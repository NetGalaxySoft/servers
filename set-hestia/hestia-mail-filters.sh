#!/usr/bin/env bash
# v1.1 – Roundcube Filters: автоматична инсталация на Dovecot Sieve/ManageSieve
# ОС: Ubuntu 24.04 + Hestia
# Характер: напълно неинтерактивен, операторът не решава нищо

set -euo pipefail

ts() { date +%F-%H%M%S; }

DOVECOT_CONF="/etc/dovecot/dovecot.conf"
DOVECOT_DIR="/etc/dovecot/conf.d"
SIEVE90="${DOVECOT_DIR}/90-sieve.conf"
MSV_LOCAL="${DOVECOT_DIR}/21-managesieve-local.conf"

RC_MAIN="/etc/roundcube/config.inc.php"
RC_PLUG="/etc/roundcube/plugins/managesieve/config.inc.php"
RC_PLUG_DIST="/usr/share/roundcube/plugins/managesieve/config.inc.php.dist"

echo "==> Инсталирам нужните пакети (тихо, без въпроси)..."
export DEBIAN_FRONTEND=noninteractive
sudo apt-get -yq update
sudo apt-get -yq install \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confold" \
  dovecot-sieve dovecot-managesieved roundcube-plugins

echo "==> Конфигурирам Dovecot (90-sieve.conf)..."
[[ -f "$SIEVE90" ]] && sudo cp -a "$SIEVE90" "${SIEVE90}.bak.$(ts)"
sudo tee "$SIEVE90" >/dev/null <<'EOF'
plugin {
  sieve = ~/.dovecot.sieve
  sieve_dir = ~/sieve
}
EOF

echo "==> Добавям локален блок за ManageSieve (21-managesieve-local.conf)..."
[[ -f "$MSV_LOCAL" ]] && sudo cp -a "$MSV_LOCAL" "${MSV_LOCAL}.bak.$(ts)"
sudo tee "$MSV_LOCAL" >/dev/null <<'EOF'
service managesieve {
  inet_listener sieve {
    port = 4190
  }
}
EOF

echo "==> Уверявам се, че 'sieve' е добавен в protocols..."
if grep -q '^[[:space:]]*protocols[[:space:]]*=' "$DOVECOT_CONF"; then
  sudo sed -E -i 's/\bsieve\b//g; s/  +/ /g' "$DOVECOT_CONF"
  sudo sed -E -i 's/^([[:space:]]*protocols[[:space:]]*=[[:space:]]*.*)$/\1 sieve/' "$DOVECOT_CONF"
else
  echo 'protocols = $protocols sieve' | sudo tee -a "$DOVECOT_CONF" >/dev/null
fi

echo "==> Валидирам Dovecot конфигурацията..."
sudo doveconf -n >/dev/null

echo "==> Активирам Roundcube плъгина 'managesieve'..."
if [[ -f "$RC_MAIN" ]]; then
  sudo cp -a "$RC_MAIN" "${RC_MAIN}.bak.$(ts)"
  if ! grep -qE "\$config\['plugins'\].*managesieve" "$RC_MAIN"; then
    if grep -q "\$config\['plugins'\]" "$RC_MAIN"; then
      sudo awk '
        BEGIN{ins=0}
        /\$config\[\x27plugins\x27\]\s*=\s*\[/ && !ins { print; print "    \"managesieve\","; ins=1; next }
        {print}
      ' "$RC_MAIN" | sudo tee /tmp/rc.conf.new >/dev/null
      sudo mv /tmp/rc.conf.new "$RC_MAIN"
    else
      printf "\n\$config['plugins'][] = 'managesieve';\n" | sudo tee -a "$RC_MAIN" >/dev/null
    fi
  fi
fi

echo "==> Настройвам плъгина 'managesieve' (localhost:4190, без TLS)..."
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

echo "==> Рестартирам услуги..."
sudo systemctl restart dovecot
sudo systemctl reload nginx 2>/dev/null || true
sudo systemctl reload apache2 2>/dev/null || true
for svc in $(systemctl list-units --type=service --all | awk '/php.*-fpm\.service/ {print $1}'); do
  sudo systemctl reload "$svc" || true
done

echo "==> Проверки:"
echo "- dovecot: $(systemctl is-active dovecot) / $(systemctl is-enabled dovecot)"
echo "- LISTEN 4190:"; sudo ss -lntp | awk 'NR==1||/:4190/ {print}'

echo "Готово. Отворете Roundcube → Settings → Filters."
rm -- "$0"
