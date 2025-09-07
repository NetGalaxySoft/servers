#!/usr/bin/env bash
# HestiaCP post-install audit: verifies components requested in hestia.conf
# Usage: sudo bash hestia-postinstall-audit.sh

set -euo pipefail

CONF="/usr/local/hestia/conf/hestia.conf"
[[ $EUID -ne 0 ]] && { echo "Run as root (sudo)."; exit 1; }
[[ ! -f "$CONF" ]] && { echo "Not found: $CONF"; exit 1; }

# Read key vars (absent vars -> empty)
read_var(){ awk -F"=" -v k="$1" '$1==k{gsub(/[ '"'"']/, "", $2);print $2}' "$CONF" 2>/dev/null || true; }

VERSION=$(read_var VERSION)
WEB_SYSTEM=$(read_var WEB_SYSTEM)
PROXY_SYSTEM=$(read_var PROXY_SYSTEM)
PHP_SYSTEM=$(read_var PHP_SYSTEM)
DNS_SYSTEM=$(read_var DNS_SYSTEM)
DB_SYSTEM=$(read_var DB_SYSTEM)
MAIL_SYSTEM=$(read_var MAIL_SYSTEM)
IMAP_SYSTEM=$(read_var IMAP_SYSTEM)
SPAMASSASSIN_SYSTEM=$(read_var SPAMASSASSIN_SYSTEM)
ANTIVIRUS_SYSTEM=$(read_var ANTIVIRUS_SYSTEM)
FIREWALL_SYSTEM=$(read_var FIREWALL_SYSTEM)
FTP_SYSTEM=$(read_var FTP_SYSTEM)
BACKUP_SYSTEM=$(read_var BACKUP_SYSTEM)

ok(){ printf "✅ %s\n" "$1"; }
warn(){ printf "⚠️  %s\n" "$1"; }
err(){ printf "❌ %s\n" "$1"; }

have_pkg(){ dpkg -s "$1" &>/dev/null; }
svc_active(){ systemctl is-active --quiet "$1"; }
svc_enabled(){ systemctl is-enabled --quiet "$1"; }

header(){
  echo "------------------------------------------------------------"
  echo "HestiaCP Post-Install Audit (version: ${VERSION:-unknown})"
  echo "Config: $CONF"
  echo "------------------------------------------------------------"
}

check_service(){
  local name="$1"             # Friendly name
  local svc_candidates="$2"   # space-separated systemd services to try
  local pkg_candidates="$3"   # space-separated packages to try
  local required="$4"         # yes|no (if config says this component is used)

  local found_svc=""
  for s in $svc_candidates; do
    systemctl list-unit-files | grep -q "^${s}\.service" && { found_svc="$s"; break; }
  done

  local have_any_pkg=""
  for p in $pkg_candidates; do
    have_pkg "$p" && { have_any_pkg="$p"; break; }
  done

  if [[ "$required" == "yes" ]]; then
    if [[ -z "$found_svc" && -z "$have_any_pkg" ]]; then
      err "$name: not installed (missing service & package)"
      return
    fi
    if [[ -n "$found_svc" ]]; then
      if svc_active "$found_svc"; then
        ok "$name: service '$found_svc' is active"
      else
        err "$name: service '$found_svc' is NOT active"
      fi
      if svc_enabled "$found_svc"; then
        ok "$name: service '$found_svc' is enabled at boot"
      else
        warn "$name: service '$found_svc' is NOT enabled at boot"
      fi
    else
      warn "$name: no service found; package '$have_any_pkg' present"
    fi
  else
    if [[ -n "$found_svc" || -n "$have_any_pkg" ]]; then
      warn "$name: appears installed, but not declared in hestia.conf"
    else
      ok "$name: not in use (as per config)"
    fi
  fi
}

header

# Web / Proxy
[[ -n "$WEB_SYSTEM" ]] && check_service "Web ($WEB_SYSTEM)" "apache2" "apache2" "yes" || ok "Web: not configured"
[[ -n "$PROXY_SYSTEM" ]] && check_service "Proxy ($PROXY_SYSTEM)" "nginx" "nginx-full nginx" "yes" || ok "Proxy: not configured"

# PHP
if [[ "$PHP_SYSTEM" == "php-fpm" ]]; then
  # find any php-fpm service
  PHPFPM_SVC=$(systemctl list-units --type=service --all | awk '/php.*-fpm\.service/ {print $1}' | sed 's/\.service$//' | head -n1)
  if [[ -n "$PHPFPM_SVC" ]]; then
    check_service "PHP-FPM" "$PHPFPM_SVC" "php-fpm php8.2-fpm php8.3-fpm" "yes"
  else
    err "PHP-FPM: no php*-fpm service found (but PHP_SYSTEM=php-fpm)"
  fi
else
  ok "PHP: not configured as php-fpm in hestia.conf"
fi

# DNS
if [[ -n "$DNS_SYSTEM" ]]; then
  check_service "DNS ($DNS_SYSTEM)" "bind9 named" "bind9" "yes"
else
  ok "DNS: not configured"
fi

# Database
if [[ -n "$DB_SYSTEM" ]]; then
  # Hestia uses MariaDB typically; service can be 'mariadb' or 'mysql'
  check_service "Database ($DB_SYSTEM)" "mariadb mysql" "mariadb-server mysql-server" "yes"
else
  ok "Database: not configured"
fi

# Mail stack
if [[ -n "$MAIL_SYSTEM" ]]; then
  check_service "MTA ($MAIL_SYSTEM)" "exim4" "exim4" "yes"
else
  ok "MTA: not configured"
fi

if [[ -n "$IMAP_SYSTEM" ]]; then
  check_service "IMAP/POP ($IMAP_SYSTEM)" "dovecot dovecot-imapd" "dovecot-core" "yes"
else
  ok "IMAP/POP: not configured"
fi

if [[ -n "$SPAMASSASSIN_SYSTEM" ]]; then
  # spamassassin service name can be spamassassin or spamd (Debian uses spamassassin.service alias to spamd)
  check_service "SpamAssassin" "spamassassin spamd" "spamassassin" "yes"
else
  ok "SpamAssassin: not configured"
fi

# Antivirus
if [[ "$ANTIVIRUS_SYSTEM" == "clamav" ]]; then
  check_service "ClamAV (freshclam)" "clamav-freshclam" "clamav-freshclam" "yes"
  check_service "ClamAV (daemon)" "clamav-daemon" "clamav-daemon" "yes"
else
  ok "Antivirus: not configured as clamav"
fi

# FTP
if [[ -n "$FTP_SYSTEM" ]]; then
  # Hestia may use vsftpd or proftpd depending on build
  if [[ "$FTP_SYSTEM" == "vsftpd" ]]; then
    check_service "FTP (vsftpd)" "vsftpd" "vsftpd" "yes"
  else
    check_service "FTP (proftpd)" "proftpd proftpd-basic" "proftpd-basic proftpd" "yes"
  fi
else
  ok "FTP: not configured"
fi

# Firewall + Fail2ban
if [[ -n "$FIREWALL_SYSTEM" ]]; then
  check_service "Fail2ban" "fail2ban" "fail2ban" "yes"
  ok "Firewall mode in Hestia: $FIREWALL_SYSTEM (rules managed by Hestia)"
else
  warn "Firewall: not declared in hestia.conf"
fi

# Backups
if [[ -n "$BACKUP_SYSTEM" ]]; then
  ok "Backups: configured ($BACKUP_SYSTEM) — storage: /backup"
else
  warn "Backups: BACKUP_SYSTEM not set in hestia.conf"
fi

echo "------------------------------------------------------------"
echo "Audit finished. Items marked ❌/⚠️  need attention."
