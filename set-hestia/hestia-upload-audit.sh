#!/usr/bin/env bash
# hestia-upload-audit.sh
# Пълна диагностика на бавен upload при Hestia (nginx+apache+php-fpm+I/O)
# Без интеракции, безопасно за продукция. Създава кратък I/O тест файл (64MB) и го изтрива.

set -euo pipefail

RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'; NC=$'\033[0m'
TS="$(date +%Y%m%d-%H%M%S)"
OUT="/tmp/hestia-upload-audit-$TS.txt"

log()  { echo -e "$@" | tee -a "$OUT"; }
ok()   { log "${GRN}✅ $*${NC}"; }
warn() { log "${YEL}⚠️  $*${NC}"; }
err()  { log "${RED}❌ $*${NC}"; }

header(){ log "\n==== $* ====\n"; }

sudo -v || true
: >/tmp/.sudo_touch

header "Системна информация"
{
  echo "Дата: $(date -Is)"
  uname -a
  lsb_release -a 2>/dev/null || true
  uptime
} | tee -a "$OUT"

header "Дисково пространство и монтирани точки"
{
  df -hT
  echo
  echo "findmnt за /var/lib/nginx:"
  findmnt -no SOURCE,TARGET,FSTYPE,OPTIONS /var/lib/nginx 2>/dev/null || true
} | tee -a "$OUT"

header "NGINX: основни параметри (глобално и Hestia-nginx)"
NGX_MAIN="/etc/nginx/nginx.conf"
HST_NGX="/usr/local/hestia/nginx/conf/nginx.conf"
for f in "$NGX_MAIN" "$HST_NGX"; do
  [ -f "$f" ] || continue
  echo "-- $f --" | tee -a "$OUT"
  awk '
    /client_max_body_size|client_body_buffer_size|client_body_timeout|client_header_timeout|send_timeout|keepalive_timeout|proxy_request_buffering|proxy_max_temp_file_size|client_body_temp_path/ && $0 !~ /^[[:space:]]*#/ {print}
  ' "$f" | tee -a "$OUT"
done

header "NGINX: пер-домейн (Hestia conf.d/domains)"
NGX_DOM_DIR="/etc/nginx/conf.d/domains"
if [ -d "$NGX_DOM_DIR" ]; then
  grep -R --line-number -E \
    'client_max_body_size|client_body_buffer_size|proxy_request_buffering|proxy_max_temp_file_size|client_body_timeout|send_timeout' \
    "$NGX_DOM_DIR" 2>/dev/null | tee -a "$OUT" || true
else
  warn "Директорията $NGX_DOM_DIR липсва (нормално, ако няма конфигурирани домейни)."
fi

header "NGINX: шаблони на Hestia"
HST_TPL="/usr/local/hestia/data/templates/web"
if [ -d "$HST_TPL" ]; then
  grep -R --line-number -E \
    'client_max_body_size|client_body_buffer_size|proxy_request_buffering|proxy_max_temp_file_size' \
    "$HST_TPL" 2>/dev/null | tee -a "$OUT" || true
else
  warn "Липсват шаблони на $HST_TPL"
fi

header "APACHE: Timeout/ReqTimeout/LimitRequestBody/MPM"
{
  grep -R --line-number -E '^\s*Timeout\s+[0-9]+' /etc/apache2/ 2>/dev/null || true
  grep -R --line-number -E 'RequestReadTimeout' /etc/apache2/ 2>/dev/null || true
  grep -R --line-number -E 'LimitRequestBody' /etc/apache2/ 2>/dev/null || true
  echo
  a2query -M 2>/dev/null || true
  echo
  if [ -f /etc/apache2/mods-enabled/mpm_event.conf ]; then
    echo "-- /etc/apache2/mods-enabled/mpm_event.conf --"
    sed -n '1,200p' /etc/apache2/mods-enabled/mpm_event.conf
  fi
} | tee -a "$OUT"

header "PHP-FPM: версии, upload лимити, времена, tmp директории, пулове"
PHP_BASE="/etc/php"
if [ -d "$PHP_BASE" ]; then
  for vdir in "$PHP_BASE"/*; do
    [ -d "$vdir" ] || continue
    ver="$(basename "$vdir")"
    FPM_INI="$vdir/fpm/php.ini"
    echo "---- PHP $ver ----" | tee -a "$OUT"
    if [ -f "$FPM_INI" ]; then
      awk -F'= ' '
        BEGIN{IGNORECASE=1}
        /^\s*upload_max_filesize/||/^\s*post_max_size/||/^\s*max_execution_time/||/^\s*max_input_time/||/^\s*memory_limit/||/^\s*request_terminate_timeout/||/^\s*upload_tmp_dir/ {gsub(/^[ \t]+|[ \t;]+$/,"",$2); printf "%s = %s\n",$1,$2}
      ' "$FPM_INI" | tee -a "$OUT"
    else
      warn "Липсва $FPM_INI"
    fi
    # Пулове
    if [ -d "$vdir/fpm/pool.d" ]; then
      for pool in "$vdir"/fpm/pool.d/*.conf; do
        [ -f "$pool" ] || continue
        echo "-- pool: $pool --" | tee -a "$OUT"
        awk -F'=|;' '
          BEGIN{IGNORECASE=1}
          /^\s*\[.*\]/ {print $0}
          /^\s*pm\s*=/ || /^\s*pm\.max_children\s*=/ || /^\s*pm\.max_requests\s*=/ || /^\s*pm\.start_servers\s*=/ || /^\s*pm\.min_spare_servers\s*=/ || /^\s*pm\.max_spare_servers\s*=/ || /^\s*request_terminate_timeout\s*=/ || /^\s*php_admin_value\[memory_limit\]\s*=/ || /^\s*security\.limit_extensions\s*=/ {gsub(/^[ \t]+|[ \t]+$/,"",$2); printf "%s=%s\n",$1,$2}
        ' "$pool" | tee -a "$OUT"
      done
    fi
  done
else
  warn "Липсва директория $PHP_BASE"
fi

header "PHP-FPM: услуги и логове (последни 200 реда/услуга)"
{
  systemctl --no-pager --type=service | grep -E 'php.*fpm' || true
  echo
  for s in $(systemctl list-units --type=service --no-legend | awk '/php.*fpm/{print $1}'); do
    echo "-- journalctl -u $s --"
    journalctl -u "$s" -n 200 --no-pager 2>/dev/null || true
    echo
  done
} | tee -a "$OUT"

header "ModSecurity / WAF (ако е активен)"
{
  grep -R --line-number -E 'SecRuleEngine' /etc 2>/dev/null || true
  if [ -d /etc/modsecurity ]; then
    echo "-- Активни правила --"
    grep -R --line-number -E 'Include.*modsecurity' /etc/apache2/ 2>/dev/null || true
  fi
} | tee -a "$OUT"

header "NGINX: темп директории и настройки за upload buffering"
{
  # client_body_temp_path може да липсва (ползва default). Проверяваме и размера на tmp дяла.
  grep -R --line-number -E 'client_body_temp_path|proxy_request_buffering|proxy_max_temp_file_size' /etc/nginx/ 2>/dev/null || true
  echo
  echo "du -sh /var/lib/nginx/tmp (ако съществува):"
  du -sh /var/lib/nginx/tmp 2>/dev/null || echo "(няма такава директория)"
  echo
  echo "du -sh /var/lib/nginx/body (ако съществува):"
  du -sh /var/lib/nginx/body 2>/dev/null || echo "(няма такава директория)"
} | tee -a "$OUT"

header "Кратък I/O бенчмарк (64MB) в /var/lib/nginx (ако е записваемо)"
IO_BASE="/var/lib/nginx"
DO_IO=1
if [ -d "$IO_BASE" ] && [ -w "$IO_BASE" ]; then
  TEST_FILE="$IO_BASE/.upload-io-test.bin"
  ( time dd if=/dev/zero of="$TEST_FILE" bs=4M count=16 conv=fdatasync oflag=direct 2>&1 ) | tee -a "$OUT" || DO_IO=0
  ( time dd if="$TEST_FILE" of=/dev/null bs=4M count=16 iflag=direct 2>&1 ) | tee -a "$OUT" || DO_IO=0
  rm -f "$TEST_FILE" || true
else
  warn "$IO_BASE не е записваемо или липсва — пропускам I/O теста тук."
  DO_IO=0
fi

header "Обобщение и подсказки"
{
  # NGINX client_body_buffer_size
  CBB_MAIN=$(awk '/client_body_buffer_size/ && $0 !~ /^#/ {print $2}' "$NGX_MAIN" 2>/dev/null | head -n1 || true)
  CBB_HST=$(awk '/client_body_buffer_size/ && $0 !~ /^#/ {print $2}' "$HST_NGX" 2>/dev/null | head -n1 || true)

  if [[ "$CBB_MAIN" =~ [Kk]$ ]] || [[ "$CBB_HST" =~ [Kk]$ ]]; then
    warn "NGINX client_body_buffer_size е в килобайти ($CBB_MAIN / $CBB_HST) → вероятно upload се буферира на ДИСК и е бавен. Препоръка: 16m."
  else
    ok "NGINX client_body_buffer_size не е в KB ($CBB_MAIN / $CBB_HST)."
  fi

  # Apache RequestReadTimeout (body)
  if grep -R -E 'RequestReadTimeout .*body=' /etc/apache2/ 2>/dev/null | grep -qv '#'; then
    warn "Наличен е Apache RequestReadTimeout с body=... → възможно е да прекъсва/забавя бавни ъплоуди. Препоръка: body=20,minrate=1"
  else
    ok "Няма агресивен RequestReadTimeout body=... в Apache."
  fi

  # PHP upload/post лимити
  BADPHP=0
  while read -r line; do
    key=$(echo "$line" | awk -F'=' '{print $1}'); val=$(echo "$line" | awk -F'= ' '{print $2}')
    case "$key" in
      upload_max_filesize|post_max_size)
        # просто показваме
        ;;
    esac
  done < <(grep -R -H -E '^\s*(upload_max_filesize|post_max_size)\s*=' /etc/php/*/fpm/php.ini 2>/dev/null || true)

  # I/O резултат
  if [ "$DO_IO" -eq 1 ]; then
    ok "I/O тест в $IO_BASE е изпълнен. Виж времената на dd (write/read) по-горе."
  else
    warn "I/O тестът беше пропуснат (нямаше права/директория). Ако upload се буферира там, провери дисковата производителност."
  fi

  # Temp директории
  if grep -R -E '^\s*upload_tmp_dir\s*=' /etc/php/*/fpm/php.ini 2>/dev/null | grep -qv '^;'; then
    ok "PHP upload_tmp_dir е дефиниран (виж секцията PHP-FPM)."
  else
    warn "PHP upload_tmp_dir не е дефиниран в php.ini → ползва се системен /tmp. Това е ОК, но ако /tmp е малък/бавен tmpfs/дял, може да влияе."
  fi

  # proxy_request_buffering
  if grep -R -E 'proxy_request_buffering\s+off;' /etc/nginx/ 2>/dev/null | grep -qv '#'; then
    ok "Намерено proxy_request_buffering off; (stream upload към upstream)."
  else
    warn "Липсва proxy_request_buffering off; → nginx вероятно буферира целия upload локално. За големи файлове може да се обмисли включване per-domain."
  fi

} | tee -a "$OUT"

log "\nОтчетът е записан в: $OUT"
