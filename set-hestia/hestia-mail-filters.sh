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

echo "✅ Готово: филтрите (Sieve/ManageSieve) са активирани. В Roundcube: Настройки → Филтри."

# Самоизтриване
rm -- "$0"
