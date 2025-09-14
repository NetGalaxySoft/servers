#!/usr/bin/env bash
# v1.0 (нов сървър) — Roundcube Filters: Dovecot Sieve/ManageSieve + Roundcube managesieve
# ОС: Ubuntu 24.04, HestiaCP съвместим
# Характер: неинтерактивен, минимални промени, с резервни копия

set -euo pipefail

# ----- Пътища -----
DOVECOT_CONF="/etc/dovecot/dovecot.conf"
DOVECOT_DIR="/etc/dovecot/conf.d"
SIEVE90="${DOVECOT_DIR}/90-sieve.conf"
MSV_LOCAL="${DOVECOT_DIR}/21-managesieve-local.conf"

RC_MAIN="/etc/roundcube/config.inc.php"
RC_PLUG="/etc/roundcube/plugins/managesieve/config.inc.php"
RC_PLUG_DIST="/usr/share/roundcube/plugins/managesieve/config.inc.php.dist"

ts() { date +%F-%H%M%S; }

echo "==> Инсталирам пакети..."
sudo apt-get update -y
sudo apt-get install -y dovecot-sieve dovecot-managesieved roundcube-plugins || true

echo "==> Dovecot: plugin пътища (90-sieve.conf)..."
if [[ -f "$SIEVE90" ]]; then sudo cp -a "$SIEVE90" "${SIEVE90}.bak.$(ts)"; fi
sudo tee "$SIEVE90" >/dev/null <<'EOF'
plugin {
  sieve = ~/.dovecot.sieve
  sieve_dir = ~/sieve
}
EOF

echo "==> Dovecot: локален ManageSieve блок (21-managesieve-local.conf)..."
if [[ -f "$MSV_LOCAL" ]]; then sudo cp -a "$MSV_LOCAL" "${MSV_LOCAL}.bak.$(ts)"; fi
sudo tee "$MSV_LOCAL" >/dev/null <<'EOF'
service managesieve {
  inet_listener sieve {
    port = 4190
  }
}
EOF

echo "==> Dovecot: добавям 'sieve' в protocols (точно веднъж)..."
if grep -q '^[[:space:]]*protocols[[:space:]]*=' "$DOVECOT_CONF"; then
  # премахни евентуални стари “sieve” и добави един накрая
  sudo sed -E -i 's/^([[:space:]]*protocols[[:space:]]*=[[:space:]]*)(.*)$/\1\2/; s/\bsieve\b//g; s/  +/ /g' "$DOVECOT_CONF"
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
      # Вкарай в масива
      sudo awk '
        BEGIN{ins=0}
        /\$config\[\x27plugins\x27\]\s*=\s*\[/ && !ins { print; print "    \"managesieve\","; ins=1; next }
        {print}
      ' "$RC_MAIN" | sudo tee /tmp/rc.conf.new >/dev/null
      sudo mv /tmp/rc.conf.new "$RC_MAIN"
    else
      # Ако няма масив, добави append ред
      printf "\n\$config['plugins'][] = 'managesieve';\n" | sudo tee -a "$RC_MAIN" >/dev/null
    fi
  fi
else
  echo "!! Не открих $RC_MAIN — проверете инсталацията на Roundcube." >&2
fi

echo "==> Конфиг на плъгина 'managesieve' (localhost:4190, без TLS за локална връзка)..."
if [[ -f "$RC_PLUG_DIST" && ! -f "$RC_PLUG" ]]; then
  sudo install -m 0644 "$RC_PLUG_DIST" "$RC_PLUG"
elif [[ ! -f "$RC_PLUG_DIST" && ! -f "$RC_PLUG" ]]; then
  echo "!! Липсва $RC_PLUG_DIST — пакетът с плъгини може да не е наличен." >&2
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

