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

# --- Activate Roundcube managesieve plugin (idempotent) ---
RC_CONF="/etc/roundcube/config.inc.php"
if sudo test -f "$RC_CONF"; then
  if sudo grep -qE '\bmanagesieve\b' "$RC_CONF"; then
    ok "Roundcube: managesieve вече е активен"
  else
    sudo cp -a "$RC_CONF" "$RC_CONF.bak" || true
    # Формат: $config["plugins"] = [];
    sudo sed -i -E 's/(\$config\[[\"\047]plugins[\"\047]\]\s*=\s*)\[\s*\](\s*;)/\1["managesieve"]\2/' "$RC_CONF"
    # Формат: $config["plugins"] = ["a","b"];
    sudo sed -i -E 's/(\$config\[[\"\047]plugins[\"\047]\]\s*=\s*\[[^]]*?)\s*\](\s*;)/\1, "managesieve"]\2/' "$RC_CONF"
    # Формат: $config["plugins"] = array();
    sudo sed -i -E "s/(\$config\[['\"]plugins['\"]\]\s*=\s*array\s*)\(\s*\)(\s*;)/\1('managesieve')\2/" "$RC_CONF"
    # Формат: $config['plugins'] = array('a','b');
    sudo sed -i -E "s/(\$config\[['\"]plugins['\"]\]\s*=\s*array\s*\([^)']*)(\))(\s*;)/\1, 'managesieve'\2\3/" "$RC_CONF"

    if sudo grep -qE '\bmanagesieve\b' "$RC_CONF"; then
      ok "Roundcube: добавен плъгин managesieve"
    else
      err "Roundcube: неуспешно активиране на managesieve (виж $RC_CONF и бекъп $RC_CONF.bak)"
    fi
  fi
else
  warn "Roundcube: липсва конфигурация ($RC_CONF) – пропускам активиране на managesieve"
fi

rm -- "$0"

