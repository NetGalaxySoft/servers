#!/usr/bin/env bash
# hestia-postinstall-audit.sh
# Версия: 1.0 (детерминиран одит за HestiaCP на Ubuntu 22.04/24.04)
# Изход: 0 = всичко е ОК; 1 = има проблеми/несъответствия

set -u

# ---------- помощни функции ----------
ok()    { printf "✅ %s\n" "$*"; }
warn()  { printf "⚠️  %s\n" "$*"; }
err()   { printf "❌ %s\n" "$*"; }
sep()   { printf -- "------------------------------------------------------------\n"; }

# безопасно изпълнение на команда; връща stdout в глобална променлива _OUT и код
run() {
  _OUT=""
  if _OUT="$(eval "$1" 2>/dev/null)"; then return 0; else return 1; fi
}

# Проверка за пакет
pkg_present() {
  local pkg="$1"
  if sudo dpkg-query -W -f='${Status}\n' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
    return 0
  fi
  return 1
}

# Намиране на наличен unit измежду кандидати (без да изискваме да е активен)
# Поставя името в глобална променлива FOUND_UNIT (без .service)
FOUND_UNIT=""
find_unit() {
  FOUND_UNIT=""
  local c
  for c in "$@"; do
    if sudo systemctl list-unit-files --type=service | awk '{print $1}' | grep -qx "${c}.service"; then
      FOUND_UNIT="$c"
      return 0
    fi
  done
  return 1
}

# Проверка на услуга: съществува ли unit, active ли е, enabled ли е
# Аргументи: етикет; списък кандидати за unit; по избор: изисква ли се да е активна ("require_active")
check_service() {
  local label="$1"; shift
  local require_active="${1:-}"; # може да е "require_active", ако е подаден
  # ако е подадено "require_active" като първи параметър след label, го махаме и продължаваме с кандидатите
  local want_active="no"
  if [[ "$require_active" == "require_active" ]]; then
    want_active="yes"
    shift
  fi

  local candidates=("$@")
  local unit=""
  if find_unit "${candidates[@]}"; then
    unit="$FOUND_UNIT"
  else
    err "$label: unit не е намерен (${candidates[*]})"
    return 2
  fi

  local active="unknown" enabled="unknown"
  if sudo systemctl is-active --quiet "$unit"; then active="active"; else active="$(sudo systemctl is-active "$unit" 2>/dev/null || true)"; fi
  if sudo systemctl is-enabled --quiet "$unit"; then enabled="enabled"; else enabled="disabled"; fi

  if [[ "$want_active" == "yes" ]]; then
    if [[ "$active" == "active" ]]; then
      ok "$label: '${unit}' е active (${enabled})"
      return 0
    else
      warn "$label: '${unit}' е ${active} (${enabled})"
      return 1
    fi
  else
    # не изискваме да е стартирана – само наличност
    ok "$label: unit '${unit}' е наличен (active=${active}, ${enabled})"
    return 0
  fi
}

# Четене на ключ=стойност от hestia.conf
conf_get() {
  local key="$1"
  local file="$2"
  sudo awk -F'=' -v k="$key" '$1==k {sub(/\r$/,"",$2); gsub(/^"|\"$/,"",$2); print $2}' "$file" 2>/dev/null
}

# ---------- заглавие ----------
sep
echo "HestiaCP Post-Install Audit"
conf_file="/usr/local/hestia/conf/hestia.conf"
echo "Config: $conf_file"
sep

overall_rc=0
issues=0

# ---------- проверка за наличие на Hestia ----------
if [[ ! -f "$conf_file" ]]; then
  err "Файлът $conf_file липсва – HestiaCP не изглежда инсталирана."
  exit 1
fi
ok "Намерена конфигурация на Hestia: $conf_file"

# ---------- четене на ключови настройки ----------
WEB_SYSTEM="$(conf_get WEB_SYSTEM "$conf_file")"
PROXY_SYSTEM="$(conf_get PROXY_SYSTEM "$conf_file")"
DNS_SYSTEM="$(conf_get DNS_SYSTEM "$conf_file")"
MAIL_SYSTEM="$(conf_get MAIL_SYSTEM "$conf_file")"
DB_SYSTEM="$(conf_get DB_SYSTEM "$conf_file")"
FIREWALL_SYSTEM="$(conf_get FIREWALL_SYSTEM "$conf_file")"
BACKUP_SYSTEM="$(conf_get BACKUP_SYSTEM "$conf_file")"
BACKUP_DIR="$(conf_get BACKUP_DIR "$conf_file")"

printf "Настройки от hestia.conf:\n"
printf "  WEB_SYSTEM=%s\n  PROXY_SYSTEM=%s\n  DNS_SYSTEM=%s\n  MAIL_SYSTEM=%s\n  DB_SYSTEM=%s\n  FIREWALL_SYSTEM=%s\n  BACKUP_SYSTEM=%s\n  BACKUP_DIR=%s\n" \
  "${WEB_SYSTEM:-}" "${PROXY_SYSTEM:-}" "${DNS_SYSTEM:-}" "${MAIL_SYSTEM:-}" "${DB_SYSTEM:-}" "${FIREWALL_SYSTEM:-}" "${BACKUP_SYSTEM:-}" "${BACKUP_DIR:-}"
sep

# ---------- проверки по подсистеми (пакет ↔ unit ↔ конфиг) ----------

# Web
if [[ "${WEB_SYSTEM:-}" == "apache2" ]]; then
  if pkg_present apache2; then
    ok "Пакет apache2 е инсталиран"
  else
    err "Пакет apache2 не е инсталиран (WEB_SYSTEM=apache2)"
    issues=$((issues+1))
  fi
  if ! check_service "Web (apache2)" require_active apache2; then issues=$((issues+1)); fi
else
  ok "WEB_SYSTEM=${WEB_SYSTEM:-none} (не се очаква apache2)"
fi

# Proxy
if [[ "${PROXY_SYSTEM:-}" == "nginx" ]]; then
  if pkg_present nginx; then
    ok "Пакет nginx е инсталиран"
  else
    err "Пакет nginx не е инсталиран (PROXY_SYSTEM=nginx)"
    issues=$((issues+1))
  fi
  if ! check_service "Proxy (nginx)" require_active nginx; then issues=$((issues+1)); fi
else
  ok "PROXY_SYSTEM=${PROXY_SYSTEM:-none} (не се очаква nginx)"
fi

# DNS
if [[ "${DNS_SYSTEM:-}" == "bind9" ]]; then
  if pkg_present bind9 || pkg_present bind9-dnsutils || pkg_present bind9-utils; then
    ok "Пакет(и) bind9 присъстват"
  else
    err "bind9 липсва (DNS_SYSTEM=bind9)"
    issues=$((issues+1))
  fi
  # на някои системи unit е named.service (BIND9)
  if ! check_service "DNS (BIND9)" require_active bind9 named; then issues=$((issues+1)); fi
else
  ok "DNS_SYSTEM=${DNS_SYSTEM:-none} (не се очаква bind9)"
fi

# Mail (Exim + Dovecot)
if [[ "${MAIL_SYSTEM:-}" == "exim4" ]]; then
  if pkg_present exim4; then ok "Пакет exim4 е инсталиран"; else err "exim4 не е инсталиран (MAIL_SYSTEM=exim4)"; issues=$((issues+1)); fi
  if ! check_service "MTA (exim4)" require_active exim4; then issues=$((issues+1)); fi

  # Dovecot (IMAP/POP)
  if pkg_present dovecot-core || pkg_present dovecot-imapd; then
    ok "Пакети dovecot* са инсталирани"
  else
    err "Dovecot не е инсталиран (очаква се при MAIL_SYSTEM=exim4)"
    issues=$((issues+1))
  fi
  if ! check_service "IMAP/POP (dovecot)" require_active dovecot dovecot-imapd; then issues=$((issues+1)); fi
else
  ok "MAIL_SYSTEM=${MAIL_SYSTEM:-none} (не се очакват exim4/dovecot)"
fi

# Database (MariaDB)
if [[ "${DB_SYSTEM:-}" == "mariadb" || "${DB_SYSTEM:-}" == "mysql" ]]; then
  # При Hestia обичайно mariadb
  if pkg_present mariadb-server || pkg_present mysql-server; then
    ok "DB пакет (MariaDB/MySQL) е инсталиран"
  else
    err "MariaDB/MySQL липсва (DB_SYSTEM=${DB_SYSTEM:-})"
    issues=$((issues+1))
  fi
  if ! check_service "Database (MariaDB/MySQL)" require_active mariadb mysql; then issues=$((issues+1)); fi
else
  ok "DB_SYSTEM=${DB_SYSTEM:-none} (не се очаква MariaDB/MySQL)"
fi

# PHP-FPM (очаква се при Hestia web stack)
if pkg_present php-fpm || dpkg -l | awk '{print $2}' | grep -q '^php[0-9.]*-fpm$'; then
  # unit името може да е php8.3-fpm, php8.2-fpm и т.н.
  if find_unit php-fpm php8.3-fpm php8.2-fpm php8.1-fpm; then
    if ! check_service "PHP-FPM" require_active "$FOUND_UNIT"; then issues=$((issues+1)); fi
  else
    warn "PHP-FPM пакет има, но unit не е намерен (ще прегледаме имената)"
    issues=$((issues+1))
  fi
else
  warn "PHP-FPM не изглежда инсталиран (възможно custom setup)"
fi

# ClamAV
if pkg_present clamav-daemon || pkg_present clamav-freshclam; then
  ok "ClamAV пакети присъстват"
  if ! check_service "ClamAV (daemon)" clamav-daemon; then :; fi
  if ! check_service "ClamAV (freshclam)" clamav-freshclam; then :; fi
else
  ok "ClamAV не е инсталиран (по избор)"
fi

# SpamAssassin (по избор; при -z yes Hestia го инсталира)
if pkg_present spamassassin || pkg_present sa-compile; then
  ok "SpamAssassin е наличен"
  if ! check_service "SpamAssassin" spamassassin; then :; fi
else
  ok "SpamAssassin не е инсталиран (по избор)"
fi

# FTP (vsftpd)
if pkg_present vsftpd; then
  ok "vsftpd е инсталиран"
  if ! check_service "FTP (vsftpd)" vsftpd; then :; fi
else
  ok "vsftpd не е инсталиран (по избор)"
fi

# Fail2ban
if pkg_present fail2ban; then
  ok "fail2ban е инсталиран"
  if ! check_service "Fail2ban" require_active fail2ban; then issues=$((issues+1)); fi
else
  warn "fail2ban не е инсталиран (препоръчително е с Hestia)"
  issues=$((issues+1))
fi

# Firewall (Hestia управлява iptables)
if [[ "${FIREWALL_SYSTEM:-}" == "iptables" ]]; then
  if sudo /usr/local/hestia/bin/v-list-firewall 1>/dev/null 2>&1; then
    ok "Firewall режим в Hestia: iptables (управлява се от Hestia)"
  else
    warn "Hestia firewall команди не отговарят (проверете hestia-firewall.service)"
    if ! check_service "Hestia Firewall" hestia-firewall; then :; fi
  fi
else
  warn "FIREWALL_SYSTEM=${FIREWALL_SYSTEM:-unknown} (очаквано: iptables)"
  issues=$((issues+1))
fi

# Backups
if [[ "${BACKUP_SYSTEM:-}" == "local" ]]; then
  dir="${BACKUP_DIR:-/backup}"
  if [[ -n "$dir" ]] && sudo test -d "$dir"; then
    ok "Backups: local; директория: $dir (налична)"
  else
    warn "Backups: local; директорията липсва или е недостъпна: ${dir:-/backup}"
    issues=$((issues+1))
  fi
else
  warn "BACKUP_SYSTEM=${BACKUP_SYSTEM:-none} (очаквано: local)"
  issues=$((issues+1))
fi

sep
if [[ "$issues" -eq 0 ]]; then
  ok "Одитът приключи: няма проблеми."
  exit 0
else
  warn "Одитът приключи: открити са ${issues} несъответствия/предупреждения."
  exit 1
fi
