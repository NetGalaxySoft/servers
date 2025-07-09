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

# === ИНИЦИАЛИЗАЦИЯ НА СПИСЪК С МОДУЛИ ======================================
MODULES_FILE="todo.modules"

if [[ ! -f "$MODULES_FILE" ]]; then
  echo "⏳ Създаване на файл със списък на модулите ($MODULES_FILE)..."

  cat > "$MODULES_FILE" <<EOF
mod_01_ip_check
mod_02_fqdn_config
mod_03_ssh_port
mod_04_admin_user
mod_05_firewall_setup
mod_06_firewall_trusted
mod_07_summary_reboot
EOF

  echo "✅ Списъкът с модули беше създаден успешно."
else
  echo "ℹ️ Открит съществуващ файл със списък на модулите: $MODULES_FILE"
  echo "   Скриптът ще използва текущото съдържание и ще изпълнява само наличните модули."
fi
echo ""
echo ""


# === [МОДУЛ 1] ВЪВЕЖДАНЕ И ПРОВЕРКА НА IP АДРЕС НА СЪРВЪРА ================
MODULE_NAME="mod_01_ip_check"
if ! grep -q "^$MODULE_NAME$" todo.modules; then
  echo "🔁 Пропускане на $MODULE_NAME (вече изпълнен или не е в списъка)..."
  return 0 2>/dev/null || exit 0
fi

echo "[1] ВЪВЕЖДАНЕ И ПРОВЕРКА НА IP АДРЕС НА СЪРВЪРА..."
echo "-------------------------------------------------------------------------"
echo ""

while true; do
  printf "🌐 Въведете публичния IP адрес на сървъра (или 'q' за изход): "
  read SERVER_IP

  if [[ "$SERVER_IP" == "q" || "$SERVER_IP" == "Q" ]]; then
    echo "❎ Скриптът беше прекратен от потребителя."
    exit 0
  fi

  if [[ "$SERVER_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    break
  else
    echo "❌ Невалиден IP адрес. Моля, въведете валиден IPv4 адрес (напр. 192.168.1.100)."
  fi
done

ACTUAL_IP=$(curl -s ifconfig.me)

if [[ "$ACTUAL_IP" != "$SERVER_IP" ]]; then
  echo ""
  echo "🚫 Скриптът не е стартиран на правилната машина!"
  echo "👉 Въведен IP адрес: $SERVER_IP"
  echo "📍 Открит IP адрес:  $ACTUAL_IP"
  echo "⛔ Прекратяване на изпълнението."
  exit 1
fi

echo "✅ Потвърдено: скриптът е стартиран на сървъра с IP $SERVER_IP."
echo ""

# 🔚 Премахване от списъка:
sed -i "/^$MODULE_NAME$/d" todo.modules

# 🔄 Запитване дали да се продължи:
echo ""
read -p "➡️ Продължаване към следващия модул? [Enter за ДА, 'q' за прекратяване]: " next
if [[ "$next" == "q" || "$next" == "Q" ]]; then
  echo "⛔ Скриптът беше прекратен от потребителя след модул 1."
  exit 0
fi
echo ""
echo ""


# === [МОДУЛ 2] КОНФИГУРАЦИЯ НА СЪРВЪРНИЯ ДОМЕЙН (FQDN) =====================
MODULE_NAME="mod_02_fqdn_config"
if ! grep -q "^$MODULE_NAME$" todo.modules; then
  echo "🔁 Пропускане на $MODULE_NAME (вече изпълнен или не е в списъка)..."
  return 0 2>/dev/null || exit 0
fi

echo "[2] КОНФИГУРАЦИЯ НА СЪРВЪРНИЯ ДОМЕЙН (FQDN)..."
echo "-------------------------------------------------------------------------"
echo ""

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
hostnamectl set-hostname "$FQDN"
echo "✅ Hostname е зададен: $FQDN"

# Добавяне във /etc/hosts, ако липсва
SERVER_IP=$(curl -s ifconfig.me)
if ! grep -q "$FQDN" /etc/hosts; then
  echo "$SERVER_IP    $FQDN" >> /etc/hosts
  echo "✅ Добавен ред в /etc/hosts: $SERVER_IP $FQDN"
else
  echo "ℹ️ Домейнът вече съществува във /etc/hosts"
fi

# Потвърждение
CURRENT_HOSTNAME=$(hostname)
if [[ "$CURRENT_HOSTNAME" == "$FQDN" ]]; then
  echo "✅ Потвърдено: текущият hostname е $CURRENT_HOSTNAME"
else
  echo "⚠️ Предупреждение: hostname не съвпада ($CURRENT_HOSTNAME)"
fi

# 🔚 Премахване от списъка:
sed -i "/^$MODULE_NAME$/d" todo.modules

# 🔄 Запитване дали да се продължи:
echo ""
read -p "➡️ Продължаване към следващия модул? [Enter за ДА, 'q' за прекратяване]: " next
if [[ "$next" == "q" || "$next" == "Q" ]]; then
  echo "⛔ Скриптът беше прекратен от потребителя след модул 2."
  exit 0
fi
echo ""
echo ""


# === [МОДУЛ 3] ПРОМЯНА НА SSH ПОРТА ========================================
MODULE_NAME="mod_03_ssh_port"
if ! grep -q "^$MODULE_NAME$" todo.modules; then
  echo "🔁 Пропускане на $MODULE_NAME (вече изпълнен или не е в списъка)..."
  return 0 2>/dev/null || exit 0
fi

echo "[3] ПРОМЯНА НА SSH ПОРТА..."
echo "-------------------------------------------------------------------------"
echo ""

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

# Промяна в sshd_config, ако портът е различен от текущия
if [[ "$SSH_PORT" != "$CURRENT_SSH_PORT" ]]; then
  echo "🔧 Актуализиране на /etc/ssh/sshd_config..."

  if grep -q "^#*Port " /etc/ssh/sshd_config; then
    sudo sed -i "s/^#*Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
  else
    echo "Port $SSH_PORT" | sudo tee -a /etc/ssh/sshd_config > /dev/null
  fi

  echo "🔄 Рестартиране на SSH услугата..."
  sudo systemctl restart ssh

  if [[ $? -eq 0 ]]; then
    echo "✅ SSH портът е променен успешно на $SSH_PORT и услугата е рестартирана."
  else
    echo "❌ Грешка при рестартиране на SSH! Провери конфигурацията ръчно!"
    exit 1
  fi
else
  echo "ℹ️ Няма промяна – SSH портът остава $SSH_PORT."
fi

# 🔚 Премахване от списъка:
sed -i "/^$MODULE_NAME$/d" todo.modules

# 🔄 Запитване дали да се продължи:
echo ""
read -p "➡️ Продължаване към следващия модул? [Enter за ДА, 'q' за прекратяване]: " next
if [[ "$next" == "q" || "$next" == "Q" ]]; then
  echo "⛔ Скриптът беше прекратен от потребителя след модул 3."
  exit 0
fi
echo ""
echo ""


# === [МОДУЛ 4] СЪЗДАВАНЕ НА НОВ АДМИНИСТРАТОРСКИ ПРОФИЛ ====================
MODULE_NAME="mod_04_admin_user"
if ! grep -q "^$MODULE_NAME$" todo.modules; then
  echo "🔁 Пропускане на $MODULE_NAME (вече изпълнен или не е в списъка)..."
  return 0 2>/dev/null || exit 0
fi

echo "[4] СЪЗДАВАНЕ НА НОВ АДМИНИСТРАТОРСКИ ПРОФИЛ"
echo "-------------------------------------------------------------------------"
echo "🔐 По съображения за сигурност, root достъпът чрез SSH ще бъде забранен."
echo "✅ Ще създадем нов потребител с root права за административна работа."
echo ""

# Въвеждане на име
while true; do
  printf "👉 Въведете потребителско име за новия администратор (мин. 3 символа или q за изход): "
  read ADMIN_USER

  if [[ "$ADMIN_USER" == "q" || "$ADMIN_USER" == "Q" ]]; then
    echo "❎ Скриптът беше прекратен от потребителя."
    exit 0
  fi

  if [[ -z "$ADMIN_USER" ]]; then
    echo "❌ Полето за потребителското име не може да бъде празно."
    continue
  fi

  if [[ ${#ADMIN_USER} -lt 3 ]]; then
    echo "❌ Потребителското име трябва да бъде поне 3 символа."
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

# Инструкции за парола
echo "🛡️ Паролата трябва да отговаря на следните условия:"
echo "   - Минимум 8 символа"
echo "   - Поне една латинска малка буква (a-z)"
echo "   - Поне една латинска главна буква (A-Z)"
echo "   - Поне една цифра (0-9)"
echo "❗ Внимание: Проверете на какъв език въвеждате, ако използвате специфични букви (напр. кирилица)"
echo ""

# Въвеждане и потвърждение на парола
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
      printf "❓ Искате ли да продължите с тази парола? (y / n): "
      read -r confirm_charset
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

# Създаване на потребител
echo "👤 Създаване на потребител '$ADMIN_USER'..."
sudo useradd -m -s /bin/bash "$ADMIN_USER"
echo "$ADMIN_USER:$PASSWORD_1" | sudo chpasswd
sudo usermod -aG sudo "$ADMIN_USER"
echo "✅ Потребителят '$ADMIN_USER' беше създаден с root права."

# Забрана за root вход чрез SSH
if sudo grep -q "^PermitRootLogin" /etc/ssh/sshd_config; then
  sudo sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
else
  echo "PermitRootLogin no" | sudo tee -a /etc/ssh/sshd_config > /dev/null
fi
sudo systemctl restart ssh
echo "🔒 Root достъпът чрез SSH е забранен."

# 🔚 Премахване от списъка:
sed -i "/^$MODULE_NAME$/d" todo.modules

# 🔄 Продължение:
echo ""
read -p "➡️ Продължаване към следващия модул? [Enter за ДА, 'q' за прекратяване]: " next
if [[ "$next" == "q" || "$next" == "Q" ]]; then
  echo "⛔ Скриптът беше прекратен от потребителя след модул 4."
  exit 0
fi
echo ""
echo ""


# === [МОДУЛ 5] UFW: ДЕАКТИВАЦИЯ НА ДРУГИ И ДОБАВЯНЕ НА ПОРТОВЕ ==============
MODULE_NAME="mod_05_firewall_setup"
if ! grep -q "^$MODULE_NAME$" todo.modules; then
  echo "🔁 Пропускане на $MODULE_NAME (вече изпълнен или не е в списъка)..."
  return 0 2>/dev/null || exit 0
fi

echo "[5] КОНФИГУРИРАНЕ НА UFW И ДЕАКТИВАЦИЯ НА ДРУГИ FIREWALL..."
echo "-------------------------------------------------------------------------"
echo ""

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

# --- Инсталиране на UFW, ако липсва ---
if ! command -v ufw >/dev/null 2>&1; then
  echo "📦 Инсталиране на UFW..."
  sudo apt-get update
  sudo apt-get install -y ufw
fi

FIREWALL_SYSTEM="ufw"
echo "FIREWALL_SYSTEM=ufw" > .setup.env

# --- Зареждане на SSH_PORT, ако е наличен ---
if [[ -f .setup.env ]]; then
  source .setup.env
fi

if [[ -n "$SSH_PORT" ]]; then
  echo "🔐 Разрешаване на SSH порт: $SSH_PORT"
  sudo ufw allow "$SSH_PORT"/tcp
else
  echo "⚠️ SSH порт не е открит. Пропуска се автоматично разрешение."
fi

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

# --- Запис на портовете във .setup.env (по избор) ---
echo "PORT_LIST=\"${PORT_LIST[*]}\"" >> .setup.env

echo ""
echo "✅ Правилата за UFW са подготвени, но защитната стена все още НЕ е активирана."
echo "   Това ще бъде направено в следващия модул."

# 🔚 Премахване от списъка:
sed -i "/^$MODULE_NAME$/d" todo.modules

# 🔄 Продължение:
echo ""
read -p "➡️ Продължаване към следващия модул? [Enter за ДА, 'q' за прекратяване]: " next
if [[ "$next" == "q" || "$next" == "Q" ]]; then
  echo "⛔ Скриптът беше прекратен от потребителя след модул 5."
  exit 0
fi
echo ""
echo ""


# === [МОДУЛ 6] TRUSTED МРЕЖИ И АКТИВИРАНЕ НА UFW ============================
MODULE_NAME="mod_06_firewall_trusted"
if ! grep -q "^$MODULE_NAME$" todo.modules; then
  echo "🔁 Пропускане на $MODULE_NAME (вече изпълнен или не е в списъка)..."
  return 0 2>/dev/null || exit 0
fi

echo "[6] ДОБАВЯНЕ НА TRUSTED МРЕЖИ И АКТИВИРАНЕ НА UFW..."
echo "-------------------------------------------------------------------------"
echo ""

# Зареждане на вече подготвени променливи
if [[ -f .setup.env ]]; then
  source .setup.env
fi

# Проверка за наличен UFW
if ! command -v ufw >/dev/null 2>&1; then
  echo "❌ Грешка: UFW не е инсталиран. Скриптът не може да продължи."
  exit 1
fi

# Проверка дали ще се използват trusted мрежи
TRUSTED_NETS=()
while true; do
  printf "🌐 Ще използвате ли достъп от частна (trusted) мрежа? (напр. VPN, вътрешна LAN)? (y / n / q): "
  read -r use_trust

  case "$use_trust" in
    [Qq]*) echo "❎ Скриптът беше прекратен от потребителя."; exit 0 ;;
    [Nn]*) echo "🔒 Няма да се добавят доверени мрежи."; break ;;
    [Yy]*)
      echo ""
      echo "🧩 Въвеждайте по една мрежа в CIDR формат (напр. 10.8.0.0/24)."
      echo "👉 Натиснете Enter без въвеждане за край, или въведете 'q' за прекратяване."
      echo ""
      while true; do
        printf "➤ Мрежа: "
        read -r net

        if [[ "$net" == "q" || "$net" == "Q" ]]; then
          echo "❎ Скриптът беше прекратен от потребителя."; exit 0
        elif [[ -z "$net" ]]; then
          break
        elif [[ "$net" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
          TRUSTED_NETS+=("$net")
          echo "✅ Добавена мрежа: $net"
        else
          echo "❌ Невалиден формат. Използвайте CIDR, напр. 192.168.1.0/24"
        fi
      done
      break
      ;;
    *) echo "❌ Моля, отговорете с 'y', 'n' или 'q'." ;;
  esac
done

# Добавяне на правилата в UFW
for net in "${TRUSTED_NETS[@]}"; do
  sudo ufw allow from "$net"
  echo "✅ Разрешен достъп от доверена мрежа: $net"
done

# Запис в .setup.env (по избор)
echo "TRUSTED_NETS=\"${TRUSTED_NETS[*]}\"" >> .setup.env

# 🔐 Финално активиране на UFW
echo ""
echo "🟢 Активиране на защитната стена UFW..."
sudo ufw --force enable

if [[ $? -eq 0 ]]; then
  echo "✅ Защитната стена беше активирана успешно."
else
  echo "❌ Грешка при активиране на UFW!"
  exit 1
fi

# 🔚 Премахване от списъка:
sed -i "/^$MODULE_NAME$/d" todo.modules

# 🔄 Продължение:
echo ""
read -p "➡️ Продължаване към следващия модул? [Enter за ДА, 'q' за прекратяване]: " next
if [[ "$next" == "q" || "$next" == "Q" ]]; then
  echo "⛔ Скриптът беше прекратен от потребителя след модул 6."
  exit 0
fi
echo ""
echo ""

# === [МОДУЛ 7] ОБОБЩЕНИЕ НА КОНФИГУРАЦИЯТА И РЕСТАРТ ========================
MODULE_NAME="mod_07_summary_reboot"
if ! grep -q "^$MODULE_NAME$" todo.modules; then
  echo "🔁 Пропускане на $MODULE_NAME (вече изпълнен или не е в списъка)..."
  return 0 2>/dev/null || exit 0
fi

echo "[7] ОБОБЩЕНИЕ НА КОНФИГУРАЦИЯТА И РЕСТАРТ..."
echo "-------------------------------------------------------------------------"
echo ""

# Зареждане на информация от .setup.env
if [[ -f .setup.env ]]; then
  source .setup.env
else
  echo "⚠️ Липсва файл .setup.env – няма налична информация за конфигурацията."
fi

# Извеждане на резултатите
echo "📋 СЪСТОЯНИЕ НА КОНФИГУРАЦИЯТА:"
echo ""
printf "🌐 IP адрес на сървъра:           %s\n" "$(curl -s ifconfig.me)"
printf "🌍 FQDN (hostname):               %s\n" "$(hostname)"
printf "🔐 SSH порт:                      %s\n" "${SSH_PORT:-❔ не е зададен}"
printf "👤 Администраторски потребител:   %s\n" "${ADMIN_USER:-❔ не е зададен}"
printf "🛡️  Защитна стена (FIREWALL):     %s\n" "${FIREWALL_SYSTEM:-❔ не е зададена}"
printf "🚪 Отворени портове:              %s\n" "${PORT_LIST:-❔ няма въведени}"
printf "🌐 Доверени мрежи (VPN/LAN):      %s\n" "${TRUSTED_NETS:-❔ няма въведени}"
echo ""

# Проверка дали UFW е активен
if sudo ufw status | grep -iq "inactive"; then
  echo "❌ UFW НЕ Е АКТИВЕН! Моля, активирайте го преди рестарт."
  read -p "➡️ Активиране на UFW сега? (y / q): " activate_ufw
  if [[ "$activate_ufw" =~ ^[Yy]$ ]]; then
    sudo ufw --force enable
    echo "✅ UFW беше активиран успешно."
  else
    echo "❎ Скриптът беше прекратен. Не е безопасно да рестартирате сървъра без активен firewall."
    exit 1
  fi
else
  echo "✅ UFW е активен."
fi

# 🔁 Питане за рестарт с изтриване на временните файлове
echo ""
while true; do
  echo "♻️ Желаете ли да рестартирате системата сега?"
  read -p "Въведете 'r' за рестарт, 'q' за изход без рестарт, или Enter за край: " restart_choice
  case "$restart_choice" in
    [Rr]*)
      echo "🧹 Изчистване на временните файлове..."
      rm -f .setup.env todo.modules
      echo "🔄 Рестартиране на системата..."
      sleep 2
      sudo reboot
      ;;
    [Qq]*)
      echo "⛔ Скриптът завърши без рестарт. Моля, рестартирайте ръчно по-късно."
      break
      ;;
    "")
      echo "✅ Скриптът завърши успешно. UFW е активен. Няма рестарт."
      break
      ;;
    *)
      echo "❌ Моля, въведете 'r', 'q' или натиснете Enter."
      ;;
  esac
done

# 🔚 Премахване от списъка:
sed -i "/^$MODULE_NAME$/d" todo.modules

# --------- Край на скрипта ---------
