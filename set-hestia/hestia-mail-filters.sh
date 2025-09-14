#!/bin/bash
# Активиране на пощенски филтри: Dovecot Sieve/ManageSieve + Roundcube managesieve
set -euo pipefail

echo "==> Инсталирам пакети dovecot-sieve и dovecot-managesieved..."
sudo apt update
sudo apt install -y dovecot-sieve dovecot-managesieved

# 1) Включи sieve за LDA или LMTP (според наличните конфиги)
if [[ -f /etc/dovecot/conf.d/20-lmtp.conf ]]; then
  echo "==> Открит е 20-lmtp.conf – включвам sieve за LMTP..."
  sudo sed -i 's/^#*\s*mail_plugins = .*/mail_plugins = $mail_plugins sieve/' /etc/dovecot/conf.d/20-lmtp.conf
else
  echo "==> Няма 20-lmtp.conf – включвам sieve за LDA в 15-lda.conf..."
  if grep -q '^\s*mail_plugins\s*=' /etc/dovecot/conf.d/15-lda.conf; then
    sudo sed -i 's/^\s*mail_plugins\s*=.*/mail_plugins = $mail_plugins sieve/' /etc/dovecot/conf.d/15-lda.conf
  else
    printf "\nprotocol lda {\n  mail_plugins = \$mail_plugins sieve\n}\n" | sudo tee -a /etc/dovecot/conf.d/15-lda.conf >/dev/null
  fi
fi

# 2) Увери се, че ManageSieve услугата е налична (порт 4190)
if ! grep -q "service managesieve-login" /etc/dovecot/conf.d/20-managesieve.conf 2>/dev/null; then
  echo "==> Създавам 20-managesieve.conf..."
  sudo tee /etc/dovecot/conf.d/20-managesieve.conf >/dev/null <<'EOF'
service managesieve-login {
  inet_listener sieve {
    port = 4190
  }
}
service managesieve {}
protocol sieve {
  managesieve_max_line_length = 65536
}
EOF
fi

# 3) Настройки за пътищата на Sieve (скриптовете на потребителя)
if ! grep -q "plugin {" /etc/dovecot/conf.d/90-sieve.conf 2>/dev/null; then
  echo "==> Създавам 90-sieve.conf..."
  sudo tee /etc/dovecot/conf.d/90-sieve.conf >/dev/null <<'EOF'
plugin {
  sieve = ~/.dovecot.sieve
  sieve_dir = ~/sieve
}
EOF
fi

# 4) Глобално включи протокола sieve в Dovecot
sudo sed -i 's/^#\?\s*protocols\s*=.*/protocols = imap pop3 sieve/' /etc/dovecot/dovecot.conf

echo "==> Рестартирам Dovecot..."
sudo systemctl restart dovecot

# Проверка за слушащ порт 4190
sudo ss -ltnp | grep -q ':4190' && echo "✅ Dovecot managesieve слуша на порт 4190" || echo "⚠️  NO_LISTEN_4190"

# 5) Активирай плъгина managesieve в Roundcube (идемпотентно)
RC_CONF="/etc/roundcube/config.inc.php"
if [[ -f "$RC_CONF" ]]; then
  if grep -qE '\bmanagesieve\b' "$RC_CONF"; then
    echo "==> Roundcube: managesieve вече е активен."
  else
    echo "==> Активирам managesieve в $RC_CONF (бекъп ще бъде създаден)..."
    sudo cp -a "$RC_CONF" "$RC_CONF.bak" || true
    # Формат: $config["plugins"] = [];
    sudo sed -i -E 's/(\$config\[[\"\047]plugins[\"\047]\]\s*=\s*)\[\s*\](\s*;)/\1["managesieve"]\2/' "$RC_CONF"
    # Формат: $config["plugins"] = ["a","b"];
    sudo sed -i -E 's/(\$config\[[\"\047]plugins[\"\047]\]\s*=\s*\[[^]]*?)\s*\](\s*;)/\1, "managesieve"]\2/' "$RC_CONF"
    # Формат: $config['plugins'] = array();
    sudo sed -i -E "s/(\$config\[['\"]plugins['\"]\]\s*=\s*array\s*)\(\s*\)(\s*;)/\1('managesieve')\2/" "$RC_CONF"
    # Формат: $config['plugins'] = array('a','b');
    sudo sed -i -E "s/(\$config\[['\"]plugins['\"]\]\s*=\s*array\s*\([^)']*)(\))(\s*;)/\1, 'managesieve'\2\3/" "$RC_CONF"

    if grep -qE '\bmanagesieve\b' "$RC_CONF"; then
      echo "✅ Roundcube: managesieve е активиран."
    else
      echo "❌ Roundcube: активирането на managesieve не успя – провери $RC_CONF и бекъп $RC_CONF.bak"
      exit 1
    fi
  fi
else
  echo "⚠️  Roundcube: конфигурацията липсва ($RC_CONF) – пропускам активиране на managesieve."
fi

# --- Roundcube managesieve: конфигурация на връзката към локалния сървър ---
RC_MS_DIR="/etc/roundcube/plugins/managesieve"
RC_MS_CONF="$RC_MS_DIR/config.inc.php"

sudo mkdir -p "$RC_MS_DIR"

if [[ ! -f "$RC_MS_CONF" ]]; then
  sudo tee "$RC_MS_CONF" >/dev/null <<'PHP'
<?php
$config['managesieve_host'] = '127.0.0.1';
$config['managesieve_port'] = 4190;
$config['managesieve_usetls'] = false;
$config['managesieve_default'] = '~/.dovecot.sieve';
$config['managesieve_script_name'] = 'roundcube';
PHP
  echo "✅ Roundcube: създаден $RC_MS_CONF"
else
  # Идемпотентно задай/коригирай ключовете
  sudo sed -i -E "s/^\s*\$config\['managesieve_host'\].*$/\$config['managesieve_host'] = '127.0.0.1';/g" "$RC_MS_CONF" || true
  sudo sed -i -E "s/^\s*\$config\['managesieve_port'\].*$/\$config['managesieve_port'] = 4190;/g" "$RC_MS_CONF" || true
  sudo sed -i -E "s/^\s*\$config\['managesieve_usetls'\].*$/\$config['managesieve_usetls'] = false;/g" "$RC_MS_CONF" || true
  sudo sed -i -E "s/^\s*\$config\['managesieve_default'\].*$/\$config['managesieve_default'] = '~\/.dovecot.sieve';/g" "$RC_MS_CONF" || true
  sudo sed -i -E "s/^\s*\$config\['managesieve_script_name'\].*$/\$config['managesieve_script_name'] = 'roundcube';/g" "$RC_MS_CONF" || true

  # Ако някой ключ липсва напълно, добави го в края
  grep -q "managesieve_host" "$RC_MS_CONF" || echo "\$config['managesieve_host'] = '127.0.0.1';"       | sudo tee -a "$RC_MS_CONF" >/dev/null
  grep -q "managesieve_port" "$RC_MS_CONF" || echo "\$config['managesieve_port'] = 4190;"               | sudo tee -a "$RC_MS_CONF" >/dev/null
  grep -q "managesieve_usetls" "$RC_MS_CONF" || echo "\$config['managesieve_usetls'] = false;"          | sudo tee -a "$RC_MS_CONF" >/dev/null
  grep -q "managesieve_default" "$RC_MS_CONF" || echo "\$config['managesieve_default'] = '~/.dovecot.sieve';" | sudo tee -a "$RC_MS_CONF" >/dev/null
  grep -q "managesieve_script_name" "$RC_MS_CONF" || echo "\$config['managesieve_script_name'] = 'roundcube';" | sudo tee -a "$RC_MS_CONF" >/dev/null

  echo "✅ Roundcube: актуализиран $RC_MS_CONF"
fi

# Рестарт на уеб слоя (зависи от стека) — try-restart, без да гърми при липсваща услуга
sudo systemctl try-restart apache2 2>/dev/null || true
sudo systemctl try-restart nginx 2>/dev/null || true
for s in php7.4-fpm php8.0-fpm php8.1-fpm php8.2-fpm php8.3-fpm php8.4-fpm; do
  sudo systemctl try-restart "$s" 2>/dev/null || true
done

# Бърза проверка на managesieve порта
sudo ss -ltnp | grep -q ':4190' && echo "✅ Managesieve (4190) слуша" || echo "⚠️  Managesieve (4190) не слуша"


echo "✅ Готово: филтрите (Sieve/ManageSieve) са активирани. В Roundcube: Настройки → Филтри."

# Самоизтриване
rm -- "$0"
