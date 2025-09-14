#!/bin/bash

# --- Mail Filters (Dovecot Sieve / ManageSieve + Roundcube) ---

echo "==> Настройка на филтри (Sieve / ManageSieve) за Dovecot и Roundcube..."

# Инсталиране на нужните пакети
sudo apt update
sudo apt install -y dovecot-sieve dovecot-managesieved

# Включване на sieve плъгина за LMTP
sudo sed -i 's/^#*\s*mail_plugins = .*/mail_plugins = $mail_plugins sieve/' /etc/dovecot/conf.d/20-lmtp.conf

# Активиране на ManageSieve услугата
if ! grep -q "service managesieve-login" /etc/dovecot/conf.d/20-managesieve.conf; then
  cat <<'EOF' | sudo tee /etc/dovecot/conf.d/20-managesieve.conf >/dev/null
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

# Настройка на Sieve директориите за потребителите
if ! grep -q "plugin {" /etc/dovecot/conf.d/90-sieve.conf; then
  cat <<'EOF' | sudo tee /etc/dovecot/conf.d/90-sieve.conf >/dev/null
plugin {
  sieve = ~/.dovecot.sieve
  sieve_dir = ~/sieve
}
EOF
fi

# Рестарт на Dovecot
sudo systemctl restart dovecot

# Активиране на Roundcube managesieve плъгина
RC_CONF="/etc/roundcube/config.inc.php"
if sudo test -f "$RC_CONF"; then
  sudo sed -i "s/^\(\$config\['plugins'\] = \).*/\1array('archive','managesieve','zipdownload','attachment_reminder');/" "$RC_CONF"
  echo "✅ Roundcube: добавен плъгин managesieve"
else
  echo "⚠️  Roundcube конфигурацията не е намерена ($RC_CONF)"
fi

echo "✅ Филтри и autoresponder са активирани (Dovecot + Roundcube)"
