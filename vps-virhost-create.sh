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

# === [2] ВЪВЕЖДАНЕ И АНАЛИЗ НА ДОМЕЙН ======================================

while true; do
  read -rp "🌐 Въведете основен или субдомейн (напр. example.com или blog.example.com) или 'q' за изход: " input_domain

  [[ "$input_domain" == "q" ]] && {
    echo "🚪 Прекратяване по заявка на оператора."
    exit 0
  }

  # Празно поле
  if [[ -z "$input_domain" ]]; then
    echo "⚠️ Домейнът не може да бъде празен. Опитайте отново."
    continue
  fi

  # Основна проверка за валиден формат
  if ! [[ "$input_domain" =~ ^[a-z0-9.-]+\.[a-z]{2,}$ ]]; then
    echo "⚠️ Невалиден домейн. Уверете се, че е в правилен формат."
    continue
  fi

  # Проверка дали се резолвира
  resolved_ip=$(dig +short "$input_domain" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n1)

  if [[ -z "$resolved_ip" ]]; then
    echo "❌ Домейнът \"$input_domain\" не се резолвира към IP адрес."
    echo "🔧 Проверете DNS записите и се уверете, че сочат към този сървър."
    continue
  fi

  echo "✅ Домейнът се резолвира към IP: $resolved_ip"
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
echo "📌 Разпознат домейн:           $SUMMARY_DOMAIN"
echo "📌 Root домейн:               $SUMMARY_ROOT_DOMAIN"
echo "📌 Тип:                       $( [[ "$SUMMARY_IS_SUBDOMAIN" == "yes" ]] && echo 'субдомейн' || echo 'основен домейн' )"
echo "📁 Очаквана директория:       $SUMMARY_WEBROOT"

# === [3] ПОЗДРАВИТЕЛНО СЪОБЩЕНИЕ ==========================================

echo ""
echo "📄 Можете да добавите кратко съобщение към началната страница (index.html)"
echo "ℹ️ Например: 'Добре дошли в новия сайт! Работим по съдържанието.'"
echo "   (До 160 символа. Натиснете Enter за пропускане или 'q' за прекратяване.)"
echo ""

read -rp "💬 Въведете съобщение: " custom_msg

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
echo "🧮 Откриване на наличните PHP версии в системата..."
php_versions_array=()
available_php_versions=$(ls /etc/php/ 2>/dev/null | sort -Vr)

if [[ -z "$available_php_versions" ]]; then
  echo "❌ Не са открити инсталирани PHP версии. Скриптът не може да продължи."
  exit 1
fi

i=1
echo ""
echo "➤ Изберете PHP версия за този виртуален хост:"
for ver in $available_php_versions; do
  php_versions_array+=("$ver")
  if [[ $i -eq 1 ]]; then
    echo "[$i] PHP $ver (по подразбиране – последна стабилна)"
  elif [[ "$ver" =~ ^7\.|^5\. ]]; then
    echo "[$i] PHP $ver ⚠️ (остаряла)"
  else
    echo "[$i] PHP $ver"
  fi
  ((i++))
done
echo "[q] Прекратяване"

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

  SUMMARY_PHP_VERSION="${php_versions_array[$((php_choice - 1))]}"
  echo "✅ Избрана PHP версия: PHP $SUMMARY_PHP_VERSION"
  break
done

# === [5] ИЗБОР НА СЕРТИФИКАТ ==============================================

echo ""
echo "🔐 Всеки виртуален хост трябва да има SSL сертификат."
echo "Можете да изберете:"
echo "  [1] Let's Encrypt (препоръчително, автоматично издаване)"
echo "  [2] Собствен сертификат (въвеждате .crt и .key файлове)"
echo "  [q] Прекратяване"

while true; do
  read -rp "Вашият избор [1]: " ssl_choice

  if [[ "$ssl_choice" == "q" ]]; then
    echo "🚪 Прекратяване по заявка на оператора."
    exit 0
  fi

  if [[ -z "$ssl_choice" ]]; then
    ssl_choice=1
  fi

  case "$ssl_choice" in
    1)
      SUMMARY_SSL_TYPE="letsencrypt"
      echo "✅ Избрано: Let's Encrypt (ще се използва certbot)"
      break
      ;;
    2)
      SUMMARY_SSL_TYPE="custom"
      echo "✅ Избрано: собствен сертификат"
      echo "ℹ️ Въведете пълния път до .crt и .key файловете при потвърждение."
      break
      ;;
    *)
      echo "⚠️ Невалиден избор. Моля, изберете 1, 2 или q."
      ;;
  esac
done

# === [6] ЛИМИТИ НА ХОСТА (вкл. дисково пространство) ======================

domain_clean="${SUMMARY_ROOT_DOMAIN//./_}"
NOMINAL_USER="nom_${domain_clean}"
NOMINAL_GROUP="grp_${domain_clean}"
SUMMARY_NOMINAL_USER="$NOMINAL_USER"
SUMMARY_NOMINAL_GROUP="$NOMINAL_GROUP"

echo ""
echo "💽 Искате ли да създадете номинален собственик и да наложите лимит на дисково пространство?"
echo "Това ще създаде потребител $NOMINAL_USER и група $NOMINAL_GROUP"
echo ""
echo "  [1] Да, с лимит (препоръчително)"
echo "  [2] Да, без лимит"
echo "  [3] Не – не създавай потребител и група"
echo "  [q] Прекратяване"

while true; do
  read -rp "Вашият избор [1]: " limit_choice

  [[ "$limit_choice" == "q" ]] && {
    echo "🚪 Прекратяване по заявка на оператора."
    exit 0
  }

  [[ -z "$limit_choice" ]] && limit_choice=1

  case "$limit_choice" in
    1)
      SUMMARY_ENABLE_NOMINAL_USER="yes"
      echo ""
      echo "➤ Въведете лимит на дисково пространство (в MB, напр. 500): "
      read -rp "MB: " disk_limit_mb
      if ! [[ "$disk_limit_mb" =~ ^[0-9]+$ ]]; then
        echo "❌ Невалиден лимит. Прекратяване."
        exit 1
      fi
      SUMMARY_DISK_LIMIT_MB="$disk_limit_mb"
      break
      ;;
    2)
      SUMMARY_ENABLE_NOMINAL_USER="yes"
      SUMMARY_DISK_LIMIT_MB="unlimited"
      break
      ;;
    3)
      SUMMARY_ENABLE_NOMINAL_USER="no"
      SUMMARY_DISK_LIMIT_MB="n/a"
      break
      ;;
    *)
      echo "⚠️ Невалиден избор. Моля, изберете 1, 2, 3 или q."
      ;;
  esac
done

echo ""
echo "✅ Номинален собственик:     $SUMMARY_NOMINAL_USER"
echo "✅ Група за достъп:          $SUMMARY_NOMINAL_GROUP"
echo "📦 Дисков лимит:             $SUMMARY_DISK_LIMIT_MB"

