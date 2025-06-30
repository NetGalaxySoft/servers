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

# [... предишен код без промяна ...]

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

# Финално потвърждение
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
