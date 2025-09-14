#!/usr/bin/env bash
# Roundcube Filters (Dovecot Sieve/ManageSieve) — безопасна инсталация и конфигурация
# ОС: Ubuntu 24.04 (HestiaCP съвместим)
# Характеристики: DRY-RUN, backup-и, идемпотентност, минимални и валидни конфиги

set -euo pipefail

# ==========================
# Конфигируеми флагове
# ==========================
: "${DRY_RUN:=1}"          # 1 = само diff (без запис), 0 = записва промени
: "${RUN_RESTART:=0}"      # 1 = рестартира dovecot/nginx/apache/php-fpm, 0 = не рестартира
: "${INIT_SIEVE_DIRS:=0}"  # 1 = създава ~/sieve за /home/*, 0 = пропуска

# ==========================
# Пътища/файлове
# ==========================
DOVECOT_MAIN="/etc/dovecot/dovecot.conf"
MSV_FILE="/etc/dovecot/conf.d/20-managesieve.conf"
SIEVE_FILE="/etc/dovecot/conf.d/90-sieve.conf"

RC_MAIN="/etc/roundcube/config.inc.php"
RC_PLUG="/etc/roundcube/plugins/managesieve/config.inc.php"
RC_PLUG_DIST="/usr/share/roundcube/plugins/managesieve/config.inc.php.dist"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# ==========================
# Помощни функции
# ==========================
say()  { printf '==> %s\n' "$*"; }
err()  { printf '!! %s\n' "$*" >&2; }
bak()  { local f="$1"; sudo cp -a "$f" "$f.bak.$(date +%F-%H%M%S)" 2>/dev/null || true; }

backup_and_install() {
  # $1 src  $2 dst
  local src="$1" dst="$2"
  if [[ "$DRY_RUN" = "1" ]]; then
    say "DRY-RUN diff за $dst:"
    if [[ -f "$dst" ]]; then
      sudo diff -u "$dst" "$src" || true
    else
      say "(нов файл) ще бъде създаден $dst:"
      sudo sed -n '1,200p' "$src"
    fi
  else
    if [[ -f "$dst" ]]; then bak "$dst"; fi
    sudo install -m 0644 "$src" "$dst"
  fi
}

ensure_protocol_sieve_once() {
  # гарантира, че в dovecot.conf има точно едно "sieve" в реда protocols
  local tmp="$TMP_DIR/dovecot.conf.new"
  if ! grep -q '^[[:space:]]*protocols[[:space:]]*=' "$DOVECOT_MAIN"; then
    # няма ред protocols -> добавяме
    printf 'protocols = $protocols sieve\n' | sudo tee -a "$DOVECOT_MAIN" >/dev/null
    return
  fi
  # има ред; нормализирай и добави при липса
  # 1) премахни всички срещания на "sieve" в реда
  sudo sed -E -i 's/^([[:space:]]*protocols[[:space:]]*=[[:space:]]*)(.*)$/echo "\1$(echo "\2" | sed -E "s/\bsieve\b//g")"/e' "$DOVECOT_MAIN"
  # 2) премахни двойни интервали
  sudo sed -E -i 's/^( *protocols *= *)( +)/\1/' "$DOVECOT_MAIN"
  sudo sed -E -i 's/  +/ /g' "$DOVECOT_MAIN"
  # 3) добави "sieve" в края
  sudo sed -E -i 's/^([[:space:]]*protocols[[:space:]]*=[[:space:]]*.*)$/\1 sieve/' "$DOVECOT_MAIN"
}

install_pkg() {
  local pkg="$1"
  if [[ "$DRY_RUN" = "1" ]]; then
    say "DRY-RUN: ще се инсталира пакет: $pkg"
  else
    sudo apt-get install -y "$pkg"
  fi
}

reload_services_maybe() {
  [[ "$RUN_RESTART" = "1" ]] || { say "Пропускам рестарти (RUN_RESTART=0)."; return; }
  say "Рестартирам dovecot..."
  sudo systemctl restart dovecot
  sudo systemctl is-active --quiet dovecot && say "dovecot е активен ✅" || err "dovecot не стартира ❌"

  say "Презареждам nginx/apache/php-fpm (ако ги има)..."
  sudo systemctl reload nginx 2>/dev/null || true
  sudo systemctl reload apache2 2>/dev/null || true
  # reload всички php-fpm услуги
  for svc in $(systemctl list-units --type=service --all | awk '/php.*-fpm\.service/ {print $1}'); do
    sudo systemctl reload "$svc" || true
  done
}

# ==========================
# 1) Пакети
# ==========================
say "Обновяване на индекси (може да се пропусне при DRY-RUN)..."
if [[ "$DRY_RUN" = "1" ]]; then
  say "DRY-RUN: sudo apt-get update -y"
else
  sudo apt-get update -y
fi
say "Инсталация на dovecot-sieve и dovecot-managesieved..."
install_pkg "dovecot-sieve"
install_pkg "dovecot-managesieved"

# ==========================
# 2) Dovecot: 90-sieve.conf (минимален валиден)
# ==========================
say "Подготвям 90-sieve.conf (plugin блок с пътища до потребителските филтри)..."
cat > "$TMP_DIR/90-sieve.conf" <<'EOF'
plugin {
  sieve = ~/.dovecot.sieve
  sieve_dir = ~/sieve
}
EOF
backup_and_install "$TMP_DIR/90-sieve.conf" "$SIEVE_FILE"

# ==========================
# 3) Dovecot: 20-managesieve.conf (валиден многострочен блок)
# ==========================
say "Почиствам старите service managesieve { ... } блокове и добавям валиден..."
# 3.1) Изгради базов контент от текущия файл без blocks (ако файлът съществува)
BASE_OUT="$TMP_DIR/20-managesieve.base"
if [[ -f "$MSV_FILE" ]]; then
  sudo awk '
    BEGIN{in=0}
    /^service[ \t]+managesieve[ \t]*\{/ {in=1; next}
    in && /^\}/ {in=0; next}
    !in {print}
  ' "$MSV_FILE" | sudo tee "$BASE_OUT" >/dev/null
else
  # Ако липсва, започни от празен (но е хубаво да запазим header коментари, ако ги има)
  : > "$BASE_OUT"
fi

# 3.2) Добави валидния блок най-отдолу
cat >> "$BASE_OUT" <<'EOF'

service managesieve {
  inet_listener sieve {
    port = 4190
  }
}
EOF

backup_and_install "$BASE_OUT" "$MSV_FILE"

# ==========================
# 4) Dovecot: добави "sieve" в protocols точно веднъж
# ==========================
say "Гарантирам \"sieve\" точно веднъж в protocols реда на dovecot.conf..."
ensure_protocol_sieve_once

# ==========================
# 5) Roundcube: активиране и конфиг на плъгина "managesieve"
# ==========================
say "Roundcube: активирам плъгина \"managesieve\"..."
if [[ -f "$RC_MAIN" ]]; then
  if ! grep -qE "\$config\['plugins'\].*managesieve" "$RC_MAIN"; then
    # Опит за вмъкване в съществуващ масив; ако не открие масива, добавя append ред
    TMP_RC="$TMP_DIR/config.inc.php.new"
    if grep -q "\$config\['plugins'\]" "$RC_MAIN"; then
      # Инжектиране вътре в масива след отварящата '['
      sudo awk '
        BEGIN{ins=0}
        /\$config\[\x27plugins\x27\]\s*=\s*\[/ && !ins {
          print
          print "    \"managesieve\","
          ins=1
          next
        }
        {print}
      ' "$RC_MAIN" | sudo tee "$TMP_RC" >/dev/null
      if [[ "$DRY_RUN" = "1" ]]; then
        say "DRY-RUN diff за $RC_MAIN:"
        sudo diff -u "$RC_MAIN" "$TMP_RC" || true
      else
        bak "$RC_MAIN"
        sudo mv "$TMP_RC" "$RC_MAIN"
      fi
    else
      # Няма дефиниция на plugins — добавяме безопасен append ред в края
      if [[ "$DRY_RUN" = "1" ]]; then
        say "DRY-RUN: ще добавя в края на $RC_MAIN: \$config['plugins'][] = 'managesieve';"
      else
        bak "$RC_MAIN"
        printf "\n\$config['plugins'][] = 'managesieve';\n" | sudo tee -a "$RC_MAIN" >/dev/null
      fi
    fi
  else
    say "Плъгинът \"managesieve\" вече е активен в $RC_MAIN."
  fi
else
  err "Не намирам $RC_MAIN — пропускам активиране на плъгина (провери пътя)."
fi

say "Roundcube: конфиг на плъгина managesieve (localhost:4190, без TLS за локална връзка)..."
if [[ -f "$RC_PLUG_DIST" ]]; then
  if [[ "$DRY_RUN" = "1" ]]; then
    say "DRY-RUN: ще създам $RC_PLUG от $RC_PLUG_DIST (ако липсва)."
  else
    [[ -f "$RC_PLUG" ]] || sudo install -m 0644 "$RC_PLUG_DIST" "$RC_PLUG"
  fi
else
  err "Не намирам $RC_PLUG_DIST — провери пакетите roundcube-plugins."
fi

if [[ -f "$RC_PLUG" ]]; then
  if [[ "$DRY_RUN" = "1" ]]; then
    say "DRY-RUN: ще настроя host/port/usetls в $RC_PLUG"
  else
    bak "$RC_PLUG"
    sudo sed -i "s/^\$config\['managesieve_host'\].*/\$config['managesieve_host'] = 'localhost';/" "$RC_PLUG" || true
    sudo sed -i "s/^\$config\['managesieve_port'\].*/\$config['managesieve_port'] = 4190;/" "$RC_PLUG" || true
    if grep -q "managesieve_usetls" "$RC_PLUG"; then
      sudo sed -i "s/^\$config\['managesieve_usetls'\].*/\$config['managesieve_usetls'] = false;/" "$RC_PLUG"
    else
      printf "\n\$config['managesieve_usetls'] = false;\n" | sudo tee -a "$RC_PLUG" >/dev/null
    fi
  fi
else
  say "Плъгин файл $RC_PLUG още не съществува (може да е нарочно при DRY-RUN)."
fi

# ==========================
# 6) (Опция) Инициализация на ~/sieve за /home/*
# ==========================
if [[ "$INIT_SIEVE_DIRS" = "1" ]]; then
  say "Инициализирам ~/sieve директории за потребителите в /home/* ..."
  for HOME_DIR in /home/*; do
    [[ -d "$HOME_DIR" ]] || continue
    if [[ "$DRY_RUN" = "1" ]]; then
      say "DRY-RUN: mkdir -p $HOME_DIR/sieve ; chmod 700 ; chown $(stat -c %U:%G "$HOME_DIR")"
    else
      sudo install -d -m 700 -o "$(stat -c %U "$HOME_DIR")" -g "$(stat -c %G "$HOME_DIR")" "$HOME_DIR/sieve"
    fi
  done
else
  say "Пропускам създаването на ~/sieve директории (INIT_SIEVE_DIRS=0)."
fi

# ==========================
# 7) Валидация и (по избор) рестарт
# ==========================
say "Валидация на Dovecot конфигурацията (doveconf -n) ..."
if ! sudo doveconf -n >/dev/null; then
  err "doveconf -n докладва грешка. Виж горния изход и коригирай."
  exit 1
fi
say "Синтаксисът е ОК ✅"

reload_services_maybe

say "Готово. Подсказки:"
say " - За реално прилагане: DRY_RUN=0 RUN_RESTART=1 sudo bash ./този_скрипт.sh"
say " - Проверка порт 4190: sudo ss -lntp | grep :4190 || true"
say " - Логове при проблем:  sudo journalctl -xeu dovecot.service | tail -n 80"
