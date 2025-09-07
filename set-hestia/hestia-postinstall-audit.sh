#!/usr/bin/env bash
# hestia-postinstall-audit.sh
# Версия: 1.3 — коректно брои ClamAV/SpamAssassin като проблем при изискване от hestia.conf

set -u

ok()    { printf "✅ %s\n" "$*"; }
warn()  { printf "⚠️  %s\n" "$*"; }
err()   { printf "❌ %s\n" "$*"; }
sep()   { printf -- "------------------------------------------------------------\n"; }

pkg_present() {
  local pkg="$1"
  if sudo dpkg-query -W -f='${Status}\n' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
    return 0
  fi
  return 1
}

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

check_service() {
  local label="$1"; shift
  local require_active="${1:-}"
  local want_active="no"
  if [[ "$require_active" == "require_active" ]]; then want_active="yes"; shift; fi
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
    ok "$label: unit '${unit}' е наличен (active=${active}, ${enabled})"
    return 0
  fi
}

# --- конфигурация ---
conf_get_raw() {
  local key="$1" file="$2"
  sudo awk -F'=' -v k="$key" '
    $1==k {
      v=$2
      sub(/\r$/,"",v)
      gsub(/^[[:space:]]+|[[:space:]]+$/,"",v)
      print v
    }' "$file" 2>/dev/null
}

sanitize() {
  local v="$1"
  v="${v#"${v%%[![:space:]]*}"}"   # ltrim
  v="${v%"${v##*[![:space:]]}"}"   # rtrim
  v="${v%\"}"; v="${v#\"}"         # strip "
  v="${v%\'}"; v="${v#\'}"         # strip '
  echo "$v"
}

conf_get() {
  local val; val="$(conf_get_raw "$1" "$2")"
  sanitize "$val"
}

sep
echo "HestiaCP Post-Install Audit"
conf_file="/usr/local/hestia/conf/hestia.conf"
echo "Config: $conf_file"
sep

issues=0

if [[ ! -f "$conf_file" ]]; then
  err "Файлът $conf_file липсва – HestiaCP не изглежда инсталирана."
  exit 1
fi
ok "Намерена конфигурация на Hestia: $conf_file"

# Основни ключове
WEB_SYSTEM="$(conf_get WEB_SYSTEM "$conf_file")"
PROXY_SYSTEM="$(conf_get PROXY_SYSTEM "$conf_file")"
DNS_SYSTEM="$(conf_get DNS_SYSTEM "$conf_file")"
MAIL_SYSTEM="$(conf_get MAIL_SYSTEM "$conf_file")"
DB_SYSTEM="$(conf_get DB_SYSTEM "$conf_file")"
FIREWALL_SYSTEM="$(conf_get FIREWALL_SYSTEM "$conf_file")"
BACKUP_SYSTEM="$(conf_get BACKUP_SYSTEM "$conf_file")"
BACKUP_DIR_RAW="$(conf_get BACKUP_DIR "$conf_file")"

# Антиспам/антивирус (различни конфигурации на Hestia/форкове)
ANTISPAM_SYSTEM="$(conf_get ANTISPAM_SYSTEM "$conf_file")"
ANTISPAM="$(conf_get ANTISPAM "$conf_file")"
ANTIVIRUS_SYSTEM="$(conf_get ANTIVIRUS_SYSTEM "$conf_file")"
ANTIVIRUS="$(conf_get ANTIVIRUS "$conf_file")"

printf "Настройки от hestia.conf:\n"
printf "  WEB_SYSTEM=%s\n  PROXY_SYSTEM=%s\n  DNS_SYSTEM=%s\n  MAIL_SYSTEM=%s\n  DB_SYSTEM=%s\n  FIREWALL_SYSTEM=%s\n  BACKUP_SYSTEM=%s\n  BACKUP_DIR=%s\n" \
  "${WEB_SYSTEM:-}" "${PROXY_SYSTEM:-}" "${DNS_SYSTEM:-}" "${MAIL_SYSTEM:-}" "${DB_SYSTEM:-}" "${FIREWALL_SYSTEM:-}" "${BACKUP_SYSTEM:-}" "${BACKUP_DIR_RAW:-}"
printf "  ANTISPAM_SYSTEM=%s  ANTISPAM=%s\n" "${ANTISPAM_SYSTEM:-}" "${ANTISPAM:-}"
printf "  ANTIVIRUS_SYSTEM=%s  ANTIVIRUS=%s\n" "${ANTIVIRUS_SYSTEM:-}" "${ANTIVIRUS:-}"
sep

# Очаквания по конфигурация
expect_sa=0
expect_clam=0
# SpamAssassin очакван ако някой от ключовете го изиска
if [[ "${ANTISPAM_SYSTEM,,}" == "spamassassin" || "${ANTISPAM,,}" == "yes" ]]; then
  expect_sa=1
fi
# ClamAV очакван ако някой от ключовете го изиска
if [[ "${ANTIVIRUS_SYSTEM,,}" == "clamav" || "${ANTIVIRUS,,}" == "yes" ]]; then
  expect_clam=1
fi

# --- WEB ---
if [[ "${WEB_SYSTEM:-}" == "apache2" ]]; then
  if pkg_present apache2; then ok "Пакет apache2 е инсталиран"; else err "Пакет apache2 не е инсталиран (WEB_SYSTEM=apache2)"; issues=$((issues+1)); fi
  if ! check_service "Web (apache2)" require_active apache2; then issues=$((issues+1)); fi
else
  ok "WEB_SYSTEM=${WEB_SYSTEM:-none} (apache2 не е изискано)"
fi

# --- PROXY ---
if [[ "${PROXY_SYSTEM:-}" == "nginx" ]]; then
  if pkg_present nginx; then ok "Пакет nginx е инсталиран"; else err "Пакет nginx не е инсталиран (PROXY_SYSTEM=nginx)"; issues=$((issues+1)); fi
  if ! check_service "Proxy (nginx)" require_active nginx; then issues=$((issues+1)); fi
else
  ok "PROXY_SYSTEM=${PROXY_SYSTEM:-none} (nginx не е изискан)"
fi

# --- DNS ---
if [[ "${DNS_SYSTEM:-}" == "bind9" ]]; then
  if pkg_present bind9 || pkg_present bind9-utils || pkg_present bind9-dnsutils; then
    ok "Пакет(и) bind9 присъстват"
  else
    err "bind9 липсва (DNS_SYSTEM=bind9)"; issues=$((issues+1))
  fi
  if ! check_service "DNS (BIND9)" require_active bind9 named; then issues=$((issues+1)); fi
else
  ok "DNS_SYSTEM=${DNS_SYSTEM:-none} (bind9 не е изискан)"
fi

# --- MAIL ---
if [[ "${MAIL_SYSTEM:-}" == "exim4" ]]; then
  if pkg_present exim4; then ok "Пакет exim4 е инсталиран"; else err "exim4 не е инсталиран (MAIL_SYSTEM=exim4)"; issues=$((issues+1)); fi
  if ! check_service "MTA (exim4)" require_active exim4; then issues=$((issues+1)); fi

  if pkg_present dovecot-core || pkg_present dovecot-imapd; then
    ok "Пакети dovecot* са инсталирани"
  else
    err "Dovecot не е инсталиран (очаква се при MAIL_SYSTEM=exim4)"; issues=$((issues+1))
  fi
  if ! check_service "IMAP/POP (dovecot)" require_active dovecot dovecot-imapd; then issues=$((issues+1)); fi
else
  ok "MAIL_SYSTEM=${MAIL_SYSTEM:-none} (exim4/dovecot не са изискани)"
fi

# --- DB ---
if [[ "${DB_SYSTEM:-}" == "mariadb" || "${DB_SYSTEM:-}" == "mysql" ]]; then
  if pkg_present mariadb-server || pkg_present mysql-server; then
    ok "DB пакет (MariaDB/MySQL) е инсталиран"
  else
    err "MariaDB/MySQL липсва (DB_SYSTEM=${DB_SYSTEM:-})"; issues=$((issues+1))
  fi
  if ! check_service "Database (MariaDB/MySQL)" require_active mariadb mysql; then issues=$((issues+1)); fi
else
  ok "DB_SYSTEM=${DB_SYSTEM:-none} (БД не е изискана)"
fi

# --- PHP-FPM ---
if dpkg -l | awk '{print $2}' | grep -Eq '^php([0-9.]+-)?fpm$'; then
  if find_unit php-fpm php8.3-fpm php8.2-fpm php8.1-fpm; then
    if ! check_service "PHP-FPM" require_active "$FOUND_UNIT"; then issues=$((issues+1)); fi
  else
    warn "PHP-FPM пакет има, но unit не е намерен по известните имена"; issues=$((issues+1))
  fi
else
  warn "PHP-FPM не изглежда инсталиран"; issues=$((issues+1))
fi

# --- ClamAV (очакване според hestia.conf) ---
if [[ "$expect_clam" -eq 1 ]]; then
  if pkg_present clamav-daemon || pkg_present clamav-freshclam; then
    ok "ClamAV: изискан и инсталиран"
    # по избор: проверка на услугите
    check_service "ClamAV (daemon)" clamav-daemon >/dev/null || true
    check_service "ClamAV (freshclam)" clamav-freshclam >/dev/null || true
  else
    err "ClamAV: ИЗИСКАН, но НЕ е инсталиран (hestia.conf)"
    issues=$((issues+1))
  fi
else
  if pkg_present clamav-daemon || pkg_present clamav-freshclam; then
    ok "ClamAV: инсталиран (не е изискан — допустимо)"
  else
    ok "ClamAV: не е изискан и не е инсталиран"
  fi
fi

# --- SpamAssassin (очакване според hestia.conf) ---
if [[ "$expect_sa" -eq 1 ]]; then
  if pkg_present spamassassin || pkg_present sa-compile; then
    ok "SpamAssassin: изискан и инсталиран"
    check_service "SpamAssassin" spamassassin >/dev/null || true
  else
    err "SpamAssassin: ИЗИСКАН, но НЕ е инсталиран (hestia.conf)"
    issues=$((issues+1))
  fi
else
  if pkg_present spamassassin || pkg_present sa-compile; then
    ok "SpamAssassin: инсталиран (не е изискан — допустимо)"
  else
    ok "SpamAssassin: не е изискан и не е инсталиран"
  fi
fi

# --- FTP ---
if pkg_present vsftpd; then
  ok "vsftpd е инсталиран"
  check_service "FTP (vsftpd)" vsftpd >/dev/null || true
else
  ok "vsftpd не е инсталиран (по избор)"
fi

# --- Fail2ban ---
if pkg_present fail2ban; then
  ok "fail2ban е инсталиран"
  if ! check_service "Fail2ban" require_active fail2ban; then issues=$((issues+1)); fi
else
  warn "fail2ban не е инсталиран (препоръчително)"; issues=$((issues+1))
fi

# --- Firewall ---
if [[ "${FIREWALL_SYSTEM:-}" == "iptables" ]]; then
  if command -v /usr/local/hestia/bin/v-list-firewall >/dev/null 2>&1; then
    if /usr/local/hestia/bin/v-list-firewall >/dev/null 2>&1; then
      ok "Firewall режим: iptables (управляван от Hestia)"
    else
      warn "Hestia firewall команди не отговарят (ще проверим hestia-firewall.service)"
      check_service "Hestia Firewall" hestia-firewall >/dev/null || true
    fi
  else
    warn "Hestia firewall CLI липсва, проверяваме услугата"
    check_service "Hestia Firewall" hestia-firewall >/dev/null || true
  fi
else
  warn "FIREWALL_SYSTEM=${FIREWALL_SYSTEM:-unknown} (очаквано: iptables)"
  issues=$((issues+1))
fi

# --- Backups ---
if [[ "${BACKUP_SYSTEM:-}" == "local" ]]; then
  BACKUP_DIR="${BACKUP_DIR_RAW:-/backup}"
  [[ -z "$BACKUP_DIR" ]] && BACKUP_DIR="/backup"
  if sudo test -d "$BACKUP_DIR"; then
    ok "Backups: local; директория: $BACKUP_DIR (налична)"
  else
    warn "Backups: local; директорията липсва или е недостъпна: $BACKUP_DIR"
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
