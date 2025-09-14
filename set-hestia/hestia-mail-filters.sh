#!/usr/bin/env bash
# Roundcube Filters: Dovecot Sieve + ManageSieve enable & wire-up
# Ubuntu 24.04 / Dovecot 2.3+ / Roundcube (HestiaCP OK)
set -euo pipefail

echo "==> Инсталирам Sieve/ManageSieve за Dovecot..."
sudo apt-get update -y
sudo apt-get install -y dovecot-sieve dovecot-managesieved

echo "==> Активирам sieve плъгина за LDA/LMTP..."
# LDA (deliver)
if [[ -f /etc/dovecot/conf.d/15-lda.conf ]]; then
  sudo sed -i 's/^\s*#\?\s*mail_plugins\s*=\s*.*/mail_plugins = \$mail_plugins sieve/' /etc/dovecot/conf.d/15-lda.conf
fi
# LMTP
if [[ -f /etc/dovecot/conf.d/20-lmtp.conf ]]; then
  sudo sed -i 's/^\s*#\?\s*mail_plugins\s*=\s*.*/mail_plugins = \$mail_plugins sieve/' /etc/dovecot/conf.d/20-lmtp.conf
fi

echo "==> Дефинирам път за потребителските Sieve филтри..."
sudo awk '
/^plugin\s*\{/ { inplug=1 }
inplug && /^\}/ { inplug=0 }
{ print }
/^plugin\s*\{/ && inplug==0 { }
' /etc/dovecot/conf.d/90-sieve.conf >/tmp/90-sieve.conf.new || true

if ! grep -q "plugin {" /tmp/90-sieve.conf.new 2>/dev/null; then
  # Файлът е празен или липсва секция plugin – създаваме минимален конфиг
  cat <<'EOF' | sudo tee /tmp/90-sieve.conf.new >/dev/null
plugin {
  sieve = ~/.dovecot.sieve
  sieve_dir = ~/sieve
}
EOF
else
  # Заменяме/вкарваме ключовете вътре в plugin { ... }
  sudo awk '
BEGIN{set=0}
{
  print
}
/^plugin\s*\{/ {inplug=1}
inplug && $0 ~ /sieve\s*=/ { $0="  sieve = ~/.dovecot.sieve"; set=1 }
inplug && $0 ~ /sieve_dir\s*=/ { $0="  sieve_dir = ~/sieve"; set=1 }
inplug && /^\}/ && set==0 { print "  sieve = ~/.dovecot.sieve"; print "  sieve_dir = ~/sieve" }
inplug && /^\}/ { inplug=0 }
' /etc/dovecot/conf.d/90-sieve.conf > /tmp/90-sieve.conf.patched
  sudo mv /tmp/90-sieve.conf.patched /tmp/90-sieve.conf.new
fi
sudo mv /tmp/90-sieve.conf.new /etc/dovecot/conf.d/90-sieve.conf

echo "==> Включвам ManageSieve (порт 4190) в 20-managesieve.conf..."
sudo sed -i 's/^\s*#\s*protocols\s*=.*/protocols = $protocols sieve/' /etc/dovecot/dovecot.conf || true

# Увери се, че listener-ът е активен
sudo sed -i \
  -e 's/^\s*#\s*service managesieve\s*{.*/service managesieve {\n  inet_listener sieve { port = 4190 }\n}/' \
  -e 's/^\s*service managesieve\s*{.*/service managesieve {\n  inet_listener sieve { port = 4190 }\n}/' \
  /etc/dovecot/conf.d/20-managesieve.conf

# Ако редът липсва напълно, добавяме секция:
grep -q "service managesieve" /etc/dovecot/conf.d/20-managesieve.conf || \
  sudo bash -c 'cat >>/etc/dovecot/conf.d/20-managesieve.conf <<EOF

service managesieve {
  inet_listener sieve {
    port = 4190
  }
}
EOF'

echo "==> Създавам директории/линкове по подразбиране за текущи потребители (по избор)..."
# Това е само демонстрационно. Реалните пощенски потребители ще си ги имат автоматично.
for HOME_DIR in /home/*; do
  [[ -d "$HOME_DIR" ]] || continue
  if [[ ! -d "$HOME_DIR/sieve" ]]; then
    sudo mkdir -p "$HOME_DIR/sieve"
    sudo chown -R "$(stat -c %U:%G "$HOME_DIR")" "$HOME_DIR/sieve"
    sudo chmod 700 "$HOME_DIR/sieve"
  fi
done

echo "==> Рестартирам Dovecot..."
sudo systemctl restart dovecot
sudo systemctl enable dovecot

echo "==> Проверка на конфигурацията (doveconf -n | grep -i sieve):"
doveconf -n | grep -i sieve || true

echo "==> Roundcube: активирам плъгина managesieve..."
RC_MAIN="/etc/roundcube/config.inc.php"
RC_PLUG="/etc/roundcube/plugins/managesieve/config.inc.php"
RC_PLUG_DIST="/usr/share/roundcube/plugins/managesieve/config.inc.php.dist"

# Активиране на плъгина в глобалния конфиг
if [[ -f "$RC_MAIN" ]]; then
  sudo cp -a "$RC_MAIN" "${RC_MAIN}.bak.$(date +%F-%H%M%S)"
  if grep -q "plugins.*managesieve" "$RC_MAIN"; then
    : # вече е активиран
  else
    sudo awk '
      BEGIN{done=0}
      /\$config\[\x27plugins\x27\]\s*=\s*\[/ && done==0 {
        print
        print "    \"managesieve\","
        done=1
        next
      }
      {print}
    ' "$RC_MAIN" | sudo tee /tmp/rc.conf.new >/dev/null
    sudo mv /tmp/rc.conf.new "$RC_MAIN"
  fi
fi

# Конфиг на плъгина
if [[ -f "$RC_PLUG_DIST" ]]; then
  sudo install -m 0644 "$RC_PLUG_DIST" "$RC_PLUG"
fi

if [[ -f "$RC_PLUG" ]]; then
  sudo cp -a "$RC_PLUG" "${RC_PLUG}.bak.$(date +%F-%H%M%S)"
  sudo sed -i "s/^\$config\['managesieve_host'\].*/\$config['managesieve_host'] = 'localhost';/" "$RC_PLUG"
  sudo sed -i "s/^\$config\['managesieve_port'\].*/\$config['managesieve_port'] = 4190;/" "$RC_PLUG"
  # На localhost STARTTLS не е нужен; ако искаш – смени на true
  if grep -q "managesieve_usetls" "$RC_PLUG"; then
    sudo sed -i "s/^\$config\['managesieve_usetls'\].*/\$config['managesieve_usetls'] = false;/" "$RC_PLUG"
  else
    echo "\$config['managesieve_usetls'] = false;" | sudo tee -a "$RC_PLUG" >/dev/null
  fi
  # По желание: глобални скриптове (ако използваш)
  grep -q "managesieve_default" "$RC_PLUG" || echo "\$config['managesieve_default'] = null;" | sudo tee -a "$RC_PLUG" >/dev/null
fi

echo "==> Рестарт на уеб услугите (Hestia окружение)..."
# В Hestia Roundcube върви зад nginx+apache; достатъчен е PHP-FPM рестарт, но не вреди:
sudo systemctl reload nginx || true
sudo systemctl reload apache2 || true
sudo systemctl reload php*-fpm.service || true

echo "==> Бързи проверки:"
echo " - dovecot.service: $(systemctl is-active dovecot)"
echo " - LISTEN 4190: "; sudo ss -lntp | awk '/:4190/ || NR==1 {print}'
echo "Готово."
