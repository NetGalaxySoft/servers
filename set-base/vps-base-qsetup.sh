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

echo ""
echo -e "\e[32m=========================================="
echo -e " НАЧАЛНА КОНФИГУРАЦИЯ НА ОТДАЛЕЧЕН СЪРВЪР"
echo -e "==========================================\e[0m"
echo ""

NETGALAXY_DIR="/etc/netgalaxy"
MODULES_FILE="$NETGALAXY_DIR/todo.modules"
SETUP_ENV_FILE="$NETGALAXY_DIR/setup.env"


# === [МОДУЛ 1] ПРЕДВАРИТЕЛНИ ПРОВЕРКИ И ИНИЦИАЛИЗАЦИЯ =========================
echo "[1] ПРЕДВАРИТЕЛНИ ПРОВЕРКИ НА СИСТЕМА..."
echo "-----------------------------------------------------------"
echo ""

# --- Проверка дали скриптът вече е изпълнен успешно ---
if [[ -f "$SETUP_ENV_FILE" ]] && sudo grep -q '^SETUP_VPS_BASE_STATUS=✅' "$SETUP_ENV_FILE"; then
  echo "🛑 Този скрипт вече е бил изпълнен успешно на този сървър."
  echo "Повторно изпълнение не е позволено, за да се избегне повреда на системата."
  [[ -f "$0" ]] && sudo rm -- "$0"
  exit 0
fi

# --- Проверка на операционната система ---
echo "🔍 Проверка на операционната система..."
if [[ -f /etc/os-release ]]; then
  source /etc/os-release
  OS_NAME=$ID
  OS_VERSION=$VERSION_ID
else
  echo "❌ Неуспешно откриване на ОС. Скриптът изисква Ubuntu или Debian."
  exit 1
fi

SUPPORTED=false
if [[ "$OS_NAME" == "ubuntu" && ( "$OS_VERSION" == "22.04" || "$OS_VERSION" == "24.04" ) ]]; then
  SUPPORTED=true
elif [[ "$OS_NAME" == "debian" && ( "$OS_VERSION" == "11" || "$OS_VERSION" == "12" ) ]]; then
  SUPPORTED=true
fi

if [[ "$SUPPORTED" == false ]]; then
  echo "❌ Операционната система $PRETTY_NAME не се поддържа от този скрипт."
  echo "Поддържани системи: Ubuntu 22.04/24.04, Debian 11/12"
  exit 1
fi

echo "✅ Засечена поддържана ОС: $PRETTY_NAME"
echo ""

# --- Проверка дали модулът вече е изпълнен ---
if sudo grep -q '^BASE_RESULT_MODULE1=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 1 вече е изпълнен успешно. Пропускане..."
else
  # --- Потвърждение на IP адрес ---
  while true; do
    printf "🌐 Въведете публичния IP адрес на сървъра (или 'q' за изход): "
    read SERVER_IP

    if [[ "$SERVER_IP" == "q" || "$SERVER_IP" == "Q" ]]; then
      echo "❎ Скриптът беше прекратен от потребителя."
      exit 0
    fi

    if ! [[ "$SERVER_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "❌ Невалиден IP адрес. Моля, въведете валиден IPv4 адрес (пример: 192.168.1.100)."
      continue
    fi

    ACTUAL_IP=$(curl -s -4 ifconfig.me)

    if [[ "$ACTUAL_IP" != "$SERVER_IP" ]]; then
      echo ""
      echo "🚫 Несъответствие! Въведеният IP ($SERVER_IP) не съвпада с реалния IP на машината ($ACTUAL_IP)."
      echo ""
      read -p "🔁 Искате ли да опитате отново? [Enter за ДА, 'q' за изход]: " retry
      if [[ "$retry" == "q" || "$retry" == "Q" ]]; then
        echo "⛔ Скриптът беше прекратен от потребителя."
        exit 0
      fi
      echo ""
    else
      echo "✅ Потвърдено: скриптът е стартиран на сървъра с IP $SERVER_IP."
      break
    fi
  done

  # --- Инициализация на NetGalaxy структура ---
  if [[ ! -d "$NETGALAXY_DIR" ]]; then
    echo "📁 Създаване на директория: $NETGALAXY_DIR"
    sudo mkdir -p "$NETGALAXY_DIR"
    sudo chmod 755 "$NETGALAXY_DIR"
    echo "✅ Директорията беше създадена."
  fi

  if [[ ! -f "$MODULES_FILE" ]]; then
    echo "📝 Създаване на файл: $MODULES_FILE"
    sudo touch "$MODULES_FILE"
    sudo chmod 644 "$MODULES_FILE"
  fi

  if [[ ! -f "$SETUP_ENV_FILE" ]]; then
    echo "⚙️ Създаване на конфигурационен файл: $SETUP_ENV_FILE"
    sudo touch "$SETUP_ENV_FILE"
    sudo chmod 600 "$SETUP_ENV_FILE"
    echo "# NetGalaxy Server Setup Metadata" | sudo tee "$SETUP_ENV_FILE" > /dev/null
  fi

  # ✅ Запис или обновяване на SERVER_IP в todo.modules
if sudo grep -q '^SERVER_IP=' "$MODULES_FILE" 2>/dev/null; then
  sudo sed -i "s|^SERVER_IP=.*|SERVER_IP=\"$SERVER_IP\"|" "$MODULES_FILE"
else
  echo "SERVER_IP=\"$SERVER_IP\"" | sudo tee -a "$MODULES_FILE" > /dev/null
fi

# ✅ Запис на резултат за Модул 1
if sudo grep -q '^BASE_RESULT_MODULE1=' "$SETUP_ENV_FILE" 2>/dev/null; then
  sudo sed -i 's|^BASE_RESULT_MODULE1=.*|BASE_RESULT_MODULE1=✅|' "$SETUP_ENV_FILE"
else
  echo "BASE_RESULT_MODULE1=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
fi
fi
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
# Проверка дали модулът вече е изпълнен
if sudo grep -q "^RESULT_FQDN_CONFIG=✅" "$SETUP_ENV_FILE"; then
  echo "🔁 Пропускане (FQDN вече е конфигуриран)..."
  echo ""
else
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

    if [[ -z "$(dig +short "$FQDN")" ]]; then
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

# === КОНФИГУРИРАНЕ НА HOSTNAME И /etc/hosts =================================
sudo hostnamectl set-hostname "$FQDN"
echo "✅ Hostname е зададен: $FQDN"

# Променливи
SERVER_IP=$(curl -s -4 ifconfig.me)
SHORT_HOST=$(echo "$FQDN" | cut -d '.' -f1)
WWW_ALIAS="www.$FQDN"

# ✅ Уверяваме се, че 127.0.0.1 localhost присъства (ако липсва – добавяме)
if ! grep -q "^127.0.0.1" /etc/hosts; then
  echo "127.0.0.1   localhost" | sudo tee -a /etc/hosts > /dev/null
fi

# ✅ Премахваме всички стари записи за 127.0.1.1 и публичния IP (за чистота)
sudo sed -i "/^127\.0\.1\.1/d" /etc/hosts
sudo sed -i "/$SERVER_IP/d" /etc/hosts

# ✅ Добавяме или актуализираме реда за 127.0.1.1 с FQDN и short host
echo "127.0.1.1   $FQDN $SHORT_HOST" | sudo tee -a /etc/hosts > /dev/null

# ✅ Добавяме публичния IP ред с алиас
echo "$SERVER_IP   $FQDN $WWW_ALIAS" | sudo tee -a /etc/hosts > /dev/null

# ✅ Проверка за коректност (и двата реда трябва да присъстват)
if grep -q "^127\.0\.1\.1.*$FQDN" /etc/hosts && grep -q "^$SERVER_IP.*$FQDN" /etc/hosts; then
  echo "✅ /etc/hosts е конфигуриран правилно:"
  echo "   127.0.1.1   $FQDN $SHORT_HOST"
  echo "   $SERVER_IP   $FQDN $WWW_ALIAS"
else
  echo "❌ Грешка: един или повече редове не са добавени."
  exit 1
fi

# ✅ Запис или обновяване на FQDN в todo.modules
if sudo grep -q '^FQDN=' "$MODULES_FILE" 2>/dev/null; then
  sudo sed -i "s|^FQDN=.*|FQDN=\"$FQDN\"|" "$MODULES_FILE"
else
  echo "FQDN=\"$FQDN\"" | sudo tee -a "$MODULES_FILE" > /dev/null
fi

# ✅ Записване на резултат от модула
if sudo grep -q '^BASE_RESULT_MODULE2=' "$SETUP_ENV_FILE" 2>/dev/null; then
  sudo sed -i 's|^BASE_RESULT_MODULE2=.*|BASE_RESULT_MODULE2=✅|' "$SETUP_ENV_FILE"
else
  echo "BASE_RESULT_MODULE2=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
fi
echo ""
echo ""




exit 0
# === [МОДУЛ 3] ОБНОВЯВАНЕ НА СИСТЕМАТА ========================================
echo "[3] ОБНОВЯВАНЕ НА СИСТЕМАТА..."
echo "-------------------------------------------------------------------------"
echo ""

MODULE_NAME="mod_03_system_update"
MODULES_FILE="/etc/netgalaxy/todo.modules"
SETUP_ENV_FILE="/etc/netgalaxy/setup.env"

# Проверка дали модулът вече е изпълнен
if sudo grep -q '^BASE_RESULT_MODULE3=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 3 вече е изпълнен успешно. Пропускане..."
else
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
      exit 1
    fi
  done

# Изпълнение на обновяването
  if sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get autoremove -y; then
    echo "✅ Системата е успешно обновена."

    # ✅ Запис на резултат за модула (с обновяване, ако вече съществува)
    if sudo grep -q '^BASE_RESULT_MODULE3=' "$SETUP_ENV_FILE" 2>/dev/null; then
      sudo sed -i 's|^BASE_RESULT_MODULE3=.*|BASE_RESULT_MODULE3=✅|' "$SETUP_ENV_FILE"
    else
      echo "BASE_RESULT_MODULE3=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
    fi
echo ""
echo ""


# === [МОДУЛ 4] ИНСТАЛИРАНЕ НА ОСНОВНИ ИНСТРУМЕНТИ =============================
echo "[4] ИНСТАЛИРАНЕ НА ОСНОВНИ ИНСТРУМЕНТИ..."
echo "-------------------------------------------------------------------------"
echo ""

MODULE_NAME="mod_04_base_tools"
SETUP_ENV_FILE="/etc/netgalaxy/setup.env"
RESULT_BASE_TOOLS="✅"

# ✅ Проверка дали модулът вече е изпълнен
if sudo grep -q '^BASE_RESULT_MODULE4=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 4 вече е изпълнен успешно. Пропускане..."
else
  REQUIRED_PACKAGES=(nano unzip git curl wget net-tools htop dnsutils)
  
  echo "📦 Проверка и инсталиране на основни инструменти..."
  echo "-------------------------------------------------------------------------"
  
  for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then
      echo "✔ $pkg е вече инсталиран."
    else
      echo "Инсталиране на $pkg..."
      if sudo apt-get install -y "$pkg"; then
        echo "✅ Успешно инсталиране на $pkg"
      else
        echo "⚠️ Неуспешна инсталация на $pkg."
        while true; do
          echo "👉 Изберете опция:"
          echo "[1] Повторен опит"
          echo "[2] Продължаване с предупреждение"
          echo "[q] Прекратяване на скрипта"
          read -rp "Вашият избор: " choice
          case "$choice" in
            1)
              echo "🔄 Повторен опит за $pkg..."
              if sudo apt-get install -y "$pkg"; then
                echo "✅ Успешно инсталиране на $pkg"
                break
              else
                echo "❌ Отново неуспешна инсталация на $pkg."
              fi
              ;;
            2)
              echo "⚠️ Продължаваме без $pkg. Това може да доведе до проблеми по-късно."
              RESULT_BASE_TOOLS="⚠️"
              break
              ;;
            [Qq])
              echo "⛔ Скриптът беше прекратен от потребителя."
              exit 0
              ;;
            *)
              echo "❌ Невалиден избор. Опитайте отново."
              ;;
          esac
        done
      fi
    fi
  done

# ✅ Записване на резултат за модула (с обновяване, ако вече съществува)
if sudo grep -q '^BASE_RESULT_MODULE4=' "$SETUP_ENV_FILE" 2>/dev/null; then
  sudo sed -i "s|^BASE_RESULT_MODULE4=.*|BASE_RESULT_MODULE4=$RESULT_BASE_TOOLS|" "$SETUP_ENV_FILE"
else
  echo "BASE_RESULT_MODULE4=$RESULT_BASE_TOOLS" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
fi
echo ""
echo ""


# === [МОДУЛ 5] НАСТРОЙКА НА ЛОКАЛИЗАЦИИ =======================================
echo "[5] НАСТРОЙКА НА ЛОКАЛИЗАЦИИ..."
echo "-------------------------------------------------------------------------"
echo ""

SETUP_ENV_FILE="/etc/netgalaxy/setup.env"

# ✅ Проверка дали модулът вече е изпълнен
if sudo grep -q '^BASE_RESULT_MODULE5=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 5 вече е изпълнен успешно. Пропускане..."
else
  echo "🌐 Инсталиране на езикови пакети (BG, RU)..."
  if ! sudo apt-get install -y language-pack-bg language-pack-ru; then
    echo "⚠️ Неуспешна инсталация на езикови пакети. Продължаваме."
  fi

  echo "🔧 Активиране на локализации UTF-8 в /etc/locale.gen..."
  sudo sed -i '/^# *bg_BG.UTF-8 UTF-8/s/^# *//g' /etc/locale.gen
  sudo sed -i '/^# *ru_RU.UTF-8 UTF-8/s/^# *//g' /etc/locale.gen
  sudo sed -i '/^# *en_US.UTF-8 UTF-8/s/^# *//g' /etc/locale.gen

  grep -qxF 'bg_BG.UTF-8 UTF-8' /etc/locale.gen || echo 'bg_BG.UTF-8 UTF-8' | sudo tee -a /etc/locale.gen > /dev/null
  grep -qxF 'ru_RU.UTF-8 UTF-8' /etc/locale.gen || echo 'ru_RU.UTF-8 UTF-8' | sudo tee -a /etc/locale.gen > /dev/null
  grep -qxF 'en_US.UTF-8 UTF-8' /etc/locale.gen || echo 'en_US.UTF-8 UTF-8' | sudo tee -a /etc/locale.gen > /dev/null

  echo "⚙️  Генериране на локализации UTF-8 (задължителен стандарт за съвместимост с мрежата NetGalaxy)..."
  if sudo locale-gen && sudo update-locale; then
    echo "✅ Локализациите са конфигурирани успешно."

    # ✅ Записване на резултат за модула (с обновяване, ако вече съществува)
    if sudo grep -q '^BASE_RESULT_MODULE5=' "$SETUP_ENV_FILE" 2>/dev/null; then
      sudo sed -i 's|^BASE_RESULT_MODULE5=.*|BASE_RESULT_MODULE5=✅|' "$SETUP_ENV_FILE"
    else
      echo "BASE_RESULT_MODULE5=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
    fi

  else
    echo "❌ Грешка при генериране на локализации."
    exit 1
  fi
fi
echo ""
echo ""


# === [МОДУЛ 6] НАСТРОЙКА НА ВРЕМЕВА ЗОНА И NTP СИНХРОНИЗАЦИЯ ==================
echo "[6] НАСТРОЙКА НА ВРЕМЕВА ЗОНА И NTP СИНХРОНИЗАЦИЯ..."
echo "-------------------------------------------------------------------------"
echo ""

SETUP_ENV_FILE="/etc/netgalaxy/setup.env"

# ✅ Проверка дали модулът вече е изпълнен
if sudo grep -q '^BASE_RESULT_MODULE6=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 6 вече е изпълнен успешно. Пропускане..."
else
  echo "🌍 Задаване на времева зона на UTC..."
  if ! sudo timedatectl set-timezone UTC; then
    echo "❌ Неуспешна смяна на времевата зона."
    exit 1
  fi
  echo "✅ Времева зона: UTC."

  echo "🔧 Изключване на други NTP услуги..."
  sudo systemctl stop ntpd 2>/dev/null && sudo systemctl disable ntpd 2>/dev/null
  sudo systemctl stop systemd-timesyncd 2>/dev/null && sudo systemctl disable systemd-timesyncd 2>/dev/null

  echo "📦 Инсталиране и конфигуриране на chrony..."
  if ! sudo apt-get install -y chrony; then
    echo "❌ Неуспешна инсталация на chrony."
    exit 1
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

echo "✅ Времевата зона и NTP синхронизацията са успешно конфигурирани и съвместими с мрежата NetGalaxy."

# ✅ Запис или обновяване на TIMEZONE_NTP в todo.modules
if sudo grep -q '^TIMEZONE_NTP=' "$MODULES_FILE" 2>/dev/null; then
  sudo sed -i 's|^TIMEZONE_NTP=.*|TIMEZONE_NTP="UTC"|' "$MODULES_FILE"
else
  echo 'TIMEZONE_NTP="UTC"' | sudo tee -a "$MODULES_FILE" > /dev/null
fi

# ✅ Записване на резултат за модула (с обновяване, ако вече съществува)
if sudo grep -q '^BASE_RESULT_MODULE6=' "$SETUP_ENV_FILE" 2>/dev/null; then
  sudo sed -i 's|^BASE_RESULT_MODULE6=.*|BASE_RESULT_MODULE6=✅|' "$SETUP_ENV_FILE"
else
  echo "BASE_RESULT_MODULE6=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
fi
echo ""
echo ""


# === [МОДУЛ 7] СЪЗДАВАНЕ НА НОВ АДМИНИСТРАТОРСКИ ПРОФИЛ ========================
echo "[7] СЪЗДАВАНЕ НА НОВ АДМИНИСТРАТОРСКИ ПРОФИЛ"
echo "-------------------------------------------------------------------------"
echo ""

SETUP_ENV_FILE="/etc/netgalaxy/setup.env"
MODULES_FILE="/etc/netgalaxy/todo.modules"

# ✅ Проверка дали модулът вече е изпълнен
if sudo grep -q '^BASE_RESULT_MODULE7=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 7 вече е изпълнен успешно. Пропускане..."
else

echo "🔐 По съображения за сигурност, root достъпът чрез SSH ще бъде забранен."
echo "✅ Ще бъде създаден таен потребител с root права за администриране на сървъра."
echo ""

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
echo ""

while true; do
  printf "🔑 Въведете парола за %s: " "$ADMIN_USER"
  read -s PASSWORD_1
  echo

  if [[ -z "$PASSWORD_1" ]] || (( ${#PASSWORD_1} < 8 )) || \
     ! [[ "$PASSWORD_1" =~ [a-z] ]] || \
     ! [[ "$PASSWORD_1" =~ [A-Z] ]] || \
     ! [[ "$PASSWORD_1" =~ [0-9] ]]; then
    echo "❌ Паролата трябва да съдържа поне 8 символа, включително малка и главна латинска буква, и цифра."
    continue
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
    echo "🔑 Копиране на SSH ключовете от root..."
    sudo mkdir -p /home/"$ADMIN_USER"/.ssh
    sudo cp -r /root/.ssh/* /home/"$ADMIN_USER"/.ssh/ 2>/dev/null
    sudo chown -R "$ADMIN_USER":"$ADMIN_USER" /home/"$ADMIN_USER"/.ssh
    sudo chmod 700 /home/"$ADMIN_USER"/.ssh
    sudo chmod 600 /home/"$ADMIN_USER"/.ssh/*
  else
    echo "❌ Грешка при създаване на потребител."
    exit 1
  fi
fi

# === Забрана за root вход чрез SSH ===
echo "🔒 Root достъпът чрез SSH ще бъде забранен..."
if sudo grep -q "^PermitRootLogin" /etc/ssh/sshd_config; then
  sudo sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
else
  echo "PermitRootLogin no" | sudo tee -a /etc/ssh/sshd_config > /dev/null
fi
sudo systemctl restart ssh
echo "✅ Root достъпът чрез SSH е забранен."

# ✅ Запис или обновяване на ADMIN_USER в todo.modules
if sudo grep -q '^ADMIN_USER=' "$MODULES_FILE" 2>/dev/null; then
  sudo sed -i "s|^ADMIN_USER=.*|ADMIN_USER=\"$ADMIN_USER\"|" "$MODULES_FILE"
else
  echo "ADMIN_USER=\"$ADMIN_USER\"" | sudo tee -a "$MODULES_FILE" > /dev/null
fi

# ✅ Записване на резултат за модула (с обновяване, ако вече съществува)
if sudo grep -q '^BASE_RESULT_MODULE7=' "$SETUP_ENV_FILE" 2>/dev/null; then
  sudo sed -i 's|^BASE_RESULT_MODULE7=.*|BASE_RESULT_MODULE7=✅|' "$SETUP_ENV_FILE"
else
  echo "BASE_RESULT_MODULE7=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
fi

fi
echo ""
echo ""


# === [МОДУЛ 8] КОНФИГУРИРАНЕ НА UFW И ДЕАКТИВАЦИЯ НА ДРУГИ FIREWALL ПОРТОВЕ ============
echo "[8] КОНФИГУРИРАНЕ НА UFW И ДЕАКТИВАЦИЯ НА ДРУГИ FIREWALL..."
echo "-------------------------------------------------------------------------"
echo ""

SETUP_ENV_FILE="/etc/netgalaxy/setup.env"

# Проверка дали модулът вече е изпълнен
if sudo grep -q "^RESULT_FIREWALL_SETUP=✅" "$SETUP_ENV_FILE"; then
  echo "🔁 Пропускане (защитната стена вече е конфигурирана)..."
  echo ""
else

# --- Деактивиране на firewalld, ако съществува ---
if command -v firewalld >/dev/null 2>&1; then
  echo "❌ Засечена неподдържана система: firewalld – ще бъде деактивирана."
  sudo systemctl stop firewalld
  sudo systemctl disable firewalld
  sudo apt-get remove -y firewalld
fi

# --- Изчистване на стари правила от iptables ---
if sudo iptables -L >/dev/null 2>&1; then
  echo "ℹ️ Изчистване на стари правила в iptables..."
  sudo iptables -F
fi

# --- Проверка за наличност на UFW ---
if ! command -v ufw >/dev/null 2>&1; then
  echo "📦 UFW не е инсталиран. Инсталираме..."
  if ! sudo apt-get update || ! sudo apt-get install -y ufw; then
    echo "❌ Грешка при инсталиране на UFW. Скриптът ще бъде прекратен."
    exit 1
  fi
else
  echo "✅ UFW вече е инсталиран."
fi

# --- Деактивиране на UFW, ако е активен ---
if sudo ufw status | grep -q "Status: active"; then
  echo "ℹ️ UFW е активен. Деактивираме..."
  sudo ufw disable
fi

# --- Засичане на текущия SSH порт ---
CURRENT_SSH_PORT=$(sudo ss -tlpn 2>/dev/null | grep sshd | awk '{print $4}' | awk -F: '{print $NF}' | head -n 1)

if [[ -z "$CURRENT_SSH_PORT" ]]; then
  echo "❌ Не може да се определи текущият SSH порт. Скриптът ще бъде прекратен."
  exit 1
fi

echo "🔍 Засечен SSH порт: $CURRENT_SSH_PORT"

# --- Проверка дали правилото вече съществува ---
if sudo ufw status | grep -q "$CURRENT_SSH_PORT/tcp"; then
  echo "ℹ️ SSH портът $CURRENT_SSH_PORT вече е добавен в правилата на UFW."
else
  echo "🔐 Добавяне на SSH порт $CURRENT_SSH_PORT в правилата на UFW..."
  if ! sudo ufw allow "$CURRENT_SSH_PORT"/tcp comment 'Allow SSH'; then
    echo "❌ Грешка при добавяне на SSH порт ($CURRENT_SSH_PORT) в правилата на UFW."
    exit 1
  fi
  echo "✅ SSH портът $CURRENT_SSH_PORT е добавен успешно."
fi

# ✅ Записване на текущия SSH порт (обновяване, ако вече съществува)
if sudo grep -q '^SSH_PORT=' "$MODULES_FILE" 2>/dev/null; then
  sudo sed -i "s|^SSH_PORT=.*|SSH_PORT=\"$CURRENT_SSH_PORT\"|" "$MODULES_FILE"
else
  echo "SSH_PORT=\"$CURRENT_SSH_PORT\"" | sudo tee -a "$MODULES_FILE" > /dev/null
fi

# ✅ Записване на резултат за модула (с обновяване, ако вече съществува)
if sudo grep -q '^BASE_RESULT_MODULE8=' "$SETUP_ENV_FILE" 2>/dev/null; then
  sudo sed -i 's|^BASE_RESULT_MODULE8=.*|BASE_RESULT_MODULE8=✅|' "$SETUP_ENV_FILE"
else
  echo "BASE_RESULT_MODULE8=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
fi

echo ""
echo "✅ UFW е конфигуриран. Все още НЕ е активиран – активирането ще стане в последния модул."
fi
echo ""
echo ""


# === [МОДУЛ 9] ДОБАВЯНЕ НА TRUSTED МРЕЖИ ============================
echo "[9] ДОБАВЯНЕ НА TRUSTED МРЕЖИ..."
echo "-------------------------------------------------------------------------"
echo ""

SETUP_ENV_FILE="/etc/netgalaxy/setup.env"
MODULES_FILE="/etc/netgalaxy/todo.modules"

# ✅ Проверка дали модулът вече е изпълнен
if sudo grep -q '^BASE_RESULT_MODULE9=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 9 вече е изпълнен успешно. Пропускане..."
  echo ""
else

# Зареждане на UFW
if ! command -v ufw >/dev/null 2>&1; then
  echo "❌ Грешка: UFW не е инсталиран. Скриптът не може да продължи."
  exit о
fi

# Въвеждане на доверени мрежи
TRUSTED_NETS=()
while true; do
  printf "🌐 Ще използвате ли достъп от частна (trusted) мрежа? (y / n / q): "
  read -r use_trust

  case "$use_trust" in
    [Qq]*) echo "❎ Скриптът беше прекратен от потребителя."
           exit 0 ;;
    [Nn]*) echo "🔒 Няма да се добавят доверени мрежи."
           break ;;
    [Yy]*)
      echo ""
      echo "🧩 Въвеждайте по една мрежа в CIDR формат (напр. 10.8.0.0/24)."
      echo "👉 Натиснете Enter без въвеждане за край."
      echo ""
      while true; do
        printf "➤ Мрежа: "
        read -r net

        if [[ -z "$net" ]]; then
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

# ✅ Запис на доверените мрежи в todo.modules (обновяване, ако вече съществуват)
if sudo grep -q '^TRUSTED_NETS=' "$MODULES_FILE" 2>/dev/null; then
  sudo sed -i "s|^TRUSTED_NETS=.*|TRUSTED_NETS=\"${TRUSTED_NETS[*]}\"|" "$MODULES_FILE"
else
  echo "TRUSTED_NETS=\"${TRUSTED_NETS[*]}\"" | sudo tee -a "$MODULES_FILE" > /dev/null
fi

# ✅ Записване на резултат за модула (с обновяване, ако вече съществува)
if sudo grep -q '^BASE_RESULT_MODULE9=' "$SETUP_ENV_FILE" 2>/dev/null; then
  sudo sed -i 's|^BASE_RESULT_MODULE9=.*|BASE_RESULT_MODULE9=✅|' "$SETUP_ENV_FILE"
else
  echo "BASE_RESULT_MODULE9=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
fi

fi
echo ""
echo ""


# === [МОДУЛ 10] ПРОМЯНА НА SSH ПОРТА ============================================
echo "[10] ПРОМЯНА НА SSH ПОРТА..."
echo "-------------------------------------------------------------------------"
echo ""

SETUP_ENV_FILE="/etc/netgalaxy/setup.env"
MODULES_FILE="/etc/netgalaxy/todo.modules"

# ✅ Проверка дали модулът вече е изпълнен
if sudo grep -q '^BASE_RESULT_MODULE10=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 10 вече е изпълнен успешно. Пропускане..."
  echo ""
else

# --- Извличане на SSH порта от todo.modules ---
if sudo grep -q "^SSH_PORT=" "$MODULES_FILE"; then
  SSH_PORT=$(sudo grep "^SSH_PORT=" "$MODULES_FILE" | cut -d '=' -f2 | tr -d '"')
else
  echo "❌ Не е намерен запис за SSH порта в $MODULES_FILE. Скриптът ще бъде прекратен."
  exit 1
fi

while true; do
  printf "👉 В момента използвате SSH порт %s.\n" "$CURRENT_SSH_PORT"
  echo "   Въведете нов порт, ако желаете да го промените,"
  echo "   или натиснете Enter за запазване на съществуващия (или 'q' за прекратяване):"
  printf "➤ SSH порт: "
  read -r SSH_PORT_INPUT

  if [[ "$SSH_PORT_INPUT" == "q" || "$SSH_PORT_INPUT" == "Q" ]]; then
    echo "❎ Скриптът беше прекратен от потребителя."
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
    echo "❌ Невалиден номер на порт. Допустими стойности: 1024–65535."
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
  if ! sudo systemctl restart ssh; then
    echo "❌ Грешка при рестартиране на SSH! Провери конфигурацията ръчно!"
    exit 1
  fi
  echo "✅ SSH портът е променен успешно на $SSH_PORT и услугата е рестартирана."
else
  echo "ℹ️ Няма промяна – SSH портът остава $SSH_PORT."
fi

# 🔓 Настройка на UFW за новия порт
echo "🛡️ Настройка на UFW (в неактивен режим)..."
if ! sudo ufw status | grep -q "$SSH_PORT/tcp"; then
  echo "➕ Добавяне на правило за SSH порт $SSH_PORT..."
  sudo ufw allow "$SSH_PORT"/tcp comment 'Allow SSH port'
fi

# Забрана на стария порт (ако е сменен)
if [[ "$SSH_PORT" != "$CURRENT_SSH_PORT" ]]; then
  echo "🛡️ Забрана на стария SSH порт $CURRENT_SSH_PORT..."
  sudo ufw deny "$CURRENT_SSH_PORT"/tcp comment 'Block old SSH port'
fi

# ✅ Запис на SSH порта в todo.modules (обновяване, ако вече съществува)
if sudo grep -q '^SSH_PORT=' "$MODULES_FILE" 2>/dev/null; then
  sudo sed -i "s|^SSH_PORT=.*|SSH_PORT=\"$SSH_PORT\"|" "$MODULES_FILE"
else
  echo "SSH_PORT=\"$SSH_PORT\"" | sudo tee -a "$MODULES_FILE" > /dev/null
fi

# ✅ Запис на резултат за модула (с обновяване, ако вече съществува)
if sudo grep -q '^BASE_RESULT_MODULE10=' "$SETUP_ENV_FILE" 2>/dev/null; then
  sudo sed -i 's|^BASE_RESULT_MODULE10=.*|BASE_RESULT_MODULE10=✅|' "$SETUP_ENV_FILE"
else
  echo "BASE_RESULT_MODULE10=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
fi

fi
echo ""
echo ""


# === [МОДУЛ 11] ОБОБЩЕНИЕ НА КОНФИГУРАЦИЯТА И РЕСТАРТ ========================
echo "[11] ОБОБЩЕНИЕ НА КОНФИГУРАЦИЯТА И РЕСТАРТ..."
echo "-------------------------------------------------------------------------"
echo ""

SETUP_ENV_FILE="/etc/netgalaxy/setup.env"
MODULES_FILE="/etc/netgalaxy/todo.modules"

# ✅ Проверка дали модулът вече е изпълнен
if sudo grep -q '^BASE_RESULT_MODULE11=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 11 вече е изпълнен успешно. Пропускане..."
  echo ""
  return 0 2>/dev/null || exit 0
fi

# ✅ Проверка за съществуване на setup.env
if [[ ! -f "$SETUP_ENV_FILE" ]]; then
  echo "❌ Критична грешка: липсва $SETUP_ENV_FILE."
  echo "Скриптът не може да продължи."
  exit 1
fi

# ✅ Зареждане на временни данни от todo.modules
if [[ -f "$MODULES_FILE" ]]; then
  source "$MODULES_FILE"
fi

# ✅ Обработка на липсващи данни
[[ -z "$PORT_LIST" ]] && PORT_LIST="❔ няма въведени"
[[ -z "$TRUSTED_NETS" ]] && TRUSTED_NETS="❔ няма въведени"
[[ -z "$SSH_PORT" ]] && SSH_PORT="❔ не е зададен"
[[ -z "$ADMIN_USER" ]] && ADMIN_USER="❔ не е зададен"

# ✅ Извеждане на резултатите
echo "📋 СЪСТОЯНИЕ НА КОНФИГУРАЦИЯТА:"
echo ""
printf "🌐 IP адрес на сървъра:           %s\n" "${SERVER_IP:-❔}"
printf "🌍 FQDN (hostname):               %s\n" "${FQDN:-❔}"
printf "🔐 SSH порт:                      %s\n" "${SSH_PORT:-❔}"
printf "🔒 Администраторски профил:       %s\n" "${ADMIN_USER:-❔}"
printf "🛡️  Защитна стена (UFW):            %s\n" "ще бъде активирана"
printf "🚪 Допълнителни портове:          %s\n" "${PORT_LIST:-❔}"
printf "🌐 Доверени мрежи (VPN/LAN):      %s\n" "${TRUSTED_NETS:-❔}"
printf "🌐 Локализации:                   %s\n" "$(grep '^BASE_RESULT_MODULE5=' "$SETUP_ENV_FILE" | cut -d '=' -f2)"
printf "🕒 Времева зона и NTP:            %s\n" "$(grep '^BASE_RESULT_MODULE6=' "$SETUP_ENV_FILE" | cut -d '=' -f2)"
echo ""

# === Финален диалог с оператор ===============================================
while true; do
  echo "📋 Приемате ли конфигурацията като успешна?"
  echo "[y] Активиране на UFW и рестарт на сървъра."
  echo "[n] Изход без промени (UFW остава неактивен)."
  read -rp "Вашият избор (y/n): " final_confirm

  case "$final_confirm" in
    [Yy])
      echo "🔐 Активиране на UFW..."
      if sudo ufw --force enable; then
        echo "✅ UFW беше активиран успешно."
        echo "📝 Записване на крайния статус..."

        # ✅ Запис на резултат за модула (с обновяване, ако вече съществува)
        if sudo grep -q '^BASE_RESULT_MODULE11=' "$SETUP_ENV_FILE" 2>/dev/null; then
          sudo sed -i 's|^BASE_RESULT_MODULE11=.*|BASE_RESULT_MODULE11=✅|' "$SETUP_ENV_FILE"
        else
          echo "BASE_RESULT_MODULE11=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
        fi

        # ✅ Обновяване на SETUP_VPS_BASE_STATUS
        if sudo grep -q '^SETUP_VPS_BASE_STATUS=' "$SETUP_ENV_FILE" 2>/dev/null; then
          sudo sed -i 's|^SETUP_VPS_BASE_STATUS=.*|SETUP_VPS_BASE_STATUS=✅|' "$SETUP_ENV_FILE"
        else
          echo "SETUP_VPS_BASE_STATUS=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
        fi

        echo "🧹 Изчистване на временните файлове..."
        sudo rm -f "$MODULES_FILE"

        if [[ -f "$0" ]]; then
          sudo rm -- "$0"
        fi

        echo "🔄 Рестартиране на системата след 3 секунди..."
        sleep 3
        sudo reboot
      else
        echo "❌ Неуспешно активиране на UFW. Проверете ръчно."
        exit 1
      fi
      ;;
    [Nn])
      echo "⛔ Скриптът приключи без активиране на UFW и рестарт."
      exit 0
      ;;
    *)
      echo "❌ Невалиден избор. Въведете 'y' или 'n'."
      ;;
  esac
done

# --------- Край на скрипта ---------

