#!/bin/bash

# ==========================================================================
#  vps-virhost-create.sh – Създаване на виртуален хост (Apache)
# --------------------------------------------------------------------------
#  Версия: 1.0
#  Дата:   2025-07-07
#  Автор:  Ilko Yordanov / NetGalaxy
# ==========================================================================
#
#  Този скрипт подготвя и конфигурира виртуален хост върху съществуващ VPS.
#  Поддържа основни и субдомейни, с възможност за собствен или Let's Encrypt
#  сертификат, избор на PHP версия и автоматична структура на уеб директории.
#
#  🔒 Скриптът НЕ извършва никакви промени, докато операторът не прегледа
#     и потвърди всички избрани параметри.
# ==========================================================================

# === ПОМОЩНА ИНФОРМАЦИЯ ===================================================
show_help() {
  echo "Използване: vps-virhost-create.sh [опция]"
  echo ""
  echo "Създава виртуален хост за Apache сървър с пълна структура и SSL."
  echo "Позволява избор на PHP версия и тип сертификат (Let's Encrypt или собствен)."
  echo ""
  echo "Опции:"
  echo "  --version       Показва версията на скрипта"
  echo "  --help          Показва тази помощ"
}

# === ОБРАБОТКА НА ОПЦИИ ===================================================
if [[ $# -gt 0 ]]; then
  case "$1" in
    --version)
      echo "vps-virhost-create.sh версия 1.0 (7 юли 2025 г.)"
      exit 0
      ;;
    --help)
      show_help
      exit 0
      ;;
    *)
      echo "❌ Неразпозната опция: $1"
      show_help
      exit 1
      ;;
  esac
fi

# Подготовка на променливи за събиране на данни
SUMMARY_DOMAIN=""
SUMMARY_ROOT_DOMAIN=""
SUMMARY_IS_SUBDOMAIN=""
SUMMARY_WEBROOT=""
SUMMARY_PHP_VERSION=""
SUMMARY_SSL_TYPE=""
SUMMARY_CUSTOM_MESSAGE=""

# Променливи за собственост и достъп
SUMMARY_NOMINAL_USER=""          # напр. nomhost__humanizma_eu
SUMMARY_NOMINAL_GROUP=""         # напр. host0_humanizma_eu

# Променливи за лимит
SUMMARY_DISK_LIMIT_MB=""
SUMMARY_ENABLE_NOMINAL_USER=""

# Променливи за главен администратор
SUMMARY_ADMIN_USER=""
SUMMARY_ADMIN_PASSWORD=""

# Променливи за база данни
SUMMARY_DB_NAME=""
SUMMARY_DB_USER=""
SUMMARY_DB_PASSWORD=""

# FTP достъп
SUMMARY_ENABLE_FTP=""

echo "=================================================================="
echo " 🌐 NetGalaxy - Създаване на виртуален хост за Apache сървър"
echo "=================================================================="

# Проверка за root права
if [[ "$EUID" -ne 0 ]]; then
  echo "❌ Скриптът трябва да бъде изпълнен с root права (sudo)."
  exit 1
fi

# Проверка за наличен Apache
if ! command -v apache2 >/dev/null 2>&1; then
  echo "❌ Apache уеб сървърът не е инсталиран. Инсталирайте го преди да продължите."
  exit 1
fi

# === [1] СЪБИРАНЕ НА ИНФОРМАЦИЯ И ПРОВЕРКА НА СЪРВЪРА ======================

# Откриване на реалния публичен IP адрес на сървъра
ACTUAL_IP=$(curl -s https://api.ipify.org)

if [[ -z "$ACTUAL_IP" ]]; then
  echo "❌ Неуспешно откриване на публичния IP адрес. Проверете интернет връзката."
  exit 1
fi

while true; do
  read -rp "➤ Въведете публичния IP адрес, на който трябва да работи този виртуален хост (или 'q' за изход): " SERVER_IP

  [[ "$SERVER_IP" == "q" ]] && {
    echo "🚪 Прекратяване по заявка на оператора."
    exit 0
  }

  if [[ "$SERVER_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    if [[ "$SERVER_IP" != "$ACTUAL_IP" ]]; then
      echo "❌ Въведеният IP адрес ($SERVER_IP) не съвпада с реалния IP адрес на сървъра."
      echo "🛑 Скриптът ще бъде прекратен, за да се избегне грешна инсталация."
      exit 1
    fi
    break
  else
    echo "⚠️ Невалиден IP адрес. Моля, опитайте отново."
  fi
done

SUMMARY_SERVER_IP="$SERVER_IP"

# === [2] ВЪВЕЖДАНЕ И ПРОВЕРКА НА ДОМЕЙН ======================================

while true; do
  read -rp "➤ Въведете основен или субдомейн (напр. example.com или blog.example.com), или 'q' за изход: " input_domain

  [[ "$input_domain" == "q" ]] && {
    echo "🚪 Прекратяване по заявка на оператора."
    exit 0
  }

  # Празно поле
  if [[ -z "$input_domain" ]]; then
    echo "⚠️ Домейнът не може да бъде празен. Опитайте отново."
    continue
  fi

  # Проверка за валиден формат
  if ! [[ "$input_domain" =~ ^[a-z0-9.-]+\.[a-z]{2,}$ ]]; then
    echo "⚠️ Невалиден домейн. Уверете се, че е в правилен формат."
    continue
  fi

  # Проверка чрез публичен DNS сървър (Google DNS)
  resolved_ip=$(dig +short "$input_domain" @8.8.8.8 | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n1)

  if [[ -z "$resolved_ip" ]]; then
    echo "❌ Домейнът \"$input_domain\" не се резолвира към IP адрес (според публичния DNS)."
    echo "🔧 Проверете DNS записите и се уверете, че сочат към този сървър."
    continue
  fi

  # Проверка дали съвпада с публичния IP адрес на сървъра
  if [[ "$resolved_ip" != "$SUMMARY_SERVER_IP" ]]; then
    echo "❌ Домейнът се резолвира към $resolved_ip, но публичният IP адрес на сървъра е $SUMMARY_SERVER_IP."
    echo "🛑 Уверете се, че DNS записите сочат към този сървър."
    continue
  fi

  echo "✅ Домейнът се резолвира правилно към IP: $resolved_ip"
  break
done

# Записване в променлива
SUMMARY_DOMAIN="$input_domain"

# Извличане на root домейн
IFS='.' read -ra domain_parts <<< "$SUMMARY_DOMAIN"
domain_parts_count=${#domain_parts[@]}
SUMMARY_ROOT_DOMAIN="${domain_parts[-2]}.${domain_parts[-1]}"

# Определяне дали е субдомейн
if [[ "$SUMMARY_DOMAIN" != "$SUMMARY_ROOT_DOMAIN" ]]; then
  SUMMARY_IS_SUBDOMAIN="yes"
  sub_name="${SUMMARY_DOMAIN%%.$SUMMARY_ROOT_DOMAIN}"
  SUMMARY_WEBROOT="/var/www/$SUMMARY_ROOT_DOMAIN/$sub_name/public_html"
else
  SUMMARY_IS_SUBDOMAIN="no"
  SUMMARY_WEBROOT="/var/www/$SUMMARY_ROOT_DOMAIN/public_html"
fi

# Извеждане на резултата
echo "📌 Разпознат домейн:          $SUMMARY_DOMAIN"
echo "📌 Root домейн:               $SUMMARY_ROOT_DOMAIN"
echo "📌 Тип:                       $( [[ "$SUMMARY_IS_SUBDOMAIN" == "yes" ]] && echo 'субдомейн' || echo 'основен домейн' )"
echo "📁 Директория:                $SUMMARY_WEBROOT"

# === [3] НАЧАЛНА СТРАНИЦА ==========================================

echo ""
echo "Началната страница на вашия хост ще показва следното съобщение:"
echo ""
echo "www.${SUMMARY_DOMAIN}"
echo "This site is under construction."
echo "Вие може да добавите допълнителен текст към този."
echo ""

read -rp "💬 Въведете съобщение (до 160 символа). Натиснете Enter за пропускане или 'q' за прекратяване: " custom_msg

if [[ "$custom_msg" == "q" ]]; then
  echo "🚪 Прекратяване по заявка на оператора."
  exit 0
fi

# Обрязване до 160 символа
custom_msg="${custom_msg:0:160}"

SUMMARY_CUSTOM_MESSAGE="$custom_msg"

if [[ -n "$custom_msg" ]]; then
  echo "✅ Съобщението ще бъде добавено към началната страница."
else
  echo "ℹ️ Няма въведено съобщение – index.html ще съдържа само стандартен текст."
fi

# === [4] ИЗБОР НА PHP ВЕРСИЯ ===============================================

echo ""
echo "🧮 Откриване на наличните PHP версии..."

# Списък с всички поддържани версии от ondrej/php
ALL_PHP_VERSIONS=(8.3 8.2 8.1 8.0 7.4 7.3 7.2 7.1 7.0 5.6)
php_versions_array=()
menu_index=1

# Проверка коя е инсталирана и коя не
for ver in "${ALL_PHP_VERSIONS[@]}"; do
  if [[ -d "/etc/php/$ver" ]]; then
    php_versions_array+=("$ver|installed")
  else
    php_versions_array+=("$ver|missing")
  fi
done

# Меню
echo ""
echo "➤ Изберете PHP версия за този виртуален хост:"
for entry in "${php_versions_array[@]}"; do
  version="${entry%%|*}"
  status="${entry##*|}"

  if [[ $menu_index -eq 1 ]]; then
    label="(по подразбиране – последна стабилна)"
  else
    label=""
  fi

  if [[ "$status" == "installed" ]]; then
    echo "[$menu_index] PHP $version $label"
  else
    echo "[$menu_index] PHP $version ⚠️ (ще бъде инсталирана) $label"
  fi
  ((menu_index++))
done
echo "[q] Прекратяване"

# Избор
while true; do
  read -rp "Вашият избор [1]: " php_choice

  if [[ "$php_choice" == "q" ]]; then
    echo "🚪 Прекратяване по заявка на оператора."
    exit 0
  fi

  if [[ -z "$php_choice" ]]; then
    php_choice=1
  fi

  if ! [[ "$php_choice" =~ ^[0-9]+$ ]] || (( php_choice < 1 || php_choice > ${#php_versions_array[@]} )); then
    echo "⚠️ Невалиден избор. Опитайте отново."
    continue
  fi

  selected_entry="${php_versions_array[$((php_choice - 1))]}"
  selected_version="${selected_entry%%|*}"
  selected_status="${selected_entry##*|}"

  SUMMARY_PHP_VERSION="$selected_version"
  echo "✅ Избрана PHP версия: PHP $selected_version"

  if [[ "$selected_status" == "missing" ]]; then
    SUMMARY_PHP_INSTALL_REQUIRED="yes"
  else
    SUMMARY_PHP_INSTALL_REQUIRED="no"
  fi
  break
done

# === [5] ИЗБОР НА СЕРТИФИКАТ ==============================================

echo ""
echo "🔐 Избор на SSL сертификат:"
echo "  [1] Let's Encrypt (препоръчително, автоматично издаване)"
echo "  [2] Собствен сертификат (въвеждате .crt и .key файлове)"
echo "  [q] Прекратяване"

while true; do
  read -rp "Вашият избор [1]: " ssl_choice

  [[ "$ssl_choice" == "q" ]] && { echo "🚪 Прекратяване по заявка на оператора."; exit 0; }
  [[ -z "$ssl_choice" ]] && ssl_choice=1

  case "$ssl_choice" in
    1)
      SUMMARY_SSL_TYPE="letsencrypt"
      echo "✅ Избрано: Let's Encrypt (ще се използва certbot)"
      break
      ;;
    2)
      while true; do
        read -rp "📄 Въведете пълния път до .crt файла: " crt_path
        [[ "$crt_path" == "q" ]] && exit 0
        if [[ ! -f "$crt_path" ]]; then
          echo "❌ Файлът $crt_path не съществува."
          echo "🛠️ Изберете:"
          echo "  [1] Опитайте отново"
          echo "  [2] Смяна към Let's Encrypt"
          echo "  [q] Изход"
          read -rp "Вашият избор: " retry_choice
          case "$retry_choice" in
            1) continue ;;
            2)
              SUMMARY_SSL_TYPE="letsencrypt"
              echo "🔁 Превключване към Let's Encrypt."
              break 2
              ;;
            q|Q) echo "🚪 Прекратяване."; exit 0 ;;
            *) echo "⚠️ Невалиден избор."; continue ;;
          esac
        else
          break
        fi
      done

      while true; do
        read -rp "📄 Въведете пълния път до .key файла: " key_path
        [[ "$key_path" == "q" ]] && exit 0
        if [[ ! -f "$key_path" ]]; then
          echo "❌ Файлът $key_path не съществува."
          echo "🛠️ Изберете:"
          echo "  [1] Опитайте отново"
          echo "  [2] Смяна към Let's Encrypt"
          echo "  [q] Изход"
          read -rp "Вашият избор: " retry_choice
          case "$retry_choice" in
            1) continue ;;
            2)
              SUMMARY_SSL_TYPE="letsencrypt"
              echo "🔁 Превключване към Let's Encrypt."
              break 2
              ;;
            q|Q) echo "🚪 Прекратяване."; exit 0 ;;
            *) echo "⚠️ Невалиден избор."; continue ;;
          esac
        else
          break
        fi
      done

      SUMMARY_SSL_TYPE="custom"
      SUMMARY_SSL_CRT_PATH="$crt_path"
      SUMMARY_SSL_KEY_PATH="$key_path"
      echo "✅ Сертификатът ще бъде използван от зададените файлове."
      break
      ;;
    *)
      echo "⚠️ Невалиден избор. Изберете 1, 2 или q."
      ;;
  esac
done

# === [6] ЛИМИТ НА ХОСТА (дисково пространство) ======================

domain_clean="${SUMMARY_ROOT_DOMAIN//./_}"
NOMINAL_USER="nomhost__${domain_clean}"
NOMINAL_GROUP="host0_${domain_clean}"
SUMMARY_NOMINAL_USER="$NOMINAL_USER"
SUMMARY_NOMINAL_GROUP="$NOMINAL_GROUP"

echo ""
echo "💽 Създаване на номинален собственик и лимит на дисковото пространство."
echo "Това ще създаде потребител $NOMINAL_USER и група $NOMINAL_GROUP."
echo ""

# Проверка на свободното място на root (в GB)
available_kb=$(df --output=avail / | tail -n1)
available_gb=$((available_kb / 1024 / 1024))
reserve_gb=5
usable_gb=$((available_gb - reserve_gb))

if (( usable_gb < 1 )); then
  echo "❌ Недостатъчно свободно място на диска. Остават само ${available_gb} GB."
  exit 1
fi

# Дефиниране на допустими лимити
all_limits=(1 3 7 15 30)
valid_limits=()
for lim in "${all_limits[@]}"; do
  if (( lim <= usable_gb )); then
    valid_limits+=("$lim")
  fi
done

# Показване на валидните опции
echo "📦 Изберете лимит на дисково пространство за сайта:"
i=1
for lim in "${valid_limits[@]}"; do
  echo "[$i] ${lim} GB"
  ((i++))
done
echo "[q] Прекратяване"

while true; do
  read -rp "Вашият избор [2]: " choice

  [[ "$choice" == "q" ]] && {
    echo "🚪 Прекратяване по заявка на оператора."
    exit 0
  }

  [[ -z "$choice" ]] && choice=2

  if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#valid_limits[@]} )); then
    echo "⚠️ Невалиден избор. Моля, изберете между 1 и ${#valid_limits[@]}, или 'q'."
    continue
  fi

  selected_gb="${valid_limits[$((choice - 1))]}"
  break
done

SUMMARY_DISK_LIMIT_GB="$selected_gb"
SUMMARY_DISK_LIMIT_MB=$((selected_gb * 1024))
SUMMARY_ENABLE_NOMINAL_USER="yes"

echo ""
echo "✅ Номинален собственик:     $SUMMARY_NOMINAL_USER"
echo "✅ Група за достъп:          $SUMMARY_NOMINAL_GROUP"
echo "📦 Дисков лимит:             $SUMMARY_DISK_LIMIT_GB GB"

# === [7] СЪЗДАВАНЕ НА ГЛАВЕН АДМИНИСТРАТОР НА ХОСТА ==================

echo ""
echo "👤 Създаване на главен потребител за управление на този хост."

# Препоръчително потребителско име
DEFAULT_ADMIN_USER="admin_${domain_clean}"

while true; do
  read -rp "🔑 Въведете потребителско име [${DEFAULT_ADMIN_USER}]: " input_user
  if [[ "$input_user" == "q" ]]; then
    echo "🚪 Прекратяване по заявка на оператора."
    exit 0
  fi
  [[ -z "$input_user" ]] && input_user="$DEFAULT_ADMIN_USER"

  # Проверка дали потребителят вече съществува
  if id "$input_user" &>/dev/null; then
    echo "⚠️ Потребителят '$input_user' вече съществува. Моля, изберете друго име."
  else
    break
  fi
done

SUMMARY_ADMIN_USER="$input_user"

# Въвеждане на парола с потвърждение
while true; do
  read -rsp "🔒 Въведете парола за $SUMMARY_ADMIN_USER: " pass1
  echo
  read -rsp "🔒 Повторете паролата: " pass2
  echo
  if [[ "$pass1" != "$pass2" ]]; then
    echo "❗ Паролите не съвпадат. Опитайте отново."
  elif [[ ${#pass1} -lt 8 ]]; then
    echo "❗ Паролата трябва да е поне 8 символа."
  else
    break
  fi
done

SUMMARY_ADMIN_PASS="$pass1"

echo ""
echo "✅ Потребител за управление: $SUMMARY_ADMIN_USER"

# === [8] СЪЗДАВАНЕ НА БАЗА ДАННИ =========================================

echo ""
echo "🗄️  Създаване на база данни (MariaDB) за хоста"
echo "-------------------------------------------------------------------------"
echo "Име на базата и потребителя ще бъде извлечено от домейна."
echo ""

db_name="db_${SUMMARY_ROOT_DOMAIN//./_}"
db_user="$db_name"
db_password="$SUMMARY_ADMIN_PASSWORD"

echo "➡️  Предложено име на базата:      $db_name"
echo "➡️  Потребител за базата:          $db_user"
echo "➡️  Паролата ще бъде тази на хост администратора."

echo ""
echo "🗄️  Искате ли да създадете база данни за този хост?"
echo "  [1] Да"
echo "  [2] Не (по подразбиране)"
echo "  [q] Прекратяване"

while true; do
  read -rp "Вашият избор [2]: " db_choice
  [[ "$db_choice" == "q" ]] && {
    echo "🚪 Прекратяване по заявка на оператора."
    exit 0
  }

  [[ -z "$db_choice" ]] && db_choice=2

  case "$db_choice" in
    1)
      SUMMARY_DB_CREATE="yes"
      SUMMARY_DB_NAME="$db_name"
      SUMMARY_DB_USER="$db_user"
      SUMMARY_DB_PASSWORD="$db_password"
      echo "✅ Базата ще бъде създадена."
      break
      ;;
    2)
      SUMMARY_DB_CREATE="no"
      SUMMARY_DB_NAME="n/a"
      SUMMARY_DB_USER="n/a"
      SUMMARY_DB_PASSWORD="n/a"
      echo "ℹ️  Базата няма да бъде създадена."
      break
      ;;
    *)
      echo "⚠️  Невалиден избор. Моля, изберете 1, 2 или q."
      ;;
  esac
done

# === [9] СЪЗДАВАНЕ НА FTP ДОСТЪП ===========================================

echo ""
echo "📡 Създаване на FTP достъп за главния администратор на хоста..."

FTP_USER="$SUMMARY_ADMIN_USER"
FTP_HOME_DIR="$SUMMARY_WEBROOT"

# Проверка за наличност на vsftpd
if ! dpkg -s vsftpd >/dev/null 2>&1; then
  echo "⏳ Ще бъде инсталиран vsftpd сървър."
  SUMMARY_NEEDS_VSFTPD="yes"
else
  echo "✅ Наличен vsftpd сървър."
  SUMMARY_NEEDS_VSFTPD="no"
fi

SUMMARY_CREATE_FTP="yes"
SUMMARY_FTP_USER="$FTP_USER"
SUMMARY_FTP_HOME="$FTP_HOME_DIR"

echo "✅ Ще бъде създаден FTP профил за: $FTP_USER"
echo "📁 с достъп само до: $FTP_HOME_DIR"

# === [10] ПРЕДВАРИТЕЛЕН ПРЕГЛЕД И ПОТВЪРЖДЕНИЕ ==============================

echo ""
echo "🧾 Преглед на конфигурацията преди инсталация:"
echo "------------------------------------------------------------"
printf "🌐 Домейн:                   %s\n" "$SUMMARY_DOMAIN"
printf "🔢 Root домейн:              %s\n" "$SUMMARY_ROOT_DOMAIN"
printf "📁 Директория:               %s\n" "$SUMMARY_WEBROOT"
printf "🌐 Тип:                      %s\n" "$( [[ "$SUMMARY_IS_SUBDOMAIN" == "yes" ]] && echo 'субдомейн' || echo 'основен домейн' )"
printf "💬 Съобщение за сайта:       %s\n" "${SUMMARY_CUSTOM_MESSAGE:-(стандартно)}"
printf "🐘 PHP версия:               PHP %s\n" "$SUMMARY_PHP_VERSION"
printf "🔐 SSL сертификат:           %s\n" "$( [[ "$SUMMARY_SSL_TYPE" == "letsencrypt" ]] && echo "Let's Encrypt" || echo "Собствен сертификат" )"
[[ "$SUMMARY_SSL_TYPE" == "custom" ]] && {
  printf "📄 .crt файл:                %s\n" "$SUMMARY_CUSTOM_CRT"
  printf "🔑 .key файл:                %s\n" "$SUMMARY_CUSTOM_KEY"
}
printf "👤 Номинален собственик:     %s\n" "$SUMMARY_NOMINAL_USER"
printf "👥 Група за достъп:          %s\n" "$SUMMARY_NOMINAL_GROUP"
printf "📦 Дисков лимит:             %s GB\n" "$SUMMARY_DISK_LIMIT_GB"
echo "------------------------------------------------------------"

echo ""
echo "🟢 Готови ли сте да продължите с инсталацията?"
echo "  [y] Да, стартирай инсталацията"
echo "  [r] Рестарт на скрипта (ще загубите въведените данни)"
echo "  [q] Прекратяване"

while true; do
  read -rp "Вашият избор [y/r/q]: " confirm_choice

  case "$confirm_choice" in
    y|Y)
      echo "✅ Потвърдено. Продължаване към инсталацията..."
      break
      ;;
    r|R)
      echo "🔄 Рестарт на скрипта..."
      exec "$0"
      ;;
    q|Q)
      echo "🚪 Прекратяване по заявка на оператора."
      exit 0
      ;;
    *)
      echo "⚠️ Невалиден избор. Изберете [y], [r] или [q]."
      ;;
  esac
done
