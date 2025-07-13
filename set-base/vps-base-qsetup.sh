#!/bin/bash

# ==========================================================================
#  vps-base-qsetup - Базова конфигурация на VPS сървър (локално изпълнение)
# --------------------------------------------------------------------------
#  Версия: 1.0
#  Дата: 2025-06-19
#  Автор: Ilko Yordanov / NetGalaxy
# ==========================================================================
#
#  Този скрипт извършва начална, безопасна и автоматизирана конфигурация на
#  VPS сървър. Изпълнява се директно на сървъра, не изисква SSH към други машини.
#
#  Етапи:
#    1. Въвеждане на нужната информация
#    2. Проверка за валидност
#    3. Потвърждение от оператора
#    4. Конфигурация на сървъра
# ==========================================================================

# === ПОМОЩНА ИНФОРМАЦИЯ ===================================================
show_help() {
  echo "Използване: vps-base-qsetup.sh [опция]"
  echo ""
  echo "Автоматизирана и безопасна начална конфигурация на локален VPS сървър."
  echo ""
  echo "Опции:"
  echo "  --version       Показва версията на скрипта"
  echo "  --help          Показва тази помощ"
}

# === ОБРАБОТКА НА ОПЦИИ ====================================================
if [[ $# -gt 0 ]]; then
  case "$1" in
    --version)
      echo "vps-base-qsetup версия 1.0 (19 юни 2025 г.)"
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

# === ПОКАЗВАНЕ НА ЗАГЛАВИЕТО ===============================================
echo ""
echo ""
echo -e "\e[32m=========================================="
echo -e " НАЧАЛНА КОНФИГУРАЦИЯ НА ОТДАЛЕЧЕН СЪРВЪР"
echo -e "==========================================\e[0m"
echo ""

# === [0] ИНИЦИАЛИЗАЦИЯ НА МАРКЕРНИТЕ ФАЙЛОВЕ НА ПЛАТФОРМАТА ================

NETGALAXY_DIR="/etc/netgalaxy"
MODULES_FILE="$NETGALAXY_DIR/todo.modules"
SETUP_ENV_FILE="$NETGALAXY_DIR/setup.env"

# 🔒 Проверка дали конфигурацията вече е била завършена
if [[ -f "$SETUP_ENV_FILE" ]] && sudo grep -q '^SETUP_VPS_BASE_STATUS=✅' "$SETUP_ENV_FILE"; then
  echo "🛑 Този скрипт вече е бил изпълнен на този сървър."
  echo "   Повторно изпълнение не се разрешава за предпазване от сбой на системата."

  # Самоизтриване на скрипта (ако съществува като файл)
  [[ -f "$0" ]] && rm -- "$0"
  exit 0
fi

# ✅ Ако не е завършена, продължаваме с инициализация

# Създаване на директорията, ако не съществува
if [[ ! -d "$NETGALAXY_DIR" ]]; then
  echo "📁 Създаване на директория за NetGalaxy: $NETGALAXY_DIR"
  sudo mkdir -p "$NETGALAXY_DIR"
  sudo chmod 755 "$NETGALAXY_DIR"
  echo "✅ Директорията беше създадена успешно."
fi

# Създаване на файла todo.modules, ако не съществува
if [[ ! -f "$MODULES_FILE" ]]; then
  echo "📝 Създаване на лог файл за изпълнени модули ($MODULES_FILE)..."
  sudo touch "$MODULES_FILE"
  sudo chmod 644 "$MODULES_FILE"
  echo "✅ Файлът todo.modules беше създаден успешно (празен)."
else
  echo "ℹ️ Открит съществуващ файл todo.modules – ще се добавят нови редове при изпълнение на модулите."
fi

# Създаване на setup.env, ако не съществува
if [[ ! -f "$SETUP_ENV_FILE" ]]; then
  echo "⚙️ Създаване на конфигурационен файл setup.env..."
  sudo touch "$SETUP_ENV_FILE"
  sudo chmod 600 "$SETUP_ENV_FILE"
  echo "# NetGalaxy Server Setup Metadata" | sudo tee "$SETUP_ENV_FILE" > /dev/null
  echo "✅ setup.env беше създаден успешно."
else
  echo "ℹ️ Открит съществуващ файл setup.env – ще бъде допълван при нужда."
fi
echo ""
echo ""


# === [МОДУЛ 1] ПРОВЕРКА IP АДРЕС НА СЪРВЪРА ====================
echo "[1] ПРОВЕРКА IP АДРЕС НА СЪРВЪРА..."
echo "-----------------------------------------------------------"
echo ""

MODULE_NAME="mod_01_ip_check"
MODULES_FILE="/etc/netgalaxy/todo.modules"
SETUP_ENV_FILE="/etc/netgalaxy/setup.env"

# Проверка дали модулът вече е изпълнен
if grep -q "^$MODULE_NAME\b" "$MODULES_FILE"; then
  echo "🔁 Пропускане на $MODULE_NAME (вече е отбелязан като изпълнен)..."
  echo ""
else {
  while true; do
    printf "🌐 Въведете публичния IP адрес на сървъра (или 'q' за изход): "
    read SERVER_IP

    if [[ "$SERVER_IP" == "q" || "$SERVER_IP" == "Q" ]]; then
      echo "❎ Скриптът беше прекратен от потребителя."
      exit 0
    fi

    if ! [[ "$SERVER_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "❌ Невалиден IP адрес. Моля, въведете валиден IPv4 адрес (напр. 192.168.1.100)."
      continue
    fi

    ACTUAL_IP=$(curl -s ifconfig.me)

    if [[ "$ACTUAL_IP" != "$SERVER_IP" ]]; then
      echo ""
      echo "🚫 Скриптът не е стартиран на сървъра с въведения IP адрес."
      echo "⚠️ Несъответствие! Въведеният IP не отговаря на реалния IP адрес на машината."
      echo ""
      read -p "🔁 Искате ли да опитате отново? [Enter за ДА, 'q' за изход]: " retry
      if [[ "$retry" == "q" || "$retry" == "Q" ]]; then
        echo "⛔ Скриптът беше прекратен от потребителя след $MODULE_NAME."
        exit 0
      fi
      echo ""
    else
      echo "✅ Потвърдено: скриптът е стартиран на сървъра с IP $SERVER_IP."
      break
    fi
  done

  # ✅ Записване на IP адреса в setup.env
  echo "SERVER_IP=\"$SERVER_IP\"" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null

  # ✅ Отбелязване на изпълнен модул
  echo "$MODULE_NAME" | sudo tee -a "$MODULES_FILE" > /dev/null
}; fi
echo ""
echo ""


# === [МОДУЛ 2] КОНФИГУРАЦИЯ НА СЪРВЪРНИЯ ДОМЕЙН (FQDN) ========================
echo "[2] КОНФИГУРАЦИЯ НА СЪРВЪРНИЯ ДОМЕЙН (FQDN)..."
echo "-------------------------------------------------------------------------"
echo ""

MODULE_NAME="mod_02_fqdn_config"
MODULES_FILE="/etc/netgalaxy/todo.modules"
SETUP_ENV_FILE="/etc/netgalaxy/setup.env"

# Проверка дали модулът вече е изпълнен
if grep -q "^$MODULE_NAME\b" "$MODULES_FILE"; then
  echo "🔁 Пропускане на $MODULE_NAME (вече е отбелязан като изпълнен)..."
  echo ""
else {
  while true; do
    printf "👉 Въведете домейна на сървъра (FQDN) или 'q' за изход: "
    read FQDN

    if [[ "$FQDN" == "q" || "$FQDN" == "Q" ]]; then
      echo "❎ Скриптът беше прекратен от потребителя."
      exit 0
    fi

    if [[ -z "$FQDN" ]]; then
      echo "❌ Домейнът не може да бъде празен. Опитайте отново."
      continue
    fi

    if [[ ! "$FQDN" =~ ^([a-zA-Z0-9][-a-zA-Z0-9]*\.)+[a-zA-Z]{2,}$ ]]; then
      echo "❌ Невалиден формат на домейн. Пример за валиден: example.com"
      continue
    fi

    if ! getent hosts "$FQDN" >/dev/null; then
      echo "⚠️ Внимание: Домейнът '$FQDN' не резолвира в момента."
      while true; do
        printf "❓ Искате ли да продължите с този домейн? (y / n): "
        read -r confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          break
        elif [[ "$confirm" =~ ^[Nn]$ || -z "$confirm" ]]; then
          continue 2
        else
          echo "❌ Моля, отговорете с 'y' за да продължите или 'n' за нов домейн."
        fi
      done
    fi
    break
  done

  # Задаване на hostname
  sudo hostnamectl set-hostname "$FQDN"
  echo "✅ Hostname е зададен: $FQDN"

  # Добавяне във /etc/hosts, ако липсва
  SERVER_IP=$(curl -s ifconfig.me)
  if ! grep -q "$FQDN" /etc/hosts; then
    echo "$SERVER_IP    $FQDN" | sudo tee -a /etc/hosts > /dev/null
    echo "✅ Добавен ред в /etc/hosts: $SERVER_IP $FQDN"
  else
    echo "ℹ️ Домейнът вече съществува във /etc/hosts"
  fi

  # Запис в setup.env
  echo "FQDN=\"$FQDN\"" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null

  # Отбелязване на изпълнен модул
  echo "$MODULE_NAME" | sudo tee -a "$MODULES_FILE" > /dev/null

  echo ""
  echo ""
}; fi


# === [МОДУЛ 3] ОБНОВЯВАНЕ НА СИСТЕМАТА ========================================
echo "[3] ОБНОВЯВАНЕ НА СИСТЕМАТА..."
echo "-------------------------------------------------------------------------"
echo ""

MODULE_NAME="mod_03_system_update"
MODULES_FILE="/etc/netgalaxy/todo.modules"
SETUP_ENV_FILE="/etc/netgalaxy/setup.env"

# Проверка дали модулът вече е изпълнен
if grep -q "^$MODULE_NAME\b" "$MODULES_FILE"; then
  echo "🔁 Пропускане на $MODULE_NAME (вече е отбелязан като изпълнен)..."
  echo ""
else {
  # Изчакване, ако системата е заключена от друг apt процес
  MAX_WAIT=60
  COUNTER=0
  echo "⏳ Проверка за заетост на пакетната система..."
  while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
    sleep 1
    ((COUNTER++))
    if ((COUNTER >= MAX_WAIT)); then
      echo "❌ Пакетната система е заключена от друг процес повече от ${MAX_WAIT} секунди."
      echo "   Моля, опитайте отново по-късно."

      echo "RESULT_SYSTEM_UPDATE=❌" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
      exit 1
    fi
  done

  # Изпълнение на обновяването
  if sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get autoremove -y; then
    echo "✅ Системата е успешно обновена."

    echo "RESULT_SYSTEM_UPDATE=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null

    # Отбелязване на изпълнен модул
    echo "$MODULE_NAME" | sudo tee -a "$MODULES_FILE" > /dev/null
  else
    echo "❌ Възникна грешка при обновяване на системата. Проверете горните съобщения."

    echo "RESULT_SYSTEM_UPDATE=❌" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
    exit 1
  fi
}; fi
echo ""
echo ""

# === [МОДУЛ 4] ИНСТАЛИРАНЕ НА ОСНОВНИ ИНСТРУМЕНТИ =============================
echo "[4] ИНСТАЛИРАНЕ НА ОСНОВНИ ИНСТРУМЕНТИ..."
echo "-------------------------------------------------------------------------"
echo ""

MODULE_NAME="mod_04_base_tools"
MODULES_FILE="/etc/netgalaxy/todo.modules"
SETUP_ENV_FILE="/etc/netgalaxy/setup.env"

# Проверка дали модулът вече е изпълнен
if grep -q "^$MODULE_NAME\b" "$MODULES_FILE"; then
  echo "🔁 Пропускане на $MODULE_NAME (вече е отбелязан като изпълнен)..."
  echo ""
else {

  REQUIRED_PACKAGES=(nano unzip git curl wget net-tools htop)

  if sudo apt-get install -y "${REQUIRED_PACKAGES[@]}"; then
    echo "✅ Основните инструменти бяха инсталирани успешно."

    echo "RESULT_BASE_TOOLS=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null

    # Отбелязване на изпълнен модул
    echo "$MODULE_NAME" | sudo tee -a "$MODULES_FILE" > /dev/null
  else
    echo "❌ Възникна грешка при инсталирането на основните инструменти."

    echo "RESULT_BASE_TOOLS=❌" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
    exit 1
  fi
}; fi
echo ""
echo ""


# === [МОДУЛ 5] НАСТРОЙКА НА ЛОКАЛИЗАЦИИ =======================================
echo "[5] НАСТРОЙКА НА ЛОКАЛИЗАЦИИ..."
echo "-------------------------------------------------------------------------"
echo ""

MODULE_NAME="mod_05_locales"
MODULES_FILE="/etc/netgalaxy/todo.modules"
SETUP_ENV_FILE="/etc/netgalaxy/setup.env"

# Проверка дали модулът вече е изпълнен
if grep -q "^$MODULE_NAME\b" "$MODULES_FILE"; then
  echo "🔁 Пропускане на $MODULE_NAME (вече е отбелязан като изпълнен)..."
  echo ""
else {

  RESULT_LOCALES="❔"

  echo "🌐 Инсталиране на езикови пакети (BG, RU)..."
  if sudo apt-get install -y language-pack-bg language-pack-ru; then
    echo "✅ Езиковите пакети са инсталирани."
  else
    echo "⚠️ Неуспешна инсталация на езикови пакети. Продължаваме."
    RESULT_LOCALES="⚠️"
  fi

  echo "🔧 Активиране на UTF-8 локали в /etc/locale.gen..."
  sudo sed -i '/^# *bg_BG.UTF-8 UTF-8/s/^# *//g' /etc/locale.gen
  sudo sed -i '/^# *ru_RU.UTF-8 UTF-8/s/^# *//g' /etc/locale.gen
  sudo sed -i '/^# *en_US.UTF-8 UTF-8/s/^# *//g' /etc/locale.gen

  grep -qxF 'bg_BG.UTF-8 UTF-8' /etc/locale.gen || echo 'bg_BG.UTF-8 UTF-8' | sudo tee -a /etc/locale.gen > /dev/null
  grep -qxF 'ru_RU.UTF-8 UTF-8' /etc/locale.gen || echo 'ru_RU.UTF-8 UTF-8' | sudo tee -a /etc/locale.gen > /dev/null
  grep -qxF 'en_US.UTF-8 UTF-8' /etc/locale.gen || echo 'en_US.UTF-8 UTF-8' | sudo tee -a /etc/locale.gen > /dev/null

  echo "⚙️ Генериране на UTF-8 локали (задължително за съвместимост с NetGalaxy)..."
  if sudo locale-gen && sudo update-locale; then
    echo "✅ Локалите са успешно конфигурирани."
    [[ "$RESULT_LOCALES" == "❔" ]] && RESULT_LOCALES="✅"
  else
    echo "❌ Грешка при генериране на локали."
    RESULT_LOCALES="❌"
  fi

  # 📝 Записване на резултата в setup.env
  echo "RESULT_LOCALES=\"$RESULT_LOCALES\"" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null

  # ✅ Отбелязване на изпълнен модул (ако поне езиците са инсталирани)
  if [[ "$RESULT_LOCALES" == "✅" || "$RESULT_LOCALES" == "⚠️" ]]; then
    echo "$MODULE_NAME" | sudo tee -a "$MODULES_FILE" > /dev/null
  fi
}; fi
echo ""
echo ""


# === [МОДУЛ 6] НАСТРОЙКА НА ВРЕМЕВА ЗОНА И NTP СИНХРОНИЗАЦИЯ ==================
echo "[6] НАСТРОЙКА НА ВРЕМЕВА ЗОНА И NTP СИНХРОНИЗАЦИЯ..."
echo "-------------------------------------------------------------------------"
echo ""

MODULE_NAME="mod_06_timezone_ntp"
MODULES_FILE="/etc/netgalaxy/todo.modules"
SETUP_ENV_FILE="/etc/netgalaxy/setup.env"

# Проверка дали модулът вече е изпълнен
if grep -q "^$MODULE_NAME\b" "$MODULES_FILE"; then
  echo "🔁 Пропускане на $MODULE_NAME (вече е отбелязан като изпълнен)..."
  echo ""
else

  RESULT_TIMEZONE_NTP="❔"

  echo "🌍 Задаване на времева зона на UTC (унифициран стандарт в мрежата NetGalaxy)..."
  if sudo timedatectl set-timezone UTC; then
    echo "✅ Времевата зона е зададена на UTC."
  else
    echo "❌ Неуспешна смяна на времевата зона."
    RESULT_TIMEZONE_NTP="❌"
    echo "RESULT_TIMEZONE_NTP=\"$RESULT_TIMEZONE_NTP\"" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
    return 1 2>/dev/null || exit 1
  fi

  echo "🔧 Изключване на други NTP услуги..."
  sudo systemctl stop ntpd 2>/dev/null && sudo systemctl disable ntpd 2>/dev/null
  sudo systemctl stop systemd-timesyncd 2>/dev/null && sudo systemctl disable systemd-timesyncd 2>/dev/null

  echo "📦 Инсталиране и конфигуриране на chrony..."
  if ! sudo apt-get install -y chrony; then
    echo "❌ Неуспешна инсталация на chrony."
    RESULT_TIMEZONE_NTP="❌"
    echo "RESULT_TIMEZONE_NTP=\"$RESULT_TIMEZONE_NTP\"" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
    return 1 2>/dev/null || exit 1
  fi

  echo "⚙️ Конфигуриране на /etc/chrony/chrony.conf..."
  NTP_SERVERS=(0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org)
  cat <<EOF | sudo tee /etc/chrony/chrony.conf > /dev/null
server ${NTP_SERVERS[0]} iburst
server ${NTP_SERVERS[1]} iburst
server ${NTP_SERVERS[2]} iburst
server ${NTP_SERVERS[3]} iburst

rtcsync
makestep 1.0 3
driftfile /var/lib/chrony/drift
logdir /var/log/chrony
EOF

  echo "🔄 Рестартиране на услугата chrony..."
  sudo systemctl restart chrony
  sudo systemctl enable chrony

  echo "🔎 Проверка на синхронизацията..."
  timedatectl | grep 'Time zone'
  echo "NTP статус:"
  chronyc tracking | grep -E 'Stratum|System time'
  chronyc sources | grep '^\^\*'

  echo "✅ Времевата зона и синхронизация са успешно настроени."
  RESULT_TIMEZONE_NTP="✅"

  # 📝 Записване на резултата
  echo "RESULT_TIMEZONE_NTP=\"$RESULT_TIMEZONE_NTP\"" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null

  # ✅ Отбелязване на изпълнен модул
  echo "$MODULE_NAME" | sudo tee -a "$MODULES_FILE" > /dev/null
fi
echo ""
echo ""


# === [МОДУЛ 7] СЪЗДАВАНЕ НА НОВ АДМИНИСТРАТОРСКИ ПРОФИЛ ========================
echo "[7] СЪЗДАВАНЕ НА НОВ АДМИНИСТРАТОРСКИ ПРОФИЛ"
echo "-------------------------------------------------------------------------"
echo ""

MODULE_NAME="mod_07_admin_user"
MODULES_FILE="/etc/netgalaxy/todo.modules"
SETUP_ENV_FILE="/etc/netgalaxy/setup.env"

# Проверка дали модулът вече е изпълнен
if grep -q "^$MODULE_NAME\b" "$MODULES_FILE"; then
  echo "🔁 Пропускане на $MODULE_NAME (вече е отбелязан като изпълнен)..."
  echo ""
else

echo "🔐 По съображения за сигурност, root достъпът чрез SSH ще бъде забранен."
echo "✅ Ще бъде създаден таен потребител с root права за администриране на сървъра."
echo ""

RESULT_ADMIN_USER="❔"

# === Въвеждане на име на администратор ===
while true; do
  printf "👉 Въведете потребителско име за администратор (мин. 5 символа или 'q' за изход): "
  read ADMIN_USER

  if [[ "$ADMIN_USER" == "q" || "$ADMIN_USER" == "Q" ]]; then
    echo "❎ Скриптът беше прекратен от потребителя."
    exit 0
  fi

  if [[ -z "$ADMIN_USER" ]]; then
    echo "❌ Полето за потребителското име не може да бъде празно."
    continue
  fi

  if [[ ${#ADMIN_USER} -lt 5 ]]; then
    echo "❌ Потребителското име трябва да бъде поне 5 символа."
    continue
  fi

  if [[ ! "$ADMIN_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    echo "❌ Невалидно потребителско име. Разрешени са само малки букви, цифри, '-', '_' и да не започва с цифра."
    continue
  fi

  if id "$ADMIN_USER" &>/dev/null; then
    echo "⚠️ Потребителят '$ADMIN_USER' вече съществува."
    echo ""
    while true; do
      read -p "❓ Искате ли да използвате съществуващия '$ADMIN_USER' като администратор? (y/n): " use_existing
      if [[ "$use_existing" =~ ^[Yy]$ ]]; then
        sudo usermod -aG sudo "$ADMIN_USER"
        echo "🔑 Копиране на SSH ключовете от root в ~/.ssh на $ADMIN_USER..."
        sudo mkdir -p /home/"$ADMIN_USER"/.ssh
        sudo cp -r /root/.ssh/* /home/"$ADMIN_USER"/.ssh/ 2>/dev/null
        sudo chown -R "$ADMIN_USER":"$ADMIN_USER" /home/"$ADMIN_USER"/.ssh
        sudo chmod 700 /home/"$ADMIN_USER"/.ssh
        sudo chmod 600 /home/"$ADMIN_USER"/.ssh/*
        RESULT_ADMIN_USER="✅"
        break 2
      elif [[ "$use_existing" =~ ^[Nn]$ ]]; then
        echo "🔁 Моля, въведете ново потребителско име."
        break
      else
        echo "❌ Моля, отговорете с 'y' или 'n'."
      fi
    done
  else
    break
  fi
done

# === Въвеждане на парола ===
echo "🛡️ Паролата трябва да отговаря на следните условия:"
echo "   - Минимум 8 символа"
echo "   - Поне една латинска малка буква (a-z)"
echo "   - Поне една латинска главна буква (A-Z)"
echo "   - Поне една цифра (0-9)"
echo "❗ Внимание: Проверете на какъв език въвеждате, ако използвате специфични букви (напр. кирилица)"
echo ""

while true; do
  printf "🔑 Въведете парола за %s: " "$ADMIN_USER"
  read -s PASSWORD_1
  echo

  if [[ -z "$PASSWORD_1" ]]; then
    echo "❌ Паролата не може да е празна."
    continue
  fi

  if (( ${#PASSWORD_1} < 8 )) || \
     ! [[ "$PASSWORD_1" =~ [a-z] ]] || \
     ! [[ "$PASSWORD_1" =~ [A-Z] ]] || \
     ! [[ "$PASSWORD_1" =~ [0-9] ]]; then
    echo "❌ Паролата трябва да съдържа поне 8 символа, включително малка и главна латинска буква, и цифра."
    continue
  fi

  if LC_ALL=C grep -q '[^ -~]' <<< "$PASSWORD_1"; then
    echo "⚠️ Внимание: В паролата са открити символи извън латиницата."
    while true; do
      read -p "❓ Искате ли да продължите с тази парола? (y/n): " confirm_charset
      if [[ "$confirm_charset" =~ ^[Yy]$ ]]; then
        break
      elif [[ "$confirm_charset" =~ ^[Nn]$ || -z "$confirm_charset" ]]; then
        continue 2
      else
        echo "❌ Моля, отговорете с 'y' или 'n'."
      fi
    done
  fi

  printf "🔑 Повторете паролата: "
  read -s PASSWORD_2
  echo

  if [[ "$PASSWORD_1" != "$PASSWORD_2" ]]; then
    echo "❌ Паролите не съвпадат. Опитайте отново."
  else
    break
  fi
done

# === Създаване на нов потребител ===
if ! id "$ADMIN_USER" &>/dev/null; then
  echo "👤 Създаване на нов потребител '$ADMIN_USER'..."
  if sudo useradd -m -s /bin/bash "$ADMIN_USER" && \
     echo "$ADMIN_USER:$PASSWORD_1" | sudo chpasswd && \
     sudo usermod -aG sudo "$ADMIN_USER"; then
    echo "✅ Потребителят '$ADMIN_USER' беше създаден с root права."
    echo "🔑 Копиране на SSH ключовете от root в ~/.ssh на $ADMIN_USER..."
    sudo mkdir -p /home/"$ADMIN_USER"/.ssh
    sudo cp -r /root/.ssh/* /home/"$ADMIN_USER"/.ssh/ 2>/dev/null
    sudo chown -R "$ADMIN_USER":"$ADMIN_USER" /home/"$ADMIN_USER"/.ssh
    sudo chmod 700 /home/"$ADMIN_USER"/.ssh
    sudo chmod 600 /home/"$ADMIN_USER"/.ssh/*
    RESULT_ADMIN_USER="✅"
  else
    echo "❌ Грешка при създаване на потребител."
    RESULT_ADMIN_USER="❌"
    echo "RESULT_ADMIN_USER=\"$RESULT_ADMIN_USER\"" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
    return 1 2>/dev/null || exit 1
  fi
fi

# === Забрана за root вход чрез SSH ===
if [[ "$RESULT_ADMIN_USER" == "✅" ]]; then
  echo "🔒 Root достъпът чрез SSH ще бъде забранен..."
  if sudo grep -q "^PermitRootLogin" /etc/ssh/sshd_config; then
    sudo sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
  else
    echo "PermitRootLogin no" | sudo tee -a /etc/ssh/sshd_config > /dev/null
    fi
    sudo systemctl restart ssh
    echo "✅ Root достъпът чрез SSH е забранен."

    # ✅ Запис в setup.env
    echo "RESULT_ADMIN_USER=\"$RESULT_ADMIN_USER\"" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
    echo "ADMIN_USER=\"$ADMIN_USER\"" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null

    # ✅ Отбелязване на изпълнен модул
    echo "$MODULE_NAME" | sudo tee -a "$MODULES_FILE" > /dev/null
  else
    echo "❌ Администраторският профил не е създаден успешно."
  fi
fi
echo ""
echo ""

# === [МОДУЛ 8] КОНФИГУРИРАНЕ НА UFW И ДЕАКТИВАЦИЯ НА ДРУГИ FIREWALL ПОРТОВЕ ============
echo "[8] КОНФИГУРИРАНЕ НА UFW И ДЕАКТИВАЦИЯ НА ДРУГИ FIREWALL..."
echo "-------------------------------------------------------------------------"
echo ""

MODULE_NAME="mod_08_firewall_setup"
MODULES_FILE="/etc/netgalaxy/todo.modules"
SETUP_ENV_FILE="/etc/netgalaxy/setup.env"

RESULT_FIREWALL_SETUP="❔"

# Проверка дали модулът вече е изпълнен
if grep -q "^$MODULE_NAME\b" "$MODULES_FILE"; then
  echo "🔁 Пропускане на $MODULE_NAME (вече е отбелязан като изпълнен)..."
  echo ""
else

FIREWALL_SYSTEM="none"

# --- Деинсталиране на други защитни стени ---
if command -v firewalld >/dev/null 2>&1; then
  echo "❌ Засечена неподдържана система: firewalld – ще бъде премахната."
  sudo systemctl stop firewalld
  sudo systemctl disable firewalld
  sudo apt-get remove -y firewalld
elif command -v iptables >/dev/null 2>&1; then
  echo "❌ Засечена неподдържана система: iptables – ще бъде премахната."
  sudo iptables -F
  sudo apt-get remove -y iptables
fi

# --- Инсталиране на UFW, ако липсва или не е достъпен ---
if ! command -v ufw >/dev/null 2>&1 || [[ ! -f "$(command -v ufw)" ]]; then
  echo "📦 UFW не е инсталиран или не е достъпен. Инсталираме..."
  sudo apt-get update
  sudo apt-get install -y ufw
  INSTALL_SUCCESS=$?
else
  echo "✅ UFW е инсталиран и достъпен."
  INSTALL_SUCCESS=0
fi

if [[ "$INSTALL_SUCCESS" -ne 0 ]]; then
  echo "❌ Възникна грешка при инсталацията на UFW!"
  RESULT_FIREWALL_SETUP="❌"
  echo "RESULT_FIREWALL_SETUP=\"$RESULT_FIREWALL_SETUP\"" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
  exit 1
fi

echo "FIREWALL_SYSTEM=ufw" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null

# --- Засичане на текущ SSH порт ---
CURRENT_SSH_PORT=$(ss -tlpn 2>/dev/null | grep sshd | awk -F: '/LISTEN/ {print $2}' | awk '{print $1}' | head -n 1)
CURRENT_SSH_PORT="${CURRENT_SSH_PORT:-22}"
echo "🔍 Открит активен SSH порт: $CURRENT_SSH_PORT"

# --- Отваряне на SSH порта ---
echo "🔐 Отваряне на SSH порт: $CURRENT_SSH_PORT"
sudo ufw allow "$CURRENT_SSH_PORT"/tcp

# --- Въвеждане на допълнителни портове ---
echo ""
echo "🔧 ВЪВЕДЕТЕ ДОПЪЛНИТЕЛНИ ПОРТОВЕ ЗА ОТВАРЯНЕ (ENTER за край, 'q' за изход)"
PORT_LIST=()

while true; do
  printf "➤ Порт: "
  read -r port

  if [[ "$port" == "q" || "$port" == "Q" ]]; then
    echo "❎ Скриптът беше прекратен от потребителя."
    exit 0
  elif [[ -z "$port" ]]; then
    break
  elif ! [[ "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
    echo "❌ Невалиден порт. Използвайте число между 1 и 65535."
  elif [[ " ${PORT_LIST[*]} " =~ " $port " ]]; then
    echo "⚠️ Портът вече е добавен."
  else
    PORT_LIST+=("$port")
    sudo ufw allow "$port"/tcp
    echo "✅ Разрешен порт: $port"
    fi
  done

  # --- Запис на портовете във setup.env ---
  echo "PORT_LIST=\"${PORT_LIST[*]}\"" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null

  echo ""
  echo "✅ Правилата за UFW са подготвени, но защитната стена все още НЕ е активирана."
  echo "   Това ще бъде направено в следващия модул."

  # 📝 Запис на резултата
  RESULT_FIREWALL_SETUP="✅"
  echo "RESULT_FIREWALL_SETUP=\"$RESULT_FIREWALL_SETUP\"" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null

  # ✅ Отбелязване на изпълнен модул
  echo "$MODULE_NAME" | sudo tee -a "$MODULES_FILE" > /dev/null
fi
echo ""
echo ""


# === [МОДУЛ 9] ДОБАВЯНЕ НА TRUSTED МРЕЖИ ============================
echo "[9] ДОБАВЯНЕ НА TRUSTED МРЕЖИ..."
echo "-------------------------------------------------------------------------"
echo ""

MODULE_NAME="mod_09_firewall_trusted"
MODULES_FILE="/etc/netgalaxy/todo.modules"
SETUP_ENV_FILE="/etc/netgalaxy/setup.env"

# Проверка дали модулът вече е изпълнен
if grep -q "^$MODULE_NAME\b" "$MODULES_FILE"; then
  echo "🔁 Пропускане на $MODULE_NAME (вече е изпълнен)..."
  echo ""
else

RESULT_TRUSTED_NETS="❔"

# Зареждане на вече подготвени променливи
if [[ -f "$SETUP_ENV_FILE" ]]; then
  source "$SETUP_ENV_FILE"
fi

# Проверка за наличен UFW
if ! command -v ufw >/dev/null 2>&1; then
  echo "❌ Грешка: UFW не е инсталиран. Скриптът не може да продължи."
  RESULT_TRUSTED_NETS="❌"
  echo "RESULT_TRUSTED_NETS=\"$RESULT_TRUSTED_NETS\"" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
  exit 1
fi

# Проверка дали ще се използват trusted мрежи
TRUSTED_NETS=()
while true; do
  printf "🌐 Ще използвате ли достъп от частна (trusted) мрежа? (напр. VPN, вътрешна LAN)? (y / n / q): "
  read -r use_trust

  case "$use_trust" in
    [Qq]*) echo "❎ Скриптът беше прекратен от потребителя."
           RESULT_TRUSTED_NETS="❌"
           echo "RESULT_TRUSTED_NETS=\"$RESULT_TRUSTED_NETS\"" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
           exit 0 ;;
    [Nn]*) echo "🔒 Няма да се добавят доверени мрежи."
           break ;;
    [Yy]*)
      echo ""
      echo "🧩 Въвеждайте по една мрежа в CIDR формат (напр. 10.8.0.0/24)."
      echo "👉 Натиснете Enter без въвеждане за край, или въведете 'q' за прекратяване."
      echo ""
      while true; do
        printf "➤ Мрежа: "
        read -r net

        if [[ "$net" == "q" || "$net" == "Q" ]]; then
          echo "❎ Скриптът беше прекратен от потребителя."
          RESULT_TRUSTED_NETS="❌"
          echo "RESULT_TRUSTED_NETS=\"$RESULT_TRUSTED_NETS\"" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
          exit 0
        elif [[ -z "$net" ]]; then
          break
        elif [[ "$net" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
          TRUSTED_NETS+=("$net")
          echo "✅ Добавена мрежа: $net"
        else
          echo "❌ Невалиден формат. Използвайте CIDR, напр. 192.168.1.0/24"
        fi
      done
      break ;;
    *) echo "❌ Моля, отговорете с 'y', 'n' или 'q'." ;;
  esac
done

  # Добавяне на правилата в UFW
  if [[ ${#TRUSTED_NETS[@]} -gt 0 ]]; then
    for net in "${TRUSTED_NETS[@]}"; do
      sudo ufw allow from "$net"
      echo "✅ Разрешен достъп от доверена мрежа: $net"
    done
  fi

  # Запис в setup.env
  echo "TRUSTED_NETS=\"${TRUSTED_NETS[*]}\"" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null

  # Резултат
  RESULT_TRUSTED_NETS="✅"
  echo "RESULT_TRUSTED_NETS=\"$RESULT_TRUSTED_NETS\"" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null

  # Отбелязване като изпълнен
  echo "$MODULE_NAME" | sudo tee -a "$MODULES_FILE" > /dev/null
fi
echo ""
echo ""


# === [МОДУЛ 10] ПРОМЯНА НА SSH ПОРТА ============================================
echo "[10] ПРОМЯНА НА SSH ПОРТА..."
echo "-------------------------------------------------------------------------"
echo ""

MODULE_NAME="mod_10_ssh_port"
MODULES_FILE="/etc/netgalaxy/todo.modules"
SETUP_ENV_FILE="/etc/netgalaxy/setup.env"

# Проверка дали модулът вече е изпълнен
if grep -q "^$MODULE_NAME\b" "$MODULES_FILE"; then
  echo "🔁 Пропускане на $MODULE_NAME (вече е изпълнен)..."
  echo ""
else

  RESULT_SSH_PORT="❔"

  # Засичане на текущия порт
  CURRENT_SSH_PORT=$(ss -tlpn 2>/dev/null | grep sshd | awk -F: '/LISTEN/ {print $2}' | awk '{print $1}' | head -n 1)
  CURRENT_SSH_PORT="${CURRENT_SSH_PORT:-22}"

  while true; do
    printf "👉 В момента използвате SSH порт %s.\n" "$CURRENT_SSH_PORT"
    echo "   Въведете нов порт, ако желаете да го промените,"
    echo "   или натиснете Enter без въвеждане за запазване на съществуващия (или 'q' за прекратяване):"
    printf "➤ SSH порт: "
    read -r SSH_PORT_INPUT

    if [[ "$SSH_PORT_INPUT" == "q" || "$SSH_PORT_INPUT" == "Q" ]]; then
      echo "❎ Скриптът беше прекратен от потребителя."
      RESULT_SSH_PORT="❌"
      echo "RESULT_SSH_PORT=\"$RESULT_SSH_PORT\"" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
      exit 0
    elif [[ -z "$SSH_PORT_INPUT" ]]; then
      SSH_PORT="$CURRENT_SSH_PORT"
      echo "✅ SSH портът ще остане: $SSH_PORT"
      break
    elif [[ "$SSH_PORT_INPUT" =~ ^[0-9]+$ ]] && (( SSH_PORT_INPUT >= 1024 && SSH_PORT_INPUT <= 65535 )); then
      SSH_PORT="$SSH_PORT_INPUT"
      echo "✅ Нов SSH порт ще бъде: $SSH_PORT"
      break
    else
      echo "❌ Невалиден номер на порт. Допустими стойности: 1024–65535. Опитайте отново."
    fi
  done

  # Промяна в sshd_config, ако портът е различен
  if [[ "$SSH_PORT" != "$CURRENT_SSH_PORT" ]]; then
    echo "🔧 Актуализиране на /etc/ssh/sshd_config..."

    if grep -q "^#*Port " /etc/ssh/sshd_config; then
      sudo sed -i "s/^#*Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
    else
      echo "Port $SSH_PORT" | sudo tee -a /etc/ssh/sshd_config > /dev/null
    fi

    echo "🔄 Рестартиране на SSH услугата..."
    if sudo systemctl restart ssh; then
      echo "✅ SSH портът е променен успешно на $SSH_PORT и услугата е рестартирана."
      RESULT_SSH_PORT="✅"
    else
      echo "❌ Грешка при рестартиране на SSH! Провери конфигурацията ръчно!"
      RESULT_SSH_PORT="❌"
      echo "RESULT_SSH_PORT=\"$RESULT_SSH_PORT\"" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
      return 1 2>/dev/null || exit 1
    fi
  else
    echo "ℹ️ Няма промяна – SSH портът остава $SSH_PORT."
    RESULT_SSH_PORT="✅"
  fi

  # 🔓 Конфигурация на UFW за новия SSH порт (в неактивен режим)
  echo "🛡️ Настройка на UFW (в неактивен режим)..."

  if ! sudo ufw status | grep -q "$SSH_PORT/tcp"; then
    echo "➕ Добавяне на правило за SSH порт $SSH_PORT..."
    sudo ufw allow "$SSH_PORT"/tcp comment 'Allow SSH port'
  else
    echo "ℹ️ Порт $SSH_PORT вече присъства в UFW."
  fi

  # 🔐 Задължителна забрана на стария SSH порт (ако е сменен)
if [[ "$SSH_PORT" != "$CURRENT_SSH_PORT" ]]; then
  echo "🛡️ Забрана на стария SSH порт $CURRENT_SSH_PORT в UFW (ако е различен)..."
  sudo ufw deny "$CURRENT_SSH_PORT"/tcp comment 'Block old SSH port'
  sudo ufw deny "$CURRENT_SSH_PORT"/tcp comment 'Block old SSH port (v6)'
  echo "✅ Портът $CURRENT_SSH_PORT вече е забранен."
fi

  # 📝 Записване на резултатите
  echo "SSH_PORT=\"$SSH_PORT\"" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
  echo "RESULT_SSH_PORT=\"$RESULT_SSH_PORT\"" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null

  # ✅ Отбелязване като изпълнен
  echo "$MODULE_NAME" | sudo tee -a "$MODULES_FILE" > /dev/null
  echo ""
  echo ""
fi



# === [МОДУЛ 11] ОБОБЩЕНИЕ НА КОНФИГУРАЦИЯТА И РЕСТАРТ ========================
echo "[11] ОБОБЩЕНИЕ НА КОНФИГУРАЦИЯТА И РЕСТАРТ..."
echo "-------------------------------------------------------------------------"
echo ""

SETUP_ENV_FILE="/etc/netgalaxy/setup.env"
MODULES_FILE="/etc/netgalaxy/todo.modules"

# Зареждане на информация от setup.env
if [[ -f "$SETUP_ENV_FILE" ]]; then
  source "$SETUP_ENV_FILE"
else
  echo "⚠️ Липсва файл setup.env – няма налична информация за конфигурацията."
fi

# Обработка на липсващи данни
[[ -z "$PORT_LIST" || "$PORT_LIST" == "❔" ]] && PORT_LIST="❔ няма въведени"
[[ -z "$TRUSTED_NETS" || "$TRUSTED_NETS" == "❔" ]] && TRUSTED_NETS="❔ няма въведени"

# Извеждане на резултатите
echo "📋 СЪСТОЯНИЕ НА КОНФИГУРАЦИЯТА:"
echo ""
printf "🌐 IP адрес на сървъра:           %s\n" "$(curl -s ifconfig.me)"
printf "🌍 FQDN (hostname):               %s\n" "$(hostname)"
printf "🔐 SSH порт:                      %s\n" "${SSH_PORT:-❔ не е зададен}"
printf "👤 Администраторски потребител:   %s\n" "${ADMIN_USER:-❔ не е зададен}"
printf "🛡️  Защитна стена (FIREWALL):      %s\n" "${FIREWALL_SYSTEM:-❔ не е зададена}"
printf "🚪 Отворени портове:              %s\n" "$PORT_LIST"
printf "🌐 Доверени мрежи (VPN/LAN):      %s\n" "$TRUSTED_NETS"
printf "🌐 Локализации:                   %s\n" "${RESULT_LOCALES:-❔}"
printf "🕒 Времева зона и синхронизация:  %s\n" "${RESULT_TIMEZONE_NTP:-❔}"
echo ""

# === Финален диалог с оператор ===============================================
while true; do
  echo "📋 Приемате ли скрипта като напълно изпълнен и успешен?"
  echo "[y] UFW ще бъде активиран и сървърът ще бъде рестартиран."
  echo "[n] Прекратяване на скрипта без активиране на UFW и рестарт."
  read -rp "Вашият избор (y/n): " final_confirm

  case "$final_confirm" in
    [Yy])
      echo "🔐 Активиране на UFW..."
      if sudo ufw --force enable; then
        echo "✅ UFW беше активиран успешно."
        echo "📝 Записване на резултатите..."        
        sudo sed -i '/^SETUP_VPS_BASE_STATUS=/d' "$SETUP_ENV_FILE"        
        echo "SETUP_VPS_BASE_STATUS=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null

        echo ""
        echo "♻️ Подготовка за рестарт..."
        echo "🧹 Изчистване на временните файлове..."
        sudo rm -f "$MODULES_FILE"   # ⬅️ Само него

        if [[ -f "$0" ]]; then
          sudo rm -- "$0"
        fi

        echo "🔄 Рестартиране на системата след 3 секунди..."
        sleep 3
        sudo reboot
      else
        echo "❌ Неуспешно активиране на UFW. Моля, проверете конфигурацията ръчно."
        exit 1
      fi
      ;;
    [Nn])      
      echo "SETUP_VPS_BASE_STATUS=❌" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
      echo "⛔ Скриптът завърши без промени. Моля, активирайте UFW и рестартирайте ръчно."
      exit 1
      ;;
    *)
      echo "❌ Невалиден избор. Моля, въведете 'y' или 'n'."
      ;;
  esac
done
# --------- Край на скрипта ---------



