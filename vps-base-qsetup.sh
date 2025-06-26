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

# --- [1] ВЪВЕЖДАНЕ И ПРОВЕРКА НА IP АДРЕС НА СЪРВЪРА ------------------------
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

# Автоматично откриване на текущия публичен IP
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
echo ""

# --- [2] КОНФИГУРАЦИЯ НА СЪРВЪРЕН ДОМЕЙН (FQDN) -----------------------------
echo "[2] КОНФИГУРАЦИЯ НА СЪРВЪРЕН ДОМЕЙН (FQDN)..."
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
   while true; do
     printf "❓ Искате ли да продължите с този домейн? (y / n): "
     read -r confirm
     if [[ "$confirm" =~ ^[Yy]$ ]]; then
       break  # продължаваме със същия домейн
     elif [[ "$confirm" =~ ^[Nn]$ || -z "$confirm" ]]; then
       continue 2  # връщаме се към въвеждането на нов домейн
     else
       echo "❌ Моля, отговорете с 'y' за да продължите или 'n' за нов домейн."
     fi
   done
 fi

  break
done
echo ""
echo ""

# --- [3] ОПРЕДЕЛЯНЕ НА SSH ПОРТ -----------------------------------------------
echo "[3] ОПРЕДЕЛЯНЕ НА SSH ПОРТ..."
echo "-------------------------------------------------------------------------"
echo ""

# Откриване на текущия SSH порт (или задаване на 22, ако не се открие)
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
echo ""
echo ""

# --- [4] АДМИНИСТРАТОРСКИ ПРОФИЛ -----------------------------------------------
echo "[4] СЪЗДАВАНЕ НА НОВ АДМИНИСТРАТОРСКИ ПРОФИЛ"
echo "-------------------------------------------------------------------------"
echo "🔐 По съображения за сигурност, root достъпът чрез SSH ще бъде забранен."
echo "✅ Ще създадем нов потребител с root права за административна работа."
echo ""

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

  # Проверка за дължина, малка буква, главна буква и цифра
  if (( ${#PASSWORD_1} < 8 )) || \
     ! [[ "$PASSWORD_1" =~ [a-z] ]] || \
     ! [[ "$PASSWORD_1" =~ [A-Z] ]] || \
     ! [[ "$PASSWORD_1" =~ [0-9] ]]; then
    echo "❌ Паролата трябва да съдържа поне 8 символа, включително малка и главна латинска буква, и цифра."
    continue
  fi

  # Проверка за букви извън латиницата
  if LC_ALL=C grep -q '[^ -~]' <<< "$PASSWORD_1"; then
    echo "⚠️ Внимание: В паролата са открити букви или знаци, които не са част от стандартната латиница."
    echo "   Това може да се дължи на използване на кирилица или други нестандартни символи."
    while true; do
      printf "❓ Искате ли да продължите с тази парола? (y / n): "
      read -r confirm_charset
      if [[ "$confirm_charset" =~ ^[Yy]$ ]]; then
        break
      elif [[ "$confirm_charset" =~ ^[Nn]$ || -z "$confirm_charset" ]]; then
        continue 2  # въведи нова парола
      else
        echo "❌ Моля, отговорете с 'y' или 'n'."
      fi
    done
  fi

  # Повторно въвеждане
  printf "🔑 Повторете паролата: "
  read -s PASSWORD_2
  echo

  if [[ "$PASSWORD_1" != "$PASSWORD_2" ]]; then
    echo "❌ Паролите не съвпадат. Опитайте отново."
  else
    break
  fi
done
echo ""
echo ""

# --- [5] ПРОВЕРКА ЗА FIREWALL СИСТЕМА --------------------------------------------
echo "[5] ПРОВЕРКА ЗА FIREWALL СИСТЕМА..."
echo "-------------------------------------------------------------------------"
echo ""

FIREWALL_SYSTEM="none"
FIREWALL_ACTIVE="no"

# Засичане на налична защитна стена
if command -v ufw >/dev/null 2>&1; then
  FIREWALL_SYSTEM="ufw"
elif command -v firewalld >/dev/null 2>&1; then
  FIREWALL_SYSTEM="firewalld"
elif command -v iptables >/dev/null 2>&1; then
  FIREWALL_SYSTEM="iptables"
fi

# Обработка на различните сценарии
case "$FIREWALL_SYSTEM" in
  "ufw")
    echo "🛡️  Засечена система за управление на защитната стена: UFW"
    if sudo ufw status | grep -iq "inactive"; then
      echo "ℹ️  UFW е инсталиран, но не е активиран."
      echo "⚠️  Вашата система разполага с неактивирана защитна стена **UFW**, която е задължителна за сървърите на платформата NetGalaxy."
      while true; do
        printf "✔️ Желаете ли да я активирате? (y за съгласие, q за изход): "
        read confirm
        case "$confirm" in
          [Yy]*) break ;;
          [Qq]*) echo "❎ Скриптът беше прекратен от потребителя."; exit 0 ;;
          *) echo "❌ Моля, отговорете с 'y' или 'q'." ;;
        esac
      done
    else
      echo "✅ Защитната стена **UFW** е активна."
      echo ""
      echo "📖 Засечени отворени портове в UFW:"
      sudo ufw status numbered 2>/dev/null | sed 's/^/    /'
    fi
    ;;

  "none")
    echo "⚠️  В момента вашата система **не използва защитна стена**."
    echo "🛡️  В бъдеще ще използвате защитна стена **UFW**, която е задължителна за сървърите на платформата NetGalaxy."
    while true; do
      printf "✔️ Желаете ли да продължите с конфигуриране на UFW? (y за съгласие, q за изход): "
      read confirm
      case "$confirm" in
        [Yy]*) break ;;
        [Qq]*) echo "❎ Скриптът беше прекратен от потребителя."; exit 0 ;;
        *) echo "❌ Моля, отговорете с 'y' или 'q'." ;;
      esac
    done
    ;;

  *)
    echo "🔁 В момента използвате защитна стена: $FIREWALL_SYSTEM"
    echo "📌 В бъдеще тази система ще бъде деактивирана и ще се използва **UFW**, която е задължителна за сървърите на платформата NetGalaxy."
    echo ""
    echo "📖 Засечени отворени портове:"
    ss -tuln | awk 'NR>1 {print $5}' | cut -d: -f2 | sort -nu | sed 's/^/  - /'
    while true; do
      printf "✔️ Желаете ли да продължите с преминаване към UFW? (y за съгласие, q за изход): "
      read confirm
      case "$confirm" in
        [Yy]*) break ;;
        [Qq]*) echo "❎ Скриптът беше прекратен от потребителя."; exit 0 ;;
        *) echo "❌ Моля, отговорете с 'y' или 'q'." ;;
      esac
    done
    ;;
esac
echo ""
echo ""


# --- [5.1] ОТВОРЕНИ ПОРТОВЕ НА ЗАЩИТНАТА СТЕНА ------------------
echo "[5.1] ОТВОРЕНИ ПОРТОВЕ НА ЗАЩИТНАТА СТЕНА..."
echo "------------------------------------------------------------"
echo ""

# Показване на SSH порта, независимо от защитната стена
if [[ -n "$SSH_PORT" ]]; then
  echo "🔐 Избран порт за SSH достъп до сървъра: $SSH_PORT"
  echo ""
fi

# Проверка дали има активна защитна стена и засечени отворени портове
OPEN_PORTS=()

if [[ "$FIREWALL_SYSTEM" == "ufw" ]]; then
  mapfile -t OPEN_PORTS < <(sudo ufw status numbered 2>/dev/null | awk '/ALLOW/ {print $1 ": " $2}' | sed 's/^/  - /')
elif [[ "$FIREWALL_SYSTEM" == "firewalld" || "$FIREWALL_SYSTEM" == "iptables" ]]; then
  mapfile -t OPEN_PORTS < <(ss -tuln | awk 'NR>1 {print $5}' | cut -d: -f2 | sort -nu | sed 's/^/  - /')
fi

if [[ ${#OPEN_PORTS[@]} -gt 0 ]]; then
  echo "📡 Засечени отворени портове във вашата защитна стена:"
  for port in "${OPEN_PORTS[@]}"; do
    echo "$port"
  done
  echo ""

  echo "⚠️  Съгласно изискванията за сигурност на платформата **NetGalaxy**,"
  echo "всички ненужни портове трябва да бъдат **затворени** при първоначалната конфигурация на сървъра."
  echo ""
  echo "👉 Ако тези портове са **необходими** за работата на вашата система, потвърдете с 'y'."
  echo "👉 Ако желаете те да бъдат затворени (или ще посочите нужните по-късно), натиснете Enter."
  echo "👉 Натиснете 'q' за прекратяване на скрипта."

  while true; do
    printf "✔️ Вашият избор: "
    read ports_keep
    case "$ports_keep" in
      [Yy]*) break ;;
      [Qq]*) echo "❎ Скриптът беше прекратен от потребителя."; exit 0 ;;
      "")    echo "🔐 Отварянето на нови портове ще бъде конфигурирано ръчно в следващата стъпка."; break ;;
      *)     echo "❌ Моля, отговорете с 'y', Enter или 'q'." ;;
    esac
  done
else
  echo "✅ Не са засечени отворени портове освен SSH ($SSH_PORT)."
fi
echo ""
echo ""

# --- [5.2] ОТВАРЯНЕ НА ДОПЪЛНИТЕЛНИ ПОРТОВЕ -----------------------------
echo "[5.2] ОТВАРЯНЕ НА ДОПЪЛНИТЕЛНИ ПОРТОВЕ..."
echo "--------------------------------------------------------------------"
echo ""

PORT_LIST=()

# Само ако системата има защитна стена
if [[ "$FIREWALL_SYSTEM" != "none" ]]; then
  echo "⚠️  ВНИМАНИЕ! ОТВАРЯЙТЕ САМО ТЕЗИ ПОРТОВЕ, ЗА КОИТО СТЕ СИГУРНИ, ЧЕ СА НЕОБХОДИМИ!"
  echo "❗ Отварянето на ненужни портове създава рискове за сигурността на сървъра."
  echo ""
  echo "🧩 Въвеждайте по един порт на ред (между 1 и 65535)"
  echo "👉 или натиснете Enter без въвеждане на порт, за да продължите."
  echo "👉 Въведете 'q', ако желаете да прекратите изпълнението на скрипта."
  echo ""

  while true; do
    printf "➤ Въведете порт: "
    read -r port

    if [[ "$port" == "q" || "$port" == "Q" ]]; then
      echo "❎ Скриптът беше прекратен от потребителя."
      exit 0
    elif [[ -z "$port" ]]; then
      break
    elif ! [[ "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
      echo "❌ Невалиден порт. Въведете число между 1 и 65535."
      continue
    fi

    # Проверка дали вече е въведен
    if [[ " ${PORT_LIST[*]} " =~ " $port " ]]; then
      echo "⚠️ Порт $port вече е добавен."
    else
      PORT_LIST+=("$port")
      echo "✅ Добавен порт: $port"
    fi
  done
fi
echo ""
echo ""

# --- [5.3] ДОБАВЯНЕ НА ЧАСТНИ МРЕЖИ (TRUSTED_NETS) -------------------------------
echo "[5.3] ДОБАВЯНЕ НА ЧАСТНИ МРЕЖИ (TRUSTED_NETS)..."
echo "--------------------------------------------------------------------"
echo ""

TRUSTED_NETS=()

# Питане дали ще се използва частна мрежа
while true; do
  printf "🌐 Ще използвате ли достъп от частна мрежа (напр. VPN, вътрешна LAN)? (y / n / q за прекратяване): "
  read -r use_private_net

  if [[ "$use_private_net" == "q" || "$use_private_net" == "Q" ]]; then
    echo "❎ Скриптът беше прекратен от потребителя."
    exit 0

  elif [[ "$use_private_net" == "y" || "$use_private_net" == "Y" ]]; then
    echo ""
    echo "🧩 Въведете CIDR адресите на доверените частни мрежи (напр. 10.8.0.0/24):"
    echo "👉 Натиснете Enter без въвеждане за край или въведете 'q' за прекратяване."
    echo ""

    while true; do
      printf "➤ Въведете мрежа: "
      read -r net

      if [[ "$net" == "q" || "$net" == "Q" ]]; then
        echo "❎ Скриптът беше прекратен от потребителя."
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
    break

  elif [[ "$use_private_net" == "n" || "$use_private_net" == "N" ]]; then
    echo "🔒 Пропускане на добавяне на доверени частни мрежи."
    break

  else
    echo "❌ Невалиден отговор. Моля, въведете 'y', 'n' или 'q'."
  fi
done
echo ""
echo ""

# === [6] ПРЕГЛЕД НА ВЪВЕДЕНАТА ИНФОРМАЦИЯ =====================================
echo "[6] ПРЕГЛЕД НА ВЪВЕДЕНАТА ИНФОРМАЦИЯ..."
echo "-------------------------------------------------------------------------"
echo ""

# Цветове, ако терминалът ги поддържа
if [[ -t 1 && "$TERM" != "dumb" ]]; then
  COLOR_YELLOW="\e[93m"      # Ярко жълт
  COLOR_GREEN="\e[32;1m"     # Удебелен зелен
  COLOR_RESET="\e[0m"
else
  COLOR_YELLOW=""
  COLOR_GREEN=""
  COLOR_RESET=""
fi

# Обобщение
echo -e "✅ ${COLOR_YELLOW}Сървърът ще бъде конфигуриран със следните параметри:${COLOR_RESET}"
echo ""
echo -e " - ${COLOR_YELLOW}IP адрес:${COLOR_RESET}               ${COLOR_GREEN}${SERVER_IP}${COLOR_RESET}"
echo -e " - ${COLOR_YELLOW}Домейн (FQDN):${COLOR_RESET}          ${COLOR_GREEN}${FQDN}${COLOR_RESET}"
echo -e " - ${COLOR_YELLOW}SSH порт:${COLOR_RESET}               ${COLOR_GREEN}${SSH_PORT}${COLOR_RESET}"
echo -e " - ${COLOR_YELLOW}Защитна стена:${COLOR_RESET}          ${COLOR_GREEN}${FIREWALL_SYSTEM}${COLOR_RESET}"
echo ""
echo -e " - ${COLOR_YELLOW}Сървърен администратор:${COLOR_RESET} ${COLOR_GREEN}${ADMIN_USER}${COLOR_RESET}"
echo -e " - ${COLOR_YELLOW}Root достъп по SSH:${COLOR_RESET}     ${COLOR_GREEN}Ще бъде забранен${COLOR_RESET}"
if [[ ${#PORT_LIST[@]} -gt 0 ]]; then
  echo -e " - ${COLOR_YELLOW}Допълнителни портове:${COLOR_RESET}   ${COLOR_GREEN}${PORT_LIST[*]}${COLOR_RESET}"
fi

if [[ ${#TRUSTED_NETS[@]} -gt 0 ]]; then
  echo -e " - ${COLOR_YELLOW}Частни мрежи с достъп:${COLOR_RESET}  ${COLOR_GREEN}${TRUSTED_NETS[*]}${COLOR_RESET}"
else
  echo -e " - ${COLOR_YELLOW}Частни мрежи с достъп:${COLOR_RESET}  ${COLOR_GREEN}няма добавени${COLOR_RESET}"
fi

echo ""
echo "🧐 Моля, прегледайте внимателно правилността на въведената информация по-горе."
echo "Ако имате забележки, прекратете конфигурацията, коригирайте и стартирайте отново този скрипт."
echo ""

while true; do
  printf "✔️ Въведете '${COLOR_GREEN}y${COLOR_RESET}' за продължение или '${COLOR_GREEN}q${COLOR_RESET}' за прекратяване: "
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


# ====== СТЪПКА 2: КОНФИГУРИРАНЕ НА СИСТЕМАТА ====================================
echo "== СТЪПКА 2: КОНФИГУРИРАНЕ НА СИСТЕМАТА =="
echo ""
echo ""
# ================================================================================
echo ""
echo ""

echo "[7] ОБНОВЯВАНЕ НА СИСТЕМАТА..."
echo "-------------------------------------------------------------------------"

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
    RESULT_SYSTEM_UPDATE="❌"
    exit 1
  fi
done

# Изпълнение на обновяването
if sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get autoremove -y; then
  echo "✅ Системата е успешно обновена."
  RESULT_SYSTEM_UPDATE="✅"
else
  echo "❌ Възникна грешка при обновяване на системата. Проверете горните съобщения."
  RESULT_SYSTEM_UPDATE="❌"
  exit 1
fi
echo ""
echo ""

echo "[8] ИНСТАЛИРАНЕ НА ОСНОВНИТЕ ИНСТРУМЕНТИ..."
echo "-------------------------------------------------------------------------"

if sudo apt-get install -y \
    nano unzip git curl wget net-tools htop \
    python3 python3-pip python3-venv build-essential; then
  echo "✅ Всички основни инструменти и зависимости са инсталирани."
  RESULT_BASE_TOOLS="✅"
else
  echo "❌ Възникна грешка при инсталацията. Проверете:"
  echo "1. Дали apt-get cache е обновен (в предходната стъпка)"
  echo "2. Дали има достатъчно дисково пространство"
  RESULT_BASE_TOOLS="❌"
  exit 1
fi
echo ""
echo ""

echo "[9] СЪЗДАВАНЕ НА НОВ АДМИНИСТРАТОРСКИ ПРОФИЛ..."
echo "-------------------------------------------------------------------------"
RESULT_ADMIN_USER="❔"

# Създаване на потребителя
if id "$ADMIN_USER" &>/dev/null; then
  echo "ℹ️ Потребителят '$ADMIN_USER' вече съществува – пропускане на създаването."
  RESULT_ADMIN_USER="⚠️"
else
  if sudo adduser --disabled-password --gecos "" "$ADMIN_USER" && \
     echo "$ADMIN_USER:$PASSWORD_1" | sudo chpasswd && \
     sudo usermod -aG sudo "$ADMIN_USER"; then
    echo "✅ Потребителят '$ADMIN_USER' е създаден и добавен към sudo групата."
    RESULT_ADMIN_USER="✅"
  else
    echo "❌ Възникна грешка при създаване на потребителя '$ADMIN_USER'."
    RESULT_ADMIN_USER="❌"
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
    RESULT_ADMIN_USER="⚠️"
  fi
else
  echo "⚠️ Не са открити SSH ключове за копиране от root."
fi
echo ""
echo ""

echo "[10] НАСТРОЙКА НА ЛОКАЛИЗАЦИИ..."
echo "-------------------------------------------------------------------------"
RESULT_LOCALES="❔"

# Инсталация на езикови пакети
if ! sudo apt-get install -y language-pack-bg language-pack-ru; then
  echo "⚠️ Внимание: Неуспешна инсталация на езикови пакети. Продължение без тях."
  RESULT_LOCALES="⚠️"
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
  [[ "$RESULT_LOCALES" == "❔" ]] && RESULT_LOCALES="✅"
else
  echo "⚠️ Внимание: Възникна грешка при генериране на локали. Проверете ръчно."
  RESULT_LOCALES="❌"
fi
echo ""
echo ""

echo "[11] КОНФИГУРАЦИЯ НА ВРЕМЕВА ЗОНА UTC..."
echo "-------------------------------------------------------------------------"
RESULT_TIMEZONE="❔"

# Промяна на системната часова зона на UTC
if sudo timedatectl set-timezone UTC; then
  echo "✅ Времевата зона е зададена на UTC."
  RESULT_TIMEZONE="✅"
else
  echo "❌ Неуспешна смяна на времевата зона. Моля, проверете ръчно."
  RESULT_TIMEZONE="❌"
  exit 1
fi
echo ""
echo ""

echo "[12] НАСТРОЙКА НА ВРЕМЕВАТА СИНХРОНИЗАЦИЯ..."
echo "-------------------------------------------------------------------------"
RESULT_NTP_SYNC="❔"

# Спиране на други NTP услуги
echo "🔍 Проверка за активни NTP услуги..."
sudo systemctl stop ntpd 2>/dev/null && sudo systemctl disable ntpd 2>/dev/null
sudo systemctl stop systemd-timesyncd 2>/dev/null && sudo systemctl disable systemd-timesyncd 2>/dev/null

# Инсталиране на chrony
echo "📦 Инсталиране на chrony..."
if ! sudo apt-get install -y chrony; then
  echo "❌ Неуспешна инсталация на chrony."
  RESULT_NTP_SYNC="❌"
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
RESULT_NTP_SYNC="✅"
echo ""
echo ""

echo "[13] НАСТРОЙКА НА HOSTNAME..."
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

echo "[14] НАСТРОЙКА НА SSH КОНФИГУРАЦИЯ..."
echo "-------------------------------------------------------------------------"
RESULT_SSH_CONFIG="❔"

# Резервно копие на оригиналния файл
if [[ -f /etc/ssh/sshd_config ]]; then
  sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
fi

# Премахване на стари записи и добавяне на новите настройки
sudo sed -i "/^#*Port /d" /etc/ssh/sshd_config
sudo sed -i "/^#*PermitRootLogin /d" /etc/ssh/sshd_config
sudo sed -i "/^#*PasswordAuthentication /d" /etc/ssh/sshd_config

echo "" | sudo tee -a /etc/ssh/sshd_config >/dev/null
echo "Port $SSH_PORT" | sudo tee -a /etc/ssh/sshd_config >/dev/null
echo "PermitRootLogin no" | sudo tee -a /etc/ssh/sshd_config >/dev/null
echo "PasswordAuthentication yes" | sudo tee -a /etc/ssh/sshd_config >/dev/null

# Проверка за синтактични грешки (опционално)
if ! sudo sshd -t; then
  echo "❌ Грешка в конфигурационния файл на SSH. Възстановяване на резервното копие..."
  sudo cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
  RESULT_SSH_CONFIG="❌"
  exit 1
fi

# Рестартиране на SSH
echo "🔄 Рестартиране на SSH услугата..."
if sudo systemctl restart ssh; then
  echo "✅ SSH конфигурацията е обновена и услугата е рестартирана успешно."
  RESULT_SSH_CONFIG="✅"
else
  echo "❌ Неуспешно рестартиране на SSH. Проверете конфигурацията."
  RESULT_SSH_CONFIG="❌"
  exit 1
fi

echo ""
echo ""

# --- [15] КОНФИГУРАЦИЯ НА UFW И РЕСТАРТ НА СЪРВЪРА -----------------------------
echo "[15] КОНФИГУРАЦИЯ НА UFW И РЕСТАРТ НА СЪРВЪРА..."
echo "-------------------------------------------------------------------------"
RESULT_UFW_CONFIG="❔"

# Добавяне на доверени мрежи (ако има въведени)
if [[ ${#TRUSTED_NETS[@]} -gt 0 ]]; then
  echo ""
  echo "🌐 Добавяне на доверени мрежи в защитната стена:"
  for net in "${TRUSTED_NETS[@]}"; do
    echo "🔐 Разрешаване на достъп от $net към всички портове..."
    sudo ufw allow from "$net"
  done
fi

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
if ! sudo ufw status | grep -q "$SSH_PORT"; then
  sudo ufw allow "$SSH_PORT"
fi

# Активиране на UFW
if sudo ufw --force enable; then
  echo "✅ UFW е активиран и конфигуриран."
  RESULT_UFW_CONFIG="✅"
else
  echo "❌ Неуспешно активиране на UFW."
  RESULT_UFW_CONFIG="❌"
  exit 1
fi

# Рестартиране на SSH след промяна на порта (ако е необходимо)
echo "🔄 Рестартиране на SSH услугата..."
if sudo systemctl restart ssh; then
  echo "✅ SSH услугата е рестартирана успешно."
else
  echo "❌ Неуспешно рестартиране на SSH. Проверете конфигурацията."
  RESULT_UFW_CONFIG="❌"
  exit 1
fi

# Отразяване на резултата за доверени мрежи
if [[ ${#TRUSTED_NETS[@]} -gt 0 ]]; then
  RESULT_TRUSTED_NETS="✅"
else
  RESULT_TRUSTED_NETS="🔒 няма"
fi
echo ""
echo ""

echo "[16] ФИНАЛНА ПРОВЕРКА И ОБОБЩЕНИЕ НА КОНФИГУРАЦИЯТА"
echo "-------------------------------------------------------------------------"

# Проверка на sshd_config
SSHD_CONFIG_FILE="/etc/ssh/sshd_config"
RESULT_SSH_PORT="❔"
RESULT_SSH_PASSWORD_AUTH="❔"
RESULT_SSH_ROOT_LOGIN="❔"

EXPECTED_PORT="$SSH_PORT"
EXPECTED_PERMIT_ROOT="no"
EXPECTED_PASS_AUTH="yes"

ACTUAL_PORT=$(grep -Ei '^Port ' "$SSHD_CONFIG_FILE" | awk '{print $2}')
ACTUAL_PERMIT_ROOT=$(grep -Ei '^PermitRootLogin ' "$SSHD_CONFIG_FILE" | awk '{print $2}')
ACTUAL_PASS_AUTH=$(grep -Ei '^PasswordAuthentication ' "$SSHD_CONFIG_FILE" | awk '{print $2}')

# Сравнения
[[ "$ACTUAL_PORT" == "$EXPECTED_PORT" ]] && RESULT_SSH_PORT="✅" || RESULT_SSH_PORT="❌"
[[ "$ACTUAL_PASS_AUTH" == "$EXPECTED_PASS_AUTH" ]] && RESULT_SSH_PASSWORD_AUTH="✅" || RESULT_SSH_PASSWORD_AUTH="❌"
[[ "$ACTUAL_PERMIT_ROOT" == "$EXPECTED_PERMIT_ROOT" ]] && RESULT_SSH_ROOT_LOGIN="✅" || RESULT_SSH_ROOT_LOGIN="❌"

# Обобщение
printf "📌 Системно обновяване:             %s\n" "${RESULT_SYSTEM_UPDATE:-❔}"
printf "📌 Основни инструменти:             %s\n" "${RESULT_BASE_TOOLS:-❔}"
printf "📌 Админ. потребител:               %s\n" "${RESULT_ADMIN_USER:-❔}"
printf "📌 Локализации:                     %s\n" "${RESULT_LOCALES:-❔}"
printf "📌 Часова зона:                     %s\n" "${RESULT_TIMEZONE:-❔}"
printf "📌 Времева синхронизация:           %s\n" "${RESULT_NTP_SYNC:-❔}"
printf "📌 Hostname:                        %s\n" "${RESULT_HOSTNAME:-❔}"
printf "📌 UFW конфигурация:                %s\n" "${RESULT_UFW_CONFIG:-❔}"
printf "📌 Частни мрежи (Trusted):          %s\n" "${RESULT_TRUSTED_NETS:-❔}"
printf "📌 SSH порт:                         %s\n" "${RESULT_SSH_PORT:-❔}"
printf "📌 Влизане с парола:                %s\n" "${RESULT_SSH_PASSWORD_AUTH:-❔}"
printf "📌 Влизане като Root:               %s\n" "${RESULT_SSH_ROOT_LOGIN:-❔}"

echo ""
echo "ℹ️  Легенда: ✅ успешно | ❌ неуспешно | ⚠️ частично | ❔ неизвестно"
echo ""

# Потвърждение за рестарт
echo ""
echo -e "\e[33mВНИМАНИЕ: Следващото действие ще рестартира сървъра!"
echo "─────────────────────────────────────────────────────────────────────────"
echo -e "\e[0m"

while true; do
  printf "👉 Въведете (R) за РЕСТАРТ или (Q) за изход без рестарт: "
  read choice
  case "$choice" in
    [Rr]*)
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
