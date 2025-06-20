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
echo -e "\e[32m=========================================="
echo -e " НАЧАЛНА КОНФИГУРАЦИЯ НА ОТДАЛЕЧЕН СЪРВЪР"
echo -e "==========================================\e[0m"
echo ""

# === ГЛОБАЛНИ ПРОМЕНЛИВИ ===================================================
SERVER_IP="$(ip route get 1.1.1.1 | grep -oP 'src \K[\d.]+')"
SSH_PORT="22"
FQDN=""
ADMIN_USER=""
CONFIRMATION=""
FIREWALL_SYSTEM="unknown"

# === СТЪПКА 1: ВЪВЕЖДАНЕ НА ИНФОРМАЦИЯ ЗА КОНФИГУРАЦИЯТА ====================
echo "== СТЪПКА 1: ВЪВЕЖДАНЕ НА ИНФОРМАЦИЯ ЗА КОНФИГУРАЦИЯТА =="
echo ""

# --- [1] КОНФИГУРАЦИЯ НА СЪРВЪРЕН ДОМЕЙН (FQDN) -----------------------------
echo "[1] КОНФИГУРАЦИЯ НА СЪРВЪРЕН ДОМЕЙН (FQDN)..."
echo "-------------------------------------------------------------------------"
echo ""

while true; do
  printf "👉 Въведете домейна на сървъра (FQDN) или 'q' за изход: "
  read FQDN

  # Проверка за прекратяване от потребителя
  if [[ "$FQDN" == "q" || "$FQDN" == "Q" ]]; then
    echo "❎ Скриптът беше прекратен от потребителя."
    exit 0
  fi

  # Проверка дали входът е празен
  if [[ -z "$FQDN" ]]; then
    echo "❌ Домейнът не може да бъде празен. Опитайте отново."
    continue
  fi

  # Проверка за валиден формат на домейн (не гарантира съществуване)
  if [[ ! "$FQDN" =~ ^([a-zA-Z0-9][-a-zA-Z0-9]*\.)+[a-zA-Z]{2,}$ ]]; then
    echo "❌ Невалиден формат на домейн. Пример за валиден: example.com"
    continue
  fi

  # Проверка дали домейнът резолвира (по избор)
  if ! getent hosts "$FQDN" >/dev/null; then
    echo "⚠️ Внимание: Домейнът '$FQDN' не резолвира в момента."
    printf "Искате ли да продължите с този домейн? [y/N]: "
    read confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      continue
    fi
  fi

  break
done
echo ""
echo ""


# --- [2] ОПРЕДЕЛЯНЕ НА SSH ПОРТ -----------------------------------------------
echo "[2] ОПРЕДЕЛЯНЕ НА SSH ПОРТ..."
echo "-------------------------------------------------------------------------"
echo ""

# Откриване на текущия SSH порт от sshd конфигурацията (ако е настроен)
CURRENT_SSH_PORT=$(ss -tlpn | grep sshd | awk -F: '/LISTEN/ {print $2}' | head -n 1)
CURRENT_SSH_PORT="${CURRENT_SSH_PORT:-22}"

while true; do
  printf "👉 В момента използвате SSH порт $CURRENT_SSH_PORT. Желаете ли да го промените? (y за промяна, Enter за запазване, q за изход): "
  read change_port

  if [[ "$change_port" == "q" || "$change_port" == "Q" ]]; then
    echo "❎ Скриптът беше прекратен от потребителя."
    exit 0
  elif [[ "$change_port" == "y" || "$change_port" == "Y" ]]; then
    while true; do
      printf "➤ Въведете нов SSH порт (между 1024 и 65535) или 'q' за изход: "
      read SSH_PORT

      if [[ "$SSH_PORT" == "q" || "$SSH_PORT" == "Q" ]]; then
        echo "❎ Скриптът беше прекратен от потребителя."
        exit 0
      elif [[ "$SSH_PORT" =~ ^[0-9]+$ ]] && (( SSH_PORT >= 1024 && SSH_PORT <= 65535 )); then
        echo "✅ Нов SSH порт ще бъде: $SSH_PORT"
        break
      else
        echo "❌ Невалиден порт. Допустими стойности: 1024–65535. Опитайте отново."
      fi
    done
    break
  else
    SSH_PORT="$CURRENT_SSH_PORT"
    echo "✅ SSH портът ще остане: $SSH_PORT"
    break
  fi
done
echo ""
echo ""


# --- [3] АДМИНИСТРАТОРСКИ ПРОФИЛ -----------------------------------------------
echo "[3] СЪЗДАВАНЕ НА НОВ АДМИНИСТРАТОРСКИ ПРОФИЛ"
echo "-------------------------------------------------------------------------"
echo "🔐 По съображения за сигурност, root достъпът чрез SSH ще бъде забранен."
echo "✅ Ще създадем нов потребител с root права за административна работа."
echo ""

while true; do
  printf "👉 Въведете потребителско име за новия администратор (q за изход): "
  read ADMIN_USER

  if [[ "$ADMIN_USER" == "q" || "$ADMIN_USER" == "Q" ]]; then
    echo "❎ Скриптът беше прекратен от потребителя."
    exit 0
  fi

  if [[ -z "$ADMIN_USER" ]]; then
    echo "❌ Полето за потребителското име не може да бъде празно."
    continue
  fi

  if [[ ! "$ADMIN_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    echo "❌ Невалидно потребителско име. Разрешени са само малки букви, цифри, '-', '_' и да не започва с цифра."
    continue
  fi

  if id "$ADMIN_USER" &>/dev/null; then
    echo "⚠️ Потребителят '$ADMIN_USER' вече съществува. Изберете друго име."
    continue
  fi

  break
done

while true; do
  printf "🔑 Въведете парола за $ADMIN_USER: "
  read -s PASSWORD_1
  echo
  printf "🔑 Повторете паролата: "
  read -s PASSWORD_2
  echo

  if [[ "$PASSWORD_1" != "$PASSWORD_2" ]]; then
    echo "❌ Паролите не съвпадат. Опитайте отново."
  elif [[ -z "$PASSWORD_1" ]]; then
    echo "❌ Паролата не може да е празна."
  else
    break
  fi
done
echo ""
echo ""


# --- [4] ПРОВЕРКА НА FIREWALL СИСТЕМА --------------------------------------------
echo "[4] ПРОВЕРКА НА FIREWALL СИСТЕМА..."
echo "-------------------------------------------------------------------------"
echo ""

# Проверка дали ufw е инсталиран
if command -v ufw >/dev/null 2>&1; then
  FIREWALL_SYSTEM="ufw"
  echo "🛡️  Засечена активна защитна стена: UFW"

  # Проверка за статус на UFW
  UFW_STATUS=$(ufw status | head -n 1)
  echo "ℹ️  Статус на UFW: $UFW_STATUS"

  echo "📖 Списък на отворените/разрешените портове в UFW:"
  ufw status numbered | sed 's/^/    /'
else
  echo "⚠️  Не е открита инсталирана защитна стена UFW."
  FIREWALL_SYSTEM="none"
fi

# --- [4.1] ДИАЛОГ ЗА FIREWALL СИСТЕМАТА -------------------------------------------
if [[ "$FIREWALL_SYSTEM" != "ufw" ]]; then
  echo ""
  if [[ "$FIREWALL_SYSTEM" == "none" ]]; then
    echo "⚠️  Вашата система в момента не използва защитна стена."
  else
    echo "⚠️  В момента вашата защитна стена е: $FIREWALL_SYSTEM"
  fi

  echo "💡 В бъдеще ще използвате UFW за управление на защитната стена."
  while true; do
    printf "Натиснете Enter за съгласие или 'q' за отказ и прекратяване: "
    read consent
    if [[ "$consent" == "q" || "$consent" == "Q" ]]; then
      echo "❎ Скриптът беше прекратен от потребителя."
      exit 0
    else
      echo "✅ Избрано: ще използваме UFW."
      break
    fi
  done
fi
echo ""
echo ""

# --- [4.2] ВЪВЕЖДАНЕ НА ДОПЪЛНИТЕЛНИ FIREWALL ПОРТОВЕ ----------------------------
PORT_LIST=()

if [[ "$FIREWALL_SYSTEM" != "none" ]]; then
  echo ""
  echo "📡 Засечени отворени портове във вашата защитна стена:"

  if [[ "$FIREWALL_SYSTEM" == "ufw" ]]; then
    ufw status numbered | awk '/ALLOW/ {print $1, $2, $3, $4}' | sed 's/^/  - /'
  else
    # За други системи използваме ss като най-общ подход
    ss -tuln | awk 'NR>1 {print $5}' | cut -d: -f2 | sort -nu | sed 's/^/  - /'
  fi

  while true; do
    printf "➕ Желаете ли да отворите нови портове? (y за да добавите, Enter за пропускане, q за прекратяване): "
    read open_more
    if [[ "$open_more" == "q" || "$open_more" == "Q" ]]; then
      echo "❎ Скриптът беше прекратен от потребителя."
      exit 0
    elif [[ "$open_more" == "y" || "$open_more" == "Y" ]]; then
      break
    else
      echo "🔒 Пропускане на добавяне на нови портове."
      open_more=""
      break
    fi
  done
fi

if [[ "$FIREWALL_SYSTEM" == "none" || "$open_more" == "y" || "$open_more" == "Y" ]]; then
  echo ""
  echo "🧩 Въвеждане на допълнителни портове за отваряне във вашата бъдеща защитна стена (UFW):"
  while true; do
    printf "➤ Въведете порт за отваряне (Enter за край, q за прекратяване): "
    read port
    if [[ "$port" == "q" || "$port" == "Q" ]]; then
      echo "❎ Скриптът беше прекратен от потребителя."
      exit 0
    elif [[ -z "$port" ]]; then
      break
    elif [[ "$port" =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 )); then
      PORT_LIST+=("$port")
      echo "✅ Добавен порт: $port"
    else
      echo "❌ Невалиден номер на порт. Моля, въведете число между 1 и 65535."
    fi
  done
fi
echo ""
echo ""


# === ОБОБЩЕНИЕ =============================================================
echo "[5] ПРЕГЛЕД НА ВЪВЕДЕНАТА ИНФОРМАЦИЯ..."
echo "-------------------------------------------------------------------------"
echo ""
echo ""

echo "✅ Въведена информация:"
echo " - Домейн (FQDN): $FQDN"
echo " - SSH порт: $SSH_PORT"
echo " - Админ потребител: $ADMIN_USER"
echo " - Root достъп по SSH: ще бъде забранен"

echo " - IP адрес на сървъра: $SERVER_IP"
echo " - Защитна стена: $FIREWALL_SYSTEM"
if [[ ${#PORT_LIST[@]} -gt 0 ]]; then
  echo " - Допълнителни портове за отваряне: ${PORT_LIST[*]}"
fi

echo ""
echo "🧐 Моля, прегледайте внимателно въведената информация по-горе."
echo "Ако всичко е вярно, можете да продължите с автоматичната конфигурация."
echo "Ако има грешка, прекратете скрипта, коригирайте и стартирайте отново."
echo ""

while true; do
  printf "✔️ Продължаваме ли с конфигурацията? (y за продължение, q за прекратяване): "
  read CONFIRMATION
  if [[ "$CONFIRMATION" == "q" || "$CONFIRMATION" == "Q" ]]; then
    echo "❎ Скриптът беше прекратен от потребителя."
    exit 0
  elif [[ "$CONFIRMATION" == "y" || "$CONFIRMATION" == "Y" ]]; then
    echo "🚀 Стартиране на автоматичната конфигурация..."
    sleep 1
    clear
    break
  else
    echo "❌ Моля, отговорете с 'y' за продължение или 'q' за прекратяване."
  fi
done
echo ""
echo ""

# === СТЪПКА 2: КОНФИГУРИРАНЕ НА СИСТЕМАТА =======================================
echo "== СТЪПКА 2: КОНФИГУРИРАНЕ НА СИСТЕМАТА =="

echo ""
echo ""
echo "[6] ОБНОВЯВАНЕ НА СИСТЕМАТА..."
echo "-------------------------------------------------------------------------"

if sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get autoremove -y; then
  echo "✅ Системата е успешно обновена."
  RESULT_UPDATE_SYSTEM="✅"
else
  echo "❌ Възникна грешка при обновяване на системата. Проверете горните съобщения."
  RESULT_UPDATE_SYSTEM="❌"
  exit 1
fi
echo ""
echo ""

echo "[7] ИНСТАЛИРАНЕ НА ОСНОВНИТЕ ИНСТРУМЕНТИ..."
echo "-------------------------------------------------------------------------"

if sudo apt-get install -y \
    nano unzip git curl wget net-tools htop \
    python3 python3-pip python3-venv build-essential; then
  echo "✅ Всички основни инструменти и зависимости са инсталирани."
  RESULT_INSTALL_TOOLS="✅"
else
  echo "❌ Възникна грешка при инсталацията. Проверете:"
  echo "1. Дали apt-get cache е обновен (в предходната стъпка)"
  echo "2. Дали има достатъчно дисково пространство"
  RESULT_INSTALL_TOOLS="❌"
  exit 1
fi
echo ""
echo ""

echo "[8] СЪЗДАВАНЕ НА АДМИНИСТРАТОРСКИ ПОТРЕБИТЕЛ..."
echo "-------------------------------------------------------------------------"
RESULT_CREATE_ADMIN_USER="❔"

# Създаване на потребителя
if id "$ADMIN_USER" &>/dev/null; then
  echo "ℹ️ Потребителят '$ADMIN_USER' вече съществува – пропускане на създаването."
  RESULT_CREATE_ADMIN_USER="⚠️"
else
  if sudo adduser --disabled-password --gecos "" "$ADMIN_USER" && \
     echo "$ADMIN_USER:$PASSWORD_1" | sudo chpasswd && \
     sudo usermod -aG sudo "$ADMIN_USER"; then
    echo "✅ Потребителят '$ADMIN_USER' е създаден и добавен към sudo групата."
    RESULT_CREATE_ADMIN_USER="✅"
  else
    echo "❌ Възникна грешка при създаване на потребителя '$ADMIN_USER'."
    RESULT_CREATE_ADMIN_USER="❌"
    exit 1
  fi
fi

# Настройка на SSH достъп (копиране на ключовете от root)
if [[ -f /root/.ssh/authorized_keys ]]; then
  if sudo mkdir -p /home/"$ADMIN_USER"/.ssh && \
     sudo cp /root/.ssh/authorized_keys /home/"$ADMIN_USER"/.ssh/ && \
     sudo chown -R "$ADMIN_USER":"$ADMIN_USER" /home/"$ADMIN_USER"/.ssh && \
     sudo chmod 700 /home/"$ADMIN_USER"/.ssh && \
     sudo chmod 600 /home/"$ADMIN_USER"/.ssh/authorized_keys; then
    echo "✅ Копирани са SSH ключовете от root."
  else
    echo "⚠️ Грешка при копиране на SSH ключовете."
    RESULT_CREATE_ADMIN_USER="⚠️"
  fi
else
  echo "⚠️ Не са открити SSH ключове за копиране от root."
fi
echo ""
echo ""

echo "[9] НАСТРОЙКА НА ЛОКАЛИЗАЦИИ..."
echo "-------------------------------------------------------------------------"
RESULT_LOCALE_SETUP="❔"

# Инсталация на езикови пакети
if ! sudo apt-get install -y language-pack-bg language-pack-ru; then
  echo "⚠️ Внимание: Неуспешна инсталация на езикови пакети. Продължение без тях."
  RESULT_LOCALE_SETUP="⚠️"
fi

# Конфигуриране на /etc/locale.gen
sudo sed -i '/^# *bg_BG.UTF-8 UTF-8/s/^# *//g' /etc/locale.gen
sudo sed -i '/^# *ru_RU.UTF-8 UTF-8/s/^# *//g' /etc/locale.gen
sudo sed -i '/^# *en_US.UTF-8 UTF-8/s/^# *//g' /etc/locale.gen

# Добавяне на локали ако липсват
grep -qxF 'bg_BG.UTF-8 UTF-8' /etc/locale.gen || echo 'bg_BG.UTF-8 UTF-8' | sudo tee -a /etc/locale.gen >/dev/null
grep -qxF 'ru_RU.UTF-8 UTF-8' /etc/locale.gen || echo 'ru_RU.UTF-8 UTF-8' | sudo tee -a /etc/locale.gen >/dev/null
grep -qxF 'en_US.UTF-8 UTF-8' /etc/locale.gen || echo 'en_US.UTF-8 UTF-8' | sudo tee -a /etc/locale.gen >/dev/null

# Генериране на локали
if sudo locale-gen && sudo update-locale; then
  echo "✅ Локализациите са настроени."
  [[ "$RESULT_LOCALE_SETUP" == "❔" ]] && RESULT_LOCALE_SETUP="✅"
else
  echo "⚠️ Внимание: Възникна грешка при генериране на локали. Проверете ръчно."
  RESULT_LOCALE_SETUP="❌"
fi
echo ""
echo ""

echo "[10] КОНФИГУРАЦИЯ НА ВРЕМЕВА ЗОНА UTC..."
echo "-------------------------------------------------------------------------"
RESULT_TIMEZONE_SETUP="❔"

# Промяна на системната часова зона на UTC
if sudo timedatectl set-timezone UTC; then
  echo "✅ Времевата зона е зададена на UTC."
  RESULT_TIMEZONE_SETUP="✅"
else
  echo "❌ Неуспешна смяна на времевата зона. Моля, проверете ръчно."
  RESULT_TIMEZONE_SETUP="❌"
  exit 1
fi
echo ""
echo ""

echo "[11] НАСТРОЙКА НА ВРЕМЕВАТА СИНХРОНИЗАЦИЯ..."
echo "-------------------------------------------------------------------------"
RESULT_TIME_SYNC="❔"

# Спиране на други NTP услуги
echo "🔍 Проверка за активни NTP услуги..."
sudo systemctl stop ntpd 2>/dev/null && sudo systemctl disable ntpd 2>/dev/null
sudo systemctl stop systemd-timesyncd 2>/dev/null && sudo systemctl disable systemd-timesyncd 2>/dev/null

# Инсталиране на chrony
echo "📦 Инсталиране на chrony..."
if ! sudo apt-get install -y chrony; then
  echo "❌ Неуспешна инсталация на chrony."
  RESULT_TIME_SYNC="❌"
  exit 1
fi

# Конфигурация на chrony с универсални сървъри
NTP_SERVERS=(0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org)
echo "⚙️ Конфигуриране на chrony с публични сървъри: ${NTP_SERVERS[*]}"
echo -e "server ${NTP_SERVERS[0]} iburst
server ${NTP_SERVERS[1]} iburst
server ${NTP_SERVERS[2]} iburst
server ${NTP_SERVERS[3]} iburst

rtcsync
makestep 1.0 3
driftfile /var/lib/chrony/drift
logdir /var/log/chrony" | sudo tee /etc/chrony/chrony.conf > /dev/null

# Рестарт и активиране
sudo systemctl restart chrony
sudo systemctl enable chrony

# Проверка на статуса
echo "🔎 Проверка на синхронизацията..."
timedatectl | grep 'Time zone'
echo "NTP статус:"
chronyc tracking | grep -E 'Stratum|System time'
chronyc sources | grep '^\^\*'

echo "✅ Времевата синхронизация е конфигурирана."
RESULT_TIME_SYNC="✅"

echo ""
echo ""

echo "[12] НАСТРОЙКА НА HOSTNAME..."
echo "-------------------------------------------------------------------------"
RESULT_HOSTNAME="❔"

# Извличане на краткото име на хоста от FQDN
HOSTNAME_SHORT="${FQDN%%.*}"

# Задаване на hostname
if sudo hostnamectl set-hostname "$FQDN"; then
  echo "✅ Hostname зададен на: $FQDN"
  RESULT_HOSTNAME="✅"
else
  echo "❌ Неуспешна смяна на hostname."
  RESULT_HOSTNAME="❌"
  exit 1
fi

# Актуализиране на /etc/hosts
sudo tee /etc/hosts > /dev/null <<EOF
127.0.0.1   localhost
127.0.1.1   $FQDN $HOSTNAME_SHORT
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF

echo "✅ /etc/hosts е актуализиран."
echo ""
echo ""

# === СТЪПКА 3: КОНФИГУРАЦИЯ НА UFW И РЕСТАРТ НА СЪРВЪРА ==========================
echo "=== СТЪПКА 3: КОНФИГУРАЦИЯ НА UFW И РЕСТАРТ НА СЪРВЪРА"
echo ""

echo "[13] КОНФИГУРАЦИЯ НА UFW И РЕСТАРТ НА СЪРВЪРА..."
echo "-------------------------------------------------------------------------"
RESULT_UFW_CONFIG="❔"

# --- ДОБАВЯНЕ НА ДОПЪЛНИТЕЛНИ ДОВЕРЕНИ МРЕЖИ (по избор) ----------------------
echo ""
echo "🌐 Ако използвате частна мрежа (VPN, локална LAN и т.н.), можете да добавите разрешение за нея в UFW."
TRUSTED_NETS=()
while true; do
  read -rp "➤ Въведете CIDR на доверена мрежа (напр. 192.168.1.0/24), Enter за край: " net
  if [[ -z "$net" ]]; then
    break
  elif [[ "$net" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
    TRUSTED_NETS+=("$net")
    echo "✅ Добавена мрежа: $net"
  else
    echo "❌ Невалиден формат. Използвайте CIDR, напр. 10.8.0.0/24"
  fi
done

for net in "${TRUSTED_NETS[@]}"; do
  echo "🔐 Разрешаване на достъп от $net към всички портове..."
  sudo ufw allow from "$net"
done

# Инсталиране на UFW, ако не е наличен
if ! command -v ufw >/dev/null 2>&1; then
  echo "📦 Инсталиране на UFW..."
  if ! sudo apt-get install -y ufw; then
    echo "❌ Неуспешна инсталация на UFW."
    RESULT_UFW_CONFIG="❌"
    exit 1
  fi
fi

# Разрешаване на записаните портове
for port in "${PORT_LIST[@]}"; do
  echo "🔓 Отваряне на порт $port..."
  sudo ufw allow "$port"
done

# Разрешаване на SSH порта, ако не е вече добавен
sudo ufw allow "$SSH_PORT"

# Активиране на UFW
if sudo ufw --force enable; then
  echo "✅ UFW е активиран и конфигуриран."
  RESULT_UFW_CONFIG="✅"
else
  echo "❌ Неуспешно активиране на UFW."
  RESULT_UFW_CONFIG="❌"
  exit 1
fi
echo ""
echo ""

echo "[14] ОБОБЩЕНИЕ НА РЕЗУЛТАТИТЕ ОТ КОНФИГУРАЦИЯТА"
echo "-------------------------------------------------------------------------"

printf "📌 Системно обновяване:             %s\n" "${RESULT_SYSTEM_UPDATE:-❔}"
printf "📌 Основни инструменти:             %s\n" "${RESULT_BASE_TOOLS:-❔}"
printf "📌 Админ. потребител:               %s\n" "${RESULT_ADMIN_USER:-❔}"
printf "📌 Локализации:                     %s\n" "${RESULT_LOCALES:-❔}"
printf "📌 Часова зона:                     %s\n" "${RESULT_TIMEZONE:-❔}"
printf "📌 Времева синхронизация:          %s\n" "${RESULT_NTP_SYNC:-❔}"
printf "📌 Hostname:                        %s\n" "${RESULT_HOSTNAME:-❔}"
printf "📌 UFW конфигурация:                %s\n" "${RESULT_UFW_CONFIG:-❔}"

echo ""
echo "ℹ️  Легенда: ✅ успешно | ❌ неуспешно | ⚠️ частично | ❔ неизвестно"
echo ""

# Потвърждение за рестарт
echo ""
echo -e "\e[33mВНИМАНИЕ: Следващото действие ще рестартира сървъра!"
echo "─────────────────────────────────────────────────────────────────────────"
echo -e "\e[0m"

while true; do
  printf "👉 Въведете (R) за РЕСТАРТ или (Q) за изход без рестарт: " choice
  case "$choice" in
    [Rr]*)
      # Премахване на самия скрипт, ако е стартиран от файл
      SCRIPT_PATH="$(realpath "$0")"
      if [[ -f "$SCRIPT_PATH" && "$SCRIPT_PATH" != "/usr/bin/bash" ]]; then
        echo "🧹 Премахване на инсталационния скрипт: $SCRIPT_PATH"
        rm -f "$SCRIPT_PATH"
      else
        echo "ℹ️ Скриптът не е стартиран от файл или не може да бъде премахнат безопасно."
      fi
      
      echo -e "\e[32m[✓] Иницииране на рестарт...\e[0m"
      sudo reboot
      exit 0
      ;;
    [Qq]*)
      echo -e "\e[31m[X] Скриптът приключи без рестарт. Можете да рестартирате ръчно по-късно.\e[0m"
      break
      ;;
    *)
      echo -e "\e[31m[!] Невалиден избор. Моля, въведете R или Q.\e[0m"
      ;;
  esac
done
echo -e "\n✅ Скриптът достигна края на изпълнението.\n"

# --------- Край на скрипта ---------
