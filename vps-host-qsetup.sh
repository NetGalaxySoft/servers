#!/bin/bash

# ========================================================================== 
#  vps-host-qsetup - Надстройка за хостинг сървър (bind9, apache, mariadb)
# --------------------------------------------------------------------------
#  Версия: 1.0
#  Дата: 2025-06-30
#  Автор: Ilko Yordanov / NetGalaxy
# ==========================================================================
#
#  Този скрипт извършва надграждаща конфигурация на вече подготвен VPS
#  сървър. Той добавя услуги за хостинг и управление на домейни.
#
#  Етапи:
#    1. Събиране на цялата информация
#    2. Потвърждение от оператора
#    3. Инсталация и конфигурация на услугите
#    4. Финален отчет на резултатите
# ==========================================================================

# === ПОМОЩНА ИНФОРМАЦИЯ ===================================================
show_help() {
  echo "Използване: vps-host-qsetup.sh [опция]"
  echo ""
  echo "Надграждаща конфигурация за хостинг сървър (Apache, bind9, MariaDB)."
  echo ""
  echo "Опции:"
  echo "  --version       Показва версията на скрипта"
  echo "  --help          Показва тази помощ"
}

# === ОБРАБОТКА НА ОПЦИИ ====================================================
if [[ $# -gt 0 ]]; then
  case "$1" in
    --version)
      echo "vps-host-qsetup версия 1.0 (30 юни 2025 г.)"
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
echo -e "  НАДСТРОЙКА ЗА ХОСТИНГ СЪРВЪР (VPS)"
echo -e "==========================================\e[0m"
echo ""

# === ГЛОБАЛНИ ПРОМЕНЛИВИ ===================================================
SERVER_IP=""
ACTUAL_IP=$(curl -s ifconfig.me)
SERVER_DOMAIN=""
ACTUAL_DOMAIN=$(hostname -f)
DNS_REQUIRED=""
DNS_MODE="master"
DNS_ZONE=""
SLAVE_MASTER_IP=""
CONFIRM=""

# === [1] СЪБИРАНЕ НА ИНФОРМАЦИЯ И ПРОВЕРКА НА СЪРВЪРА ======================

while true; do
  read -rp "➤ Въведете публичния IP адрес на сървъра (или 'q' за изход): " SERVER_IP
  [[ "$SERVER_IP" == "q" ]] && exit 0
  if [[ $SERVER_IP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    if [[ "$SERVER_IP" != "$ACTUAL_IP" ]]; then
      echo "❌ Въведеният IP адрес ($SERVER_IP) не съвпада с реалния IP адрес на сървъра ($ACTUAL_IP)"
      echo "🛑 Опит за изпълнение на скрипта върху погрешен сървър. Прекратяване."
      exit 1
    fi
    break
  else
    echo "❌ Невалиден IP адрес. Опитайте отново."
  fi
done

while true; do
  read -rp "➤ Въведете пълното домейн име (FQDN) на сървъра (или 'q' за изход): " SERVER_DOMAIN
  [[ "$SERVER_DOMAIN" == "q" ]] && exit 0
  if [[ $SERVER_DOMAIN =~ ^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)+([A-Za-z]{2,})$ ]]; then
    if [[ "$SERVER_DOMAIN" != "$ACTUAL_DOMAIN" ]]; then
      echo "❌ Въведеният FQDN ($SERVER_DOMAIN) не съвпада с текущото име на сървъра ($ACTUAL_DOMAIN)"
      echo "🛑 Опит за изпълнение на скрипта върху погрешен сървър. Прекратяване."
      exit 1
    fi
    break
  else
    echo "❌ Невалиден FQDN. Опитайте отново."
  fi
done

echo "✅ Потвърдено: Скриптът се изпълнява върху правилния сървър."

# === [2] ИСКА ЛИ ОПЕРАТОРЪТ DNS СЪРВЪР =====================================
while true; do
  read -rp "➤ Желаете ли да инсталирате DNS сървър (bind9)? (y/N/q): " DNS_REQUIRED
  case "$DNS_REQUIRED" in
    y|Y)
      DNS_REQUIRED="yes"
      break
      ;;
    n|N|"")
      DNS_REQUIRED="no"
      echo "ℹ️ Пропускане на конфигурация на DNS сървър."
      break
      ;;
    q|Q)
      exit 0
      ;;
    *)
      echo "❌ Невалиден отговор. Моля въведете y, n или q."
      ;;
  esac
done

# === [2a] ВЪПРОС ЗА DNS РЕЖИМ ===================================================
while true; do
  echo "➤ Изберете режим за DNS сървъра:"
  echo "    1: master"
  echo "    2: slave"
  echo "    q: изход"
  read -rp "Вашият избор: " DNS_MODE
  case "$DNS_MODE" in
    1)
      DNS_MODE="master"
      DNS_ZONE=$(echo "$SERVER_DOMAIN" | cut -d. -f2-)
      echo "ℹ️ Използва се основна зона: $DNS_ZONE"
      SLAVE_MASTER_IP=""
      break
      ;;
    2)
      DNS_MODE="slave"
      while true; do
        read -rp "➤ Въведете IP адреса на master DNS сървъра (или 'q' за изход): " SLAVE_MASTER_IP
        [[ "$SLAVE_MASTER_IP" == "q" ]] && exit 0
        if [[ $SLAVE_MASTER_IP == "$SERVER_IP" ]]; then
          echo "❌ IP адресът на master сървъра не може да съвпада с текущия сървър."
          continue
        fi
        if [[ $SLAVE_MASTER_IP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
          echo "ℹ️ Ще се опитаме да проверим достъпа до master сървъра..."
          if timeout 3 bash -c "> /dev/tcp/$SLAVE_MASTER_IP/53" 2>/dev/null; then
            echo "✅ Успешна връзка към порт 53 на master DNS сървъра."
            break
          else
            echo "❌ Няма достъп до порт 53 на $SLAVE_MASTER_IP. Проверете firewall или IP."
          fi
        else
          echo "❌ Невалиден IP адрес. Опитайте отново."
        fi
      done
      break
      ;;
    q|Q)
      exit 0
      ;;
    *)
      echo "❌ Невалиден избор. Моля, въведете 1, 2 или q."
      ;;
  esac
 done

# [3] Финално потвърждение
INSTALLED_SERVICES="Apache2, MariaDB, PHP, Postfix, Dovecot, Roundcube"
echo ""
echo "🔎 Преглед на въведената информация:"
echo "   • Домейн (FQDN):  $SERVER_DOMAIN"
echo "   • IP адрес:       $SERVER_IP"
if [[ "$DNS_REQUIRED" == "yes" ]]; then
  echo "   • DNS сървър:     включен ($DNS_MODE)"
  echo "   • DNS зона:       $DNS_ZONE"
  [[ "$DNS_MODE" == "slave" ]] && echo "   • Master IP:       $SLAVE_MASTER_IP"
else
  echo "   • DNS сървър:     няма да бъде инсталиран"
fi
echo "   • Услуги за инсталиране: $INSTALLED_SERVICES"

while true; do
  read -rp "❓ Потвърждавате ли тази информация? (y/N/q): " CONFIRM
  case "$CONFIRM" in
    y|Y)
      break
      ;;
    n|N|"")
      echo "❌ Прекратено от оператора."
      exit 1
      ;;
    q|Q)
      exit 0
      ;;
    *)
      echo "❌ Невалиден отговор. Моля въведете y, n или q."
      ;;
  esac
done
