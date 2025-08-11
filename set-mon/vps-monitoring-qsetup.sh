#!/usr/bin/env bash

# ==========================================================================
#  vps-monitoring-qsetup — Инсталиране на мониторинг стек за MonHub
# --------------------------------------------------------------------------
#  Версия: 0.1-test
#  Дата: 2025-08-10
#  Автор: NetGalaxySoft
# ==========================================================================
#
#  Този скрипт разполага мониторинг стек (Prometheus, Grafana, Alertmanager,
#  Loki, Promtail, node_exporter, blackbox_exporter) върху MonHub.
#  Изпълнява се директно на сървъра (MonHub), без SSH към други машини.
#
#  Етапи:
#    1. Подготовка на средата и директориите
#    2. Създаване на конфигурационни файлове
#    3. Разполагане на Docker Compose стека
#    4. Политика за достъп (UI само през SSH тунел; data само по VPN)
#    5. Проверки за работоспособност
# ==========================================================================

set -euo pipefail
set -o errtrace
trap 'echo "❌ Грешка на ред $LINENO: ${BASH_COMMAND} (код $?)" >&2' ERR

# === ПОМОЩНА ИНФОРМАЦИЯ ===================================================
show_help() {
  echo "Използване: vps-monitoring-qsetup.sh [опция]"
  echo ""
  echo "Разполага мониторинг стек за MonHub (Prometheus, Grafana, Alertmanager,"
  echo "Loki, Promtail, node_exporter, blackbox_exporter) с настройки по стандартите на NetGalaxySoft."
  echo ""
  echo "Опции:"
  echo "  --version       Показва версията на скрипта"
  echo "  --help          Показва тази помощ"
}

# === ОБРАБОТКА НА ОПЦИИ ====================================================
if [[ $# -gt 0 ]]; then
  case "$1" in
    --version)
      echo "vps-monitoring-qsetup версия 0.1-test (10 август 2025 г.)"
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

# Изчистване на терминала за по-ясен старт
command -v clear >/dev/null && clear || printf "\033c"

# Зелен банер за заглавие
echo -e "\033[92m====================================================================="
echo    "vps-monhub-qsetup.sh — Централен сървър за наблюдение и логове"
echo    "Версия: 1.0 (Ubuntu 24.04 amd64)"
echo    "Лиценз: NetGalaxySoft internal"
echo -e "=====================================================================\033[0m"
echo ""
echo ""

SETUP_DIR="/etc/netgalaxy"
SETUP_ENV_FILE="$SETUP_DIR/setup.env"
MODULES_FILE="$SETUP_DIR/todo.modules"

COMPOSE_DIR="/opt/netgalaxy/monhub"
PROM_DIR="$COMPOSE_DIR/prometheus"
ALERT_DIR="$COMPOSE_DIR/alertmanager"
LOKI_DIR="$COMPOSE_DIR/loki"
GRAFANA_DIR="$COMPOSE_DIR/grafana"

# --- Минимални съобщения (стабилен shim) ---
log()  { echo -e "$*"; }
ok()   { echo -e "✅ $*"; }
warn() { echo -e "⚠️  $*"; }
err()  { echo -e "❌ $*" >&2; }


# =====================================================================
# [МОДУЛ 1] ПРЕДВАРИТЕЛНИ ПРОВЕРКИ И ИНИЦИАЛИЗАЦИЯ
# =====================================================================
log "[1] ПРЕДВАРИТЕЛНИ ПРОВЕРКИ НА СИСТЕМА..."
log "-----------------------------------------------------------"
log ""

# ✅ Проверка за root права
if [[ $EUID -ne 0 ]]; then
  echo "❌ Трябва да стартирате скрипта с root права (sudo)."
  exit 1
fi

# ✅ Проверка за базова конфигурация
if [[ ! -f "$SETUP_ENV_FILE" ]] || ! sudo grep -q '^SETUP_VPS_BASE_STATUS=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "🛑 Сървърът е с нестандартна начална конфигурация. Моля, стартирайте файла vps-base-qsetup.sh и опитайте отново."
  echo "🗑️ Премахване на скрипта."
  [[ -f "$0" ]] && rm -- "$0"
  exit 1
fi

# ✅ Проверка дали скриптът вече е изпълнен успешно
if [[ -f "$SETUP_ENV_FILE" ]] && sudo grep -q '^SETUP_VPS_MONITORING_STATUS=✅' "$SETUP_ENV_FILE"; then
  echo "🛑 Този скрипт вече е бил изпълнен успешно на този сървър."
  echo "Повторно изпълнение не е позволено, за да се избегне повреда на системата."
  [[ -f "$0" ]] && sudo rm -- "$0"
  exit 0
fi

# ✅ Проверка на операционната система
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

# ✅ Проверка дали модулът вече е изпълнен
if sudo grep -q '^MON_RESULT_MODULE1=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 1 вече е изпълнен успешно. Пропускане..."
else
  # ✅ Потвърждение на IP адрес
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
      echo ""
      break
    fi
  done

  # ✅ Временно премахване на забраната за промяна/изтриване
  if [[ -d "$NETGALAXY_DIR" ]]; then
    # 0) Сваляме immutable флага и за директорията
    sudo chattr -i "$NETGALAXY_DIR" 2>/dev/null || true

    # 1) Първо сваляме immutable флага (ако е зададен)
    [[ -f "$SETUP_ENV_FILE"      ]] && sudo chattr -i "$SETUP_ENV_FILE"       2>/dev/null || true
    [[ -f "$MODULES_FILE"        ]] && sudo chattr -i "$MODULES_FILE"         2>/dev/null || true
    [[ -f "$NETGALAXY_DIR/.nodelete" ]] && sudo chattr -i "$NETGALAXY_DIR/.nodelete" 2>/dev/null || true

    # 2) После коригираме собственост и права поотделно (само ако съществуват)
    sudo chown root:root "$NETGALAXY_DIR" 2>/dev/null || true
    sudo chmod 755 "$NETGALAXY_DIR"       2>/dev/null || true

    [[ -f "$SETUP_ENV_FILE"      ]] && { sudo chown root:root "$SETUP_ENV_FILE"      2>/dev/null || true; sudo chmod 644 "$SETUP_ENV_FILE"      2>/dev/null || true; }
    [[ -f "$MODULES_FILE"        ]] && { sudo chown root:root "$MODULES_FILE"        2>/dev/null || true; sudo chmod 644 "$MODULES_FILE"        2>/dev/null || true; }
    [[ -f "$NETGALAXY_DIR/.nodelete" ]] && { sudo chown root:root "$NETGALAXY_DIR/.nodelete" 2>/dev/null || true; sudo chmod 644 "$NETGALAXY_DIR/.nodelete" 2>/dev/null || true; }
  fi

  # ✅ Запис или обновяване на SERVER_IP в todo.modules
  if sudo grep -q '^SERVER_IP=' "$MODULES_FILE" 2>/dev/null; then
    sudo sed -i "s|^SERVER_IP=.*|SERVER_IP=\"$SERVER_IP\"|" "$MODULES_FILE"
  else
    echo "SERVER_IP=\"$SERVER_IP\"" | sudo tee -a "$MODULES_FILE" > /dev/null
  fi

echo ""

  # ✅ Запис на резултат за Модул 1
  if sudo grep -q '^MON_RESULT_MODULE1=' "$SETUP_ENV_FILE" 2>/dev/null; then
    if sudo sed -i 's|^MON_RESULT_MODULE1=.*|MON_RESULT_MODULE1=✅|' "$SETUP_ENV_FILE"; then
        echo "MON_RESULT_MODULE1=✅"
    fi
  else
    echo "MON_RESULT_MODULE1=✅" | sudo tee -a "$SETUP_ENV_FILE"
  fi

fi
echo ""
echo ""


# ===================================================================
# [МОДУЛ 2] ИНИЦИАЛИЗАЦИЯ И ВАЛИДАЦИИ (FQDN/IP, системни директории)
# ===================================================================
log "[2] ИНИЦИАЛИЗАЦИЯ И ВАЛИДАЦИИ (FQDN/IP, системни директории)"
log "-------------------------------------------------------------------------"
log ""

# Проверка дали модулът вече е изпълнен
if sudo grep -q '^MON_RESULT_MODULE2=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 2 вече е изпълнен успешно. Пропускане..."
  echo ""
else
  # --- 2.1 FQDN: автоматично извличане (с възможност за override през DOMAIN_EXPECTED) -----
  FQDN_CANDIDATE=""
  if [[ -n "${DOMAIN_EXPECTED:-}" ]]; then
    FQDN_CANDIDATE="$DOMAIN_EXPECTED"
    echo "ℹ️ DOMAIN_EXPECTED е подаден: $FQDN_CANDIDATE"
  else
    # Опит 1: hostname --fqdn; Опит 2: hostname -f; Опит 3: hostname
    FQDN_CANDIDATE="$(hostname --fqdn 2>/dev/null || hostname -f 2>/dev/null || hostname 2>/dev/null || true)"
    FQDN_CANDIDATE="$(printf '%s' "$FQDN_CANDIDATE" | tr -d '[:space:]')"
  fi

  FQDN_REGEX='^([a-zA-Z0-9][-a-zA-Z0-9]*\.)+[a-zA-Z]{2,}$'
  if [[ -n "$FQDN_CANDIDATE" && "$FQDN_CANDIDATE" =~ $FQDN_REGEX ]]; then
    FQDN="$FQDN_CANDIDATE"
    echo "✅ Засечен FQDN: $FQDN"
  else
    echo "⚠️  Неуспешно извличане на валиден FQDN от системата."
    FQDN=""
  fi

  # --- 2.2 IP валидирации (информативни, без интеракция) -----------------------------------
  ACTUAL_IP="$(curl -s -4 ifconfig.me || true)"
  [[ -n "$ACTUAL_IP" ]] && echo "ℹ️  Засечен публичен IP адрес: $ACTUAL_IP"

  if [[ -n "$FQDN" ]]; then
    FQDN_IPS="$(dig +short "$FQDN" A 2>/dev/null | tr '\n' ' ' | sed 's/ *$//')"
    if [[ -n "$FQDN_IPS" ]]; then
      echo "ℹ️  DNS A записи за $FQDN: $FQDN_IPS"
      if [[ -n "$ACTUAL_IP" ]] && grep -qw "$ACTUAL_IP" <<< "$FQDN_IPS"; then
        echo "✅ $FQDN резолвира към публичния IP на машината."
      else
        echo "⚠️  Несъответствие или липса на публичен IP ↔ DNS A записите."
      fi
    else
      echo "⚠️  $FQDN не резолвира към A запис в момента."
    fi
  fi

  # --- 2.3 Подготовка на системни директории за мониторинга -----------------
COMPOSE_DIR="/opt/netgalaxy/monhub"
PROM_DIR="$COMPOSE_DIR/prometheus"
ALERT_DIR="$COMPOSE_DIR/alertmanager"
LOKI_DIR="$COMPOSE_DIR/loki"
GRAFANA_DIR="$COMPOSE_DIR/grafana"
LOG_DIR="/var/log/netgalaxy"

echo "📁 Създавам директории..."
sudo mkdir -p "$COMPOSE_DIR" || exit 1
sudo mkdir -p "$PROM_DIR" || exit 1
sudo mkdir -p "$ALERT_DIR" || exit 1
sudo mkdir -p "$LOKI_DIR" || exit 1
sudo mkdir -p "$GRAFANA_DIR" || exit 1
sudo mkdir -p "$LOG_DIR" || exit 1
echo "✅ Директориите са създадени."

echo "🔧 Настройвам права/собственост..."
sudo chown -R root:root "$COMPOSE_DIR" "$LOG_DIR"
sudo chmod 755 "$COMPOSE_DIR" "$LOG_DIR"
sudo find "$COMPOSE_DIR" -type d -exec chmod 755 {} \;
echo "✅ Права/собственост са настроени."

  # ✅ Запис или обновяване на FQDN в todo.modules (ако имаме валиден FQDN)
  if [[ -n "$FQDN" ]]; then
    if sudo grep -q '^FQDN=' "$MODULES_FILE" 2>/dev/null; then
      sudo sed -i "s|^FQDN=.*|FQDN=\"$FQDN\"|" "$MODULES_FILE"
    else
      echo "FQDN=\"$FQDN\"" | sudo tee -a "$MODULES_FILE" > /dev/null
    fi
  else
    echo "⚠️  Пропускам запис на FQDN в $MODULES_FILE (липсва валиден FQDN)."
  fi

echo ""

  # ✅ Записване на резултат от модула (коректният ключ за мониторинг)
  if sudo grep -q '^MON_RESULT_MODULE2=' "$SETUP_ENV_FILE" 2>/dev/null; then
    sudo sed -i 's|^MON_RESULT_MODULE2=.*|MON_RESULT_MODULE2=✅|' "$SETUP_ENV_FILE"
    echo "MON_RESULT_MODULE2=✅"
  else
    echo "MON_RESULT_MODULE2=✅" | sudo tee -a "$SETUP_ENV_FILE"
  fi
fi
echo ""
echo ""

exit 0
# =====================================================================
# [МОДУЛ 3] Системни ъпдейти, SSH твърдяване, UFW
# =====================================================================
log "[3] СИСТЕМНИ НАСТРОЙКИ: ъпдейти, SSH, UFW..."
log "=============================================="
log ""

# Проверка дали модулът вече е изпълнен
if sudo grep -q '^MON_RESULT_MODULE3=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 3 вече е изпълнен успешно. Пропускане..."
  echo ""
else
  # Ъпдейти
  sudo apt-get update -y
  sudo DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y

  # Минимални инструменти
  sudo apt-get install -y curl wget gnupg2 ca-certificates jq unzip software-properties-common ufw

  # SSH твърдяване (без да пречим на текущата сесия)
  SSHD="/etc/ssh/sshd_config"
  sudo cp -a "$SSHD" "${SSHD}.bak.$(date +%F-%H%M%S)"
  sudo sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' "$SSHD"
  sudo sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/' "$SSHD"
  sudo sed -i 's/^#\?X11Forwarding .*/X11Forwarding no/' "$SSHD"
  sudo systemctl reload ssh || sudo systemctl restart ssh

  # UFW — позволяваме само нужното
  sudo ufw --force reset
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw allow OpenSSH
  sudo ufw allow 3000/tcp    # Grafana
  sudo ufw allow 9090/tcp    # Prometheus
  sudo ufw allow 9093/tcp    # Alertmanager
  sudo ufw allow 3100/tcp    # Loki
  sudo ufw allow 9100/tcp    # node_exporter
  sudo ufw allow 9115/tcp    # blackbox_exporter
  sudo ufw --force enable

  # ✅ Запис на резултат само при успешен запис + показване в терминала
  if sudo grep -q '^MON_RESULT_MODULE3=' "$SETUP_ENV_FILE" 2>/dev/null; then
    if sudo sed -i 's|^MON_RESULT_MODULE3=.*|MON_RESULT_MODULE3=✅|' "$SETUP_ENV_FILE"; then
      echo "MON_RESULT_MODULE3=✅"
    fi
  else
    echo "MON_RESULT_MODULE3=✅" | sudo tee -a "$SETUP_ENV_FILE"
  fi

fi
echo ""
echo ""


# ======================================================
# [МОДУЛ 4] Инсталация на Docker Engine + Compose (LTS)
# ======================================================
log "[4] DOCKER ENGINE + COMPOSE..."
log "==================================================="
log ""

# --- Задължителна начална проверка за вече изпълнен модул -----------------
if sudo grep -q '^MON_RESULT_MODULE4=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 4 вече е изпълнен успешно. Пропускане..."
  echo ""
else
  MODULE_MARK="M4.docker"
  RESULT_KEY="MON_RESULT_MODULE4"

  # Официално хранилище на Docker
  sudo apt-get update -y
  sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

  # Ключодържател за Docker (идемпотентно)
  sudo install -m 0755 -d /etc/apt/keyrings
  if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod 0644 /etc/apt/keyrings/docker.gpg
  fi

  # Репо файл (идемпотентно)
  UBUNTU_CODENAME="$(. /etc/os-release && echo "$UBUNTU_CODENAME")"
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # Разрешаваме и стартираме Docker service
  sudo systemctl enable --now docker

  # ✅ Запис на резултат за Модул 4 + показване САМО при успешен запис
  if sudo grep -q "^${RESULT_KEY}=" "$SETUP_ENV_FILE" 2>/dev/null; then
    if sudo sed -i "s|^${RESULT_KEY}=.*|${RESULT_KEY}=✅|" "$SETUP_ENV_FILE"; then
      echo "${RESULT_KEY}=✅"
    fi
  else
    echo "${RESULT_KEY}=✅" | sudo tee -a "$SETUP_ENV_FILE"
  fi

fi
echo ""
echo ""


# ================================================================
# [МОДУЛ 5] Постинсталационна конфигурация и валидация на Docker
# ================================================================
log "[5] DOCKER POST-INSTALL CONFIG & VALIDATION..."
log "=============================================================="
log ""

# --- Задължителна начална проверка за вече изпълнен модул -----------------
if sudo grep -q '^MON_RESULT_MODULE5=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 5 вече е изпълнен успешно. Пропускане..."
  echo ""
else
  MODULE_MARK="M5.docker_post"
  RESULT_KEY="MON_RESULT_MODULE5"

  # -------------------------------
  # 1) Идемпотентна daemon конфигурация
  # -------------------------------
  sudo install -d -m 0755 /etc/docker

  TMP_DAEMON="/tmp/daemon.json.$$.tmp"
  FINAL_DAEMON="/etc/docker/daemon.json"

  cat > "$TMP_DAEMON" <<'JSON'
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "features": { "buildkit": true },
  "live-restore": true,
  "log-driver": "local",
  "iptables": true
}
JSON

  DAEMON_CHANGED=0
  if [[ -f "$FINAL_DAEMON" ]]; then
    if ! sudo diff -q "$TMP_DAEMON" "$FINAL_DAEMON" >/dev/null 2>&1; then
      DAEMON_CHANGED=1
    fi
  else
    DAEMON_CHANGED=1
  fi

  if [[ "$DAEMON_CHANGED" -eq 1 ]]; then
    # (опит за валидация, ако е налична)
    if command -v dockerd >/dev/null 2>&1; then
      if sudo dockerd --validate --config "$TMP_DAEMON" >/dev/null 2>&1; then
        echo "✅ Конфигурацията мина валидация (dockerd --validate)."
      else
        echo "⚠️ Валидацията с dockerd неуспешна. Прекратяване за безопасност."
        exit 1
      fi
    fi

    sudo mv "$TMP_DAEMON" "$FINAL_DAEMON"
    sudo chmod 0644 "$FINAL_DAEMON"
    echo "▶ Обновен /etc/docker/daemon.json"
    sudo systemctl daemon-reload
    sudo systemctl restart docker
  else
    rm -f "$TMP_DAEMON"
    echo "ℹ️ /etc/docker/daemon.json без промяна."
  fi

  # --------------------------------
  # 2) (По избор) Добавяне на оператор в група docker
  #    Задайте DOCKER_OPERATOR=<username> в /etc/netgalaxy/todo.modules
  # --------------------------------
  TODO_FILE="/etc/netgalaxy/todo.modules"
  if [[ -f "$TODO_FILE" ]]; then
    DOCKER_OPERATOR="$(grep -E '^DOCKER_OPERATOR=' "$TODO_FILE" 2>/dev/null | cut -d'=' -f2)"
    if [[ -n "$DOCKER_OPERATOR" ]]; then
      if id "$DOCKER_OPERATOR" >/dev/null 2>&1; then
        if ! id -nG "$DOCKER_OPERATOR" | grep -qw docker; then
          sudo usermod -aG docker "$DOCKER_OPERATOR"
          echo "▶ Добавен $DOCKER_OPERATOR в група docker (изисква re-login)."
        else
          echo "ℹ️ $DOCKER_OPERATOR вече е в група docker."
        fi
      else
        echo "⚠️ Потребителят $DOCKER_OPERATOR не съществува – пропускане."
      fi
    else
      echo "ℹ️ Няма зададен DOCKER_OPERATOR – пропускане на групово добавяне."
    fi
  else
    echo "ℹ️ Няма $TODO_FILE – пропускане на групово добавяне."
  fi

  # --------------------------------
  # 3) Sanity checks и тестове
  # --------------------------------
  echo "▶ Проверки на Docker..."
  if ! sudo systemctl is-active --quiet docker; then
    echo "❌ Услугата docker не е активна."
    exit 1
  fi

  docker --version || { echo "❌ Няма docker бинарник в PATH."; exit 1; }
  docker compose version || { echo "❌ Няма docker compose plugin."; exit 1; }

  # Проверка на cgroup драйвера = systemd
  CGDRV="$(docker info --format '{{.CgroupDriver}}' 2>/dev/null || true)"
  if [[ "$CGDRV" != "systemd" ]]; then
    echo "⚠️ Очакван cgroupdriver=systemd, засечен: $CGDRV"
  else
    echo "✅ CgroupDriver: systemd"
  fi

  # Тестов контейнер (stateless)
  if docker run --rm hello-world >/dev/null 2>&1; then
    echo "✅ hello-world контейнерът стартира успешно."
  else
    echo "❌ Неуспешен тест с hello-world."
    exit 1
  fi

  # ✅ Запис на резултат за Модул 5 + показване САМО при успешен запис
  if sudo grep -q "^${RESULT_KEY}=" "$SETUP_ENV_FILE" 2>/dev/null; then
    if sudo sed -i "s|^${RESULT_KEY}=.*|${RESULT_KEY}=✅|" "$SETUP_ENV_FILE"; then
      echo "${RESULT_KEY}=✅"
    fi
  else
    echo "${RESULT_KEY}=✅" | sudo tee -a "$SETUP_ENV_FILE" >/dev/null
    echo "${RESULT_KEY}=✅"
  fi

fi
echo ""
echo ""






exit 0




# =====================================================================
# [МОДУЛ 5] Стартиране на стека
# =====================================================================
log ""
log "=============================================="
log "[5] СТАРТИРАНЕ НА STACK-A..."
log "=============================================="
log ""

if ! already_done "M5.up"; then
  pushd "$COMPOSE_DIR" >/dev/null
  sudo docker compose up -d
  popd >/dev/null

  stamp "M5.up"
  mark_success "MONHUB_MODULE5"
  ok "Модул 5 завърши. Стекът е стартиран."
else
  warn "Модул 5 вече е изпълнен. Пропускане."
fi

# =====================================================================
# [МОДУЛ 6] Обобщение
# =====================================================================
log ""
log "=============================================="
log "[6] ОБОБЩЕНИЕ"
log "=============================================="
log ""

GRAFANA_URL="http://$(hostname -I | awk '{print $1}'):3000"
PROM_URL="http://$(hostname -I | awk '{print $1}'):9090"

printf "\n"
printf "Мониторинг стек: \n"
printf "  • Grafana:        %s (admin / admin)\n" "$GRAFANA_URL"
printf "  • Prometheus:     %s\n" "$PROM_URL"
printf "  • Alertmanager:   http://<IP>:9093\n"
printf "  • Loki API:       http://<IP>:3100\n"
printf "  • node_exporter:  http://<IP>:9100/metrics\n"
printf "  • blackbox:       http://<IP>:9115/probe?target=https://example.org\n"
printf "\nЛог директория: %s\n" "$LOG_DIR"
printf "Compose папка:  %s\n" "$COMPOSE_DIR"
printf "\nUFW: отворени портове 22, 3000, 9090, 9093, 3100, 9100, 9115\n"

mark_success "MONHUB_MODULE6"
ok "Готово."
