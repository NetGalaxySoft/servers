#!/bin/bash

# --- Fix: enable Sieve without relying on audit functions ---

set -e

echo "==> Инсталирам пакети dovecot-sieve и dovecot-managesieved..."
apt update
apt install -y dovecot-sieve dovecot-managesieved

# 1) Включи sieve в LDA (ако няма LMTP файл)
if [ -f /etc/dovecot/conf.d/20-lmtp.conf ]; then
  echo "==> Открит е 20-lmtp.conf – включвам sieve за LMTP..."
  sed -i 's/^#*\s*mail_plugins = .*/mail_plugins = $mail_plugins sieve/' /etc/dovecot/conf.d/20-lmtp.conf
else
  echo "==> Няма 20-lmtp.conf – включвам sieve за LDA в 15-lda.conf..."
  if grep -q '^\s*mail_plugins\s*=' /etc/dovecot/conf.d/15-lda.conf; then
    sed -i 's/^\s*mail_plugins\s*=.*/mail_plugins = $mail_plugins sieve/' /etc/dovecot/conf.d/15-lda.conf
  else
    printf "\nprotocol lda {\n  mail_plugins = \$mail_plugins sieve\n}\n" >> /etc/dovecot/conf.d/15-lda.conf
  fi
fi

# 2) Увери се, че ManageSieve услугата е налична
if ! grep -q "service managesieve-login" /etc/dovecot/conf.d/20-managesieve.conf 2>/dev/null; then
  echo "==> Създавам 20-managesieve.conf..."
  cat >/etc/dovecot/conf.d/20-managesieve.conf <<'EOF'
service managesieve-login {
  inet_listener sieve {
    port = 4190
  }
}
service managesieve {
}
protocol sieve {
  managesieve_max_line_length = 65536
}
EOF
fi

# 3) Настройки за пътищата на Sieve
if ! grep -q "plugin {" /etc/dovecot/conf.d/90-sieve.conf 2>/dev/null; then
  echo "==> Създавам 90-sieve.conf..."
  cat >/etc/dovecot/conf.d/90-sieve.conf <<'EOF'
plugin {
  sieve = ~/.dovecot.sieve
  sieve_dir = ~/sieve
}
EOF
fi

echo "==> Рестартирам Dovecot..."
systemctl restart dovecot

# 4) Активирай плъгина managesieve в Roundcube (идемпотентно)
RC_CONF="/etc/roundcube/config.inc.php"
if [ -f "$RC_CONF" ]; then
  if grep -qE '\bmanagesieve\b' "$RC_CONF"; then
    echo "==> Roundcube: managesieve вече е активен."
  else
    echo "==> Активирам managesieve в $RC_CONF (бекъп ще бъде създаден)..."
    cp -a "$RC_CONF" "$RC_CONF.bak" || true
    # Формат: $config["plugins"] = [];
    sed -i -E 's/(\$config\[[\"\047]plugins[\"\047]\]\s*=\s*)\[\s*\](\s*;)/\1["managesieve"]\2/' "$RC_CONF"
    # Формат: $config["plugins"] = ["a","b"];
    sed -i -E 's/(\$config\[[\"\047]plugins[\"\047]\]\s*=\s*\[[^]]*?)\s*\](\s*;)/\1, "managesieve"]\2/' "$RC_CONF"
    # Формат: $config['plugins'] = array();
    sed -i -E "s/(\$config\[['\"]plugins['\"]\]\s*=\s*array\s*)\(\s*\)(\s*;)/\1('managesieve')\2/" "$RC_CONF"
    # Формат: $config['plugins'] = array('a','b');
    sed -i -E "s/(\$config\[['\"]plugins['\"]\]\s*=\s*array\s*\([^)']*)(\))(\s*;)/\1, 'managesieve'\2\3/" "$RC_CONF"
    if grep -qE '\bmanagesieve\b' "$RC_CONF"; then
      echo "==> Roundcube: managesieve е активиран."
    else
      echo "!! Roundcube: активирането на managesieve не успя – провери $RC_CONF и бекъп $RC_CONF.bak"
      exit 1
    fi
  fi
else
  echo "!! Roundcube: конфигурацията липсва ($RC_CONF) – пропускам активиране на managesieve."
fi

echo "✅ Готово: филтрите (Sieve/ManageSieve) са активирани. В Roundcube: Настройки → Филтри."

rm -- "$0"

