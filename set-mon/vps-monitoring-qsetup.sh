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

NETGALAXY_DIR="/etc/netgalaxy"
MODULES_FILE="$NETGALAXY_DIR/todo.modules"
SETUP_ENV_FILE="$NETGALAXY_DIR/setup.env"
MON_ENV_FILE="$NETGALAXY_DIR/monitoring.env"

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

  # ✅ Създаване на празен monitoring.env (ако липсва)
  if [[ ! -f "$MON_ENV_FILE" ]]; then
    sudo touch "$MON_ENV_FILE" \
      || { err "Неуспешно създаване на $MON_ENV_FILE"; exit 1; }
    sudo chown root:root "$MON_ENV_FILE" \
      || { err "Неуспешна смяна на собственост за $MON_ENV_FILE"; exit 1; }
    sudo chmod 0644 "$MON_ENV_FILE" \
      || { err "Неуспешна промяна на права за $MON_ENV_FILE"; exit 1; }
    ok "Създаден празен файл: $MON_ENV_FILE"
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


# =====================================================================
# [МОДУЛ 3] Системни ъпдейти, SSH (без промяна на root/пароли), UFW
# =====================================================================
log "[3] СИСТЕМНИ НАСТРОЙКИ: ъпдейти, SSH, UFW..."
log "=============================================="
log ""

if sudo grep -q '^MON_RESULT_MODULE3=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 3 вече е изпълнен успешно. Пропускане..."
  echo ""
else
  # --- Ъпдейти (noninteractive) ---
  sudo apt-get update -y
  sudo DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y

  # --- Минимални инструменти ---
  sudo apt-get install -y curl wget gnupg2 ca-certificates jq unzip software-properties-common ufw

  # --- Откриване на реалните SSH портове ---
  SSHD="/etc/ssh/sshd_config"
  SSHD_BIN="$(command -v sshd || echo /usr/sbin/sshd)"

  # 1) слушащи портове на sshd (live)
  mapfile -t SSH_PORTS < <(ss -ltnp 2>/dev/null | awk '/sshd/ {split($4,a,":"); print a[length(a)]}' | sort -u)

  # 2) fallback: от конфигурацията (вкл. включени *.conf)
  if [[ ${#SSH_PORTS[@]} -eq 0 ]]; then
    mapfile -t SSH_PORTS < <(
      { awk '/^\s*Port\s+[0-9]+/ {print $2}' "$SSHD" 2>/dev/null; \
        awk '/^\s*Port\s+[0-9]+/ {print $2}' /etc/ssh/sshd_config.d/*.conf 2>/dev/null; } \
      | awk 'NF' | sort -u
    )
  fi

  # 3) финален fallback
  [[ ${#SSH_PORTS[@]} -eq 0 ]] && SSH_PORTS=(22)

  # --- SSH настройка (без да забраняваме root/пароли на този етап) ---
  sudo cp -a "$SSHD" "${SSHD}.bak.$(date +%F-%H%M%S)" 2>/dev/null || true
  sudo sed -i 's/^#\?X1\?1Forwarding .*/X11Forwarding no/' "$SSHD" 2>/dev/null || true

  # Тест и безопасен reload (никога restart)
  if sudo "$SSHD_BIN" -t; then
    sudo systemctl reload ssh || sudo systemctl reload sshd || true
  else
    warn "Невалиден sshd_config. Връщам backup."
    sudo cp -a "${SSHD}.bak."* "$SSHD" 2>/dev/null || true
  fi

  # --- Подготовка на UFW правилата (преглед преди прилагане) ---
  # Списък с портове, които ще бъдат разрешени (TCP)
  ALLOW_PORTS=( "${SSH_PORTS[@]}" 22 3000 9090 9093 3100 9100 9115 )

  # Премахване на дублирани/празни стойности
  declare -A _seen
  UNIQUE_PORTS=()

  for p in "${ALLOW_PORTS[@]}"; do
    [[ -n "$p" ]] || continue
    if [[ -z "${_seen["$p"]+x}" ]]; then
      UNIQUE_PORTS+=("$p")
      _seen["$p"]=1
    fi
  done

  echo ""
  echo "🛡️  Предварителен преглед на UFW правилата:"
  echo "    Политики: incoming=DENY, outgoing=ALLOW"
  echo "    Ще бъдат разрешени следните входящи TCP портове:"
  for p in "${UNIQUE_PORTS[@]}"; do
    echo "      • allow ${p}/tcp"
  done
  echo ""
  
  # --- Потвърждение от оператора преди активиране на UFW ---
  _ans=""
  while true; do
    echo "▶ Прилагане и активиране на UFW? [Enter=ДА/y/yes/д/да]"
    read -r -p "или [n/no/не/q за ОТКАЗ]: " _ans || _ans=""
    _ans_lc="$(printf '%s' "${_ans}" | tr '[:upper:]' '[:lower:]')"

    case "$_ans_lc" in
      ""|"y"|"yes"|"д"|"да")
        # продължаваме
        break
        ;;
      "n"|"no"|"не"|"q")
        warn "Прекратяване на изпълнението преди активиране на UFW."
        echo ""
        exit 0
        ;;
      *)
        echo "❌ Невалиден отговор. Натиснете Enter (ДА) или въведете n/no/не/q (ОТКАЗ)."
        ;;
    esac
  done

  # --- UFW политика и прилагане на правила ---
  sudo ufw --force reset
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  for p in "${UNIQUE_PORTS[@]}"; do
    sudo ufw allow "${p}/tcp"
  done
  sudo ufw --force enable

  # ✅ Запис на резултат
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


# =====================================================================
# [МОДУЛ 5] Мониторинг стек (Prometheus, Alertmanager, Blackbox, Loki, Promtail, Grafana)
# =====================================================================
log "[5] МОНТОРИНГ СТЕК: Prometheus, Alertmanager, Blackbox, Loki, Promtail, Grafana..."
log "===================================================================================="
log ""

# Проверка дали модулът вече е изпълнен
if sudo grep -q '^MON_RESULT_MODULE5=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 5 вече е изпълнен успешно. Пропускане..."
  echo ""
else
# --- 1) Директории, права и .env ---

# Директории (всичко нужно за bind mounts)
sudo mkdir -p \
  "$PROM_DIR/data" \
  "$ALERT_DIR/data" \
  "$LOKI_DIR/data" \
  "$GRAFANA_DIR/data" \
  "$GRAFANA_DIR/provisioning/datasources" \
  "$GRAFANA_DIR/plugins" \
  "$COMPOSE_DIR/blackbox"

# Права (контейнерни UID/GID)
sudo chown -R 65534:65534 "$PROM_DIR/data" "$ALERT_DIR/data"   || { err "chown prom/alert data"; exit 1; }
sudo chown -R 10001:10001 "$LOKI_DIR"                           || { err "chown loki"; exit 1; }
sudo chown -R 472:472   "$GRAFANA_DIR"                          || { err "chown grafana"; exit 1; }

# По-щадящо, но достатъчно
sudo chmod -R u+rwX,g+rwX "$GRAFANA_DIR" "$LOKI_DIR" || { err "chmod grafana/loki"; exit 1; }

# .env за docker compose (пътища и базови креденшъли)
sudo tee "$COMPOSE_DIR/.env" >/dev/null <<EOF
PROM_DIR=$PROM_DIR
ALERT_DIR=$ALERT_DIR
LOKI_DIR=$LOKI_DIR
GRAFANA_DIR=$GRAFANA_DIR

# Временни Grafana креденшъли (ще се сменят в security модул)
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin
EOF

# --- 2) Конфигурации ---

  # Prometheus (targets: локален node_exporter, blackbox, самия prometheus, alertmanager)
  sudo tee "$PROM_DIR/prometheus.yml" >/dev/null <<'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['prometheus:9090']

  - job_name: 'node'
    static_configs:
      - targets: ['node_exporter:9100']

  - job_name: 'blackbox_http'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
          - https://example.org
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox:9115
EOF

  # Alertmanager (минимална конфигурация – без реални маршрути)
  sudo tee "$ALERT_DIR/alertmanager.yml" >/dev/null <<'EOF'
route:
  receiver: 'null'
receivers:
  - name: 'null'
EOF

  # Blackbox Exporter
  sudo tee "$COMPOSE_DIR/blackbox/blackbox.yml" >/dev/null <<'EOF'
modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      valid_http_versions: ["HTTP/1.1", "HTTP/2"]
      preferred_ip_protocol: "ip4"
  icmp:
    prober: icmp
    timeout: 5s
EOF

  # Loki
  sudo tee "$LOKI_DIR/config.yml" >/dev/null <<'EOF'
server:
  http_listen_port: 3100
  grpc_listen_port: 9096

auth_enabled: false

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2024-01-01
      store: boltdb-shipper
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

ruler:
  alertmanager_url: http://alertmanager:9093
EOF

  # Promtail (събира системни логове и ги праща към Loki)
  sudo tee "$LOKI_DIR/promtail-config.yml" >/dev/null <<'EOF'
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*.log
  - job_name: journal
    journal:
      path: /var/log/journal
      max_age: 12h
      labels:
        job: systemd-journal
    relabel_configs:
      - source_labels: ['__journal__systemd_unit']
        target_label: 'unit'
EOF

  # Grafana datasource provisioning (Prometheus + Loki)
  sudo tee "$GRAFANA_DIR/provisioning/datasources/datasource.yml" >/dev/null <<'EOF'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
EOF

  # --- 3) docker-compose.yml ---
  sudo tee "$COMPOSE_DIR/docker-compose.yml" >/dev/null <<'EOF'
services:
  node_exporter:
    image: prom/node-exporter:v1.8.2
    container_name: monhub_node_exporter
    command:
      - '--path.rootfs=/rootfs'
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    ports:
      - "9100:9100"
    restart: unless-stopped
    networks: [monhub]

  prometheus:
    image: prom/prometheus:latest
    container_name: monhub_prometheus
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.retention.time=15d
    volumes:
      - ${PROM_DIR}/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ${PROM_DIR}/data:/prometheus
      - ${PROM_DIR}/targets:/etc/prometheus/targets:ro
      - ${PROM_DIR}/rules:/etc/prometheus/rules:ro
    ports:
      - "9090:9090"
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:9090/-/ready"]
      interval: 15s
      timeout: 5s
      retries: 20
    restart: unless-stopped
    networks: [monhub]

  alertmanager:
    image: prom/alertmanager:latest
    container_name: monhub_alertmanager
    volumes:
      - ${ALERT_DIR}/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
      - ${ALERT_DIR}/data:/alertmanager
    ports:
      - "9093:9093"
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:9093/-/ready"]
      interval: 15s
      timeout: 5s
      retries: 20
    restart: unless-stopped
    networks: [monhub]

  blackbox:
    image: prom/blackbox-exporter:latest
    container_name: monhub_blackbox
    volumes:
      - ./blackbox/blackbox.yml:/etc/blackbox_exporter/config.yml:ro
    ports:
      - "9115:9115"
    restart: unless-stopped
    networks: [monhub]

  loki:
    image: grafana/loki:2.9.8
    container_name: monhub_loki
    command: -config.file=/etc/loki/config.yml
    volumes:
      - ${LOKI_DIR}/config.yml:/etc/loki/config.yml:ro
      - ${LOKI_DIR}/data:/loki
    ports:
      - "3100:3100"
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3100/ready"]
      interval: 15s
      timeout: 5s
      retries: 20
    restart: unless-stopped
    networks: [monhub]

  promtail:
    image: grafana/promtail:2.9.8
    container_name: monhub_promtail
    command: -config.file=/etc/promtail/config.yml
    volumes:
      - /var/log:/var/log:ro
      - /var/log/journal:/var/log/journal:ro
      - /run/log/journal:/run/log/journal:ro
      - /etc/machine-id:/etc/machine-id:ro
      - ${LOKI_DIR}/promtail-config.yml:/etc/promtail/config.yml:ro
    restart: unless-stopped
    networks: [monhub]

  grafana:
    image: grafana/grafana:10.4.6
    container_name: monhub_grafana
    environment:
      - GF_SECURITY_ADMIN_USER=${GRAFANA_ADMIN_USER}
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
    volumes:
      - ${GRAFANA_DIR}/data:/var/lib/grafana
      - ${GRAFANA_DIR}/provisioning:/etc/grafana/provisioning
    ports:
      - "3000:3000"
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3000/api/health"]
      interval: 15s
      timeout: 5s
      retries: 20
    depends_on:
      - prometheus
      - loki
    restart: unless-stopped
    networks: [monhub]

networks:
  monhub:
    driver: bridge
EOF

# --- 3.5) Предстартови валидации (fixed) ---

# Prometheus: promtool check config
sudo docker run --rm \
  -v "$PROM_DIR:/etc/prometheus:ro" \
  --entrypoint /bin/promtool \
  prom/prometheus:latest \
  check config /etc/prometheus/prometheus.yml \
  || { err "Prometheus конфигурацията е невалидна."; exit 1; }

# Alertmanager: amtool check-config
sudo docker run --rm \
  -v "$ALERT_DIR:/etc/alertmanager:ro" \
  --entrypoint /bin/amtool \
  prom/alertmanager:latest \
  check-config /etc/alertmanager/alertmanager.yml \
  || { err "Alertmanager конфигурацията е невалидна."; exit 1; }

# Loki: верификация на конфигурацията
sudo docker run --rm \
  -v "$LOKI_DIR/config.yml:/etc/loki/config.yml:ro" \
  -v "$LOKI_DIR/data:/loki" \
  --user 10001:10001 \
  grafana/loki:2.9.8 \
  -config.file=/etc/loki/config.yml -verify-config \
  || { err "Loki конфигурацията е невалидна."; exit 1; }

ok "Конфигурациите са валидни. Стартирам стека..."

  # --- 4) Старт на стека ---
  (cd "$COMPOSE_DIR" && sudo docker compose pull && sudo docker compose up -d)

  # --- 5) systemd unit за автостарт ---
  sudo tee /etc/systemd/system/monhub.service >/dev/null <<EOF
[Unit]
Description=NetGalaxy MonHub Stack (Prometheus/Alertmanager/Loki/Grafana)
Wants=docker.service
After=docker.service

[Service]
Type=oneshot
WorkingDirectory=$COMPOSE_DIR
RemainAfterExit=true
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable --now monhub.service

  # ✅ Публикуване на портове за Модул 10
  upsert_kv(){ local k="$1" v="$2"; if sudo grep -q "^${k}=" "$MODULES_FILE" 2>/dev/null; then
  sudo sed -i "s|^${k}=.*|${k}=${v}|" "$MODULES_FILE"; else echo "${k}=${v}" | sudo tee -a "$MODULES_FILE" >/dev/null; fi; }
  upsert_kv GRAFANA_PORT 3000
  upsert_kv PROMETHEUS_PORT 9090
  upsert_kv LOKI_PORT 3100
  upsert_kv ALERTMANAGER_PORT 9093
  upsert_kv NODE_EXPORTER_PORT 9100
  # BLACKBOX_EXPORTER_PORT се задава в Модул 7 (9115)


  # --- 6) Маркиране на резултат ---
  if sudo grep -q '^MON_RESULT_MODULE5=' "$SETUP_ENV_FILE" 2>/dev/null; then
    if sudo sed -i 's|^MON_RESULT_MODULE5=.*|MON_RESULT_MODULE5=✅|' "$SETUP_ENV_FILE"; then
      echo "MON_RESULT_MODULE5=✅"
    fi
  else
    echo "MON_RESULT_MODULE5=✅" | sudo tee -a "$SETUP_ENV_FILE"
  fi

fi
echo ""
echo ""

# =====================================================================
# [МОДУЛ 6] Node Exporter (хост метрики за Prometheus)
# =====================================================================
log "[6] NODE EXPORTER: инсталация и интеграция с Prometheus..."
log "=========================================================="
log ""

if sudo grep -q '^MON_RESULT_MODULE6=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 6 вече е изпълнен успешно. Пропускане..."
  echo ""
else
  # --- 1) Верификация: node_exporter е дефиниран в docker-compose.yml ---
  sudo test -f "$COMPOSE_DIR/docker-compose.yml" || { err "Липсва $COMPOSE_DIR/docker-compose.yml"; exit 1; }
  if ! (cd "$COMPOSE_DIR" && sudo docker compose config --services | grep -xq 'node_exporter'); then
    err "Липсва service 'node_exporter' в docker-compose.yml (Модул 5)."
    exit 1
  fi

  # --- 2) Стартиране/осигуряване на услугата ---
  (cd "$COMPOSE_DIR" && sudo docker compose up -d node_exporter) || { err "Неуспешен старт на node_exporter"; exit 1; }

  # --- 3) Health проверка на node_exporter (порт 9100) ---
  ok "Извършвам health проверка на http://127.0.0.1:9100/metrics ..."
  tries=0
  until curl -fsS http://127.0.0.1:9100/metrics >/dev/null 2>&1; do
    tries=$((tries+1))
    [[ $tries -ge 15 ]] && { err "node_exporter не отговаря на порт 9100"; exit 1; }
    sleep 1
  done
  ok "node_exporter е достъпен на порт 9100."

  # --- 4) Верификация: Prometheus има target към node_exporter:9100 ---
  sudo test -f "$PROM_DIR/prometheus.yml" || { err "Липсва $PROM_DIR/prometheus.yml (Модул 5)"; exit 1; }
  if ! grep -q "node_exporter:9100" "$PROM_DIR/prometheus.yml"; then
    err "В $PROM_DIR/prometheus.yml няма target 'node_exporter:9100'. Поправи Модул 5 (scrape_configs → job 'node')."
    exit 1
  fi

  # --- 5) Валидиране и рестарт само на Prometheus ---
  sudo docker run --rm \
    -v "$PROM_DIR:/etc/prometheus:ro" \
    --entrypoint /bin/promtool \
    prom/prometheus:latest \
    check config /etc/prometheus/prometheus.yml \
    || { err "Prometheus конфигурацията е невалидна."; exit 1; }

  (cd "$COMPOSE_DIR" && sudo docker compose up -d prometheus) || { err "Неуспешно презареждане на Prometheus"; exit 1; }
  ok "Prometheus е активен с node_exporter target."

  # --- 6) Маркиране на резултат ---
  if sudo grep -q '^MON_RESULT_MODULE6=' "$SETUP_ENV_FILE" 2>/dev/null; then
    sudo sed -i 's|^MON_RESULT_MODULE6=.*|MON_RESULT_MODULE6=✅|' "$SETUP_ENV_FILE" && echo "MON_RESULT_MODULE6=✅"
  else
    echo "MON_RESULT_MODULE6=✅" | sudo tee -a "$SETUP_ENV_FILE"
  fi
fi
echo ""
echo ""


# =====================================================================
# [МОДУЛ 7] Blackbox targets (file_sd) + промени в Prometheus/Compose
# =====================================================================
log "[7] BLACKBOX TARGETS: динамични цели през file_sd..."
log "===================================================="
log ""

# Проверка дали модулът вече е изпълнен
if [[ -f "$SETUP_ENV_FILE" ]] && sudo grep -Fxq 'MON_RESULT_MODULE7=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 7 вече е изпълнен успешно. Пропускане..."
  echo ""
else
  # --- 1) Директория и targets файл за Blackbox ---
  sudo mkdir -p "$PROM_DIR/targets"

  # Създай дефолтен списък с цели, ако липсва файлът
  if [[ ! -f "$PROM_DIR/targets/blackbox_http.yml" ]]; then
    sudo tee "$PROM_DIR/targets/blackbox_http.yml" >/dev/null <<'EOF'
- targets:
    # Вътрешни цели (контейнери в мрежата "monhub")
    - http://prometheus:9090
    - http://alertmanager:9093
    - http://grafana:3000
    # Примерна външна цел
    - https://www.debian.org
EOF
  fi

  # --- 2) Инжектиране на file_sd_configs в prometheus.yml (ако липсва) ---
  if ! grep -q 'file_sd_configs:' "$PROM_DIR/prometheus.yml"; then
    tmp_prom="/tmp/prom.$$"
    sudo cp -a "$PROM_DIR/prometheus.yml" "${PROM_DIR}/prometheus.yml.bak.$(date +%F-%H%M%S)"
    sudo awk '
      BEGIN{injob=0; done=0}
      # засичаме начало на job-а blackbox_http
      /^\s*-\s*job_name:\s*'\''blackbox_http'\''\s*$/ {injob=1}
      # след реда с module: [http_2xx] инжектираме file_sd_configs (само веднъж)
      injob==1 && /^\s*module:\s*\[http_2xx\]\s*$/ && done==0 {
        print
        print "    file_sd_configs:"
        print "      - files:"
        print "        - /etc/prometheus/targets/blackbox_http.yml"
        done=1
        next
      }
      # излизаме от job секцията при следващ job_name: или края на файла
      injob==1 && /^\s*-\s*job_name:\s*'\''/ && $0 !~ /blackbox_http/ {injob=0}
      {print}
    ' "$PROM_DIR/prometheus.yml" > "$tmp_prom" && sudo mv "$tmp_prom" "$PROM_DIR/prometheus.yml"
  fi

  # --- 3) Презареди само Prometheus, за да вземе новите настройки/targets ---
  if [[ -d "$COMPOSE_DIR" ]]; then
    (cd "$COMPOSE_DIR" && sudo docker compose up -d prometheus)
    ok "Prometheus е презареден с file_sd targets."
  else
    err "Липсва COMPOSE_DIR ($COMPOSE_DIR) – проверете Модул 5."
    exit 1
  fi

  # ✅ Финализиране: права и запис в todo.modules за Модул 10
  sudo chmod 0644 "$PROM_DIR/targets/blackbox_http.yml" || true

  # Път към файла с цели
  if sudo grep -q '^BLACKBOX_TARGETS_FILE=' "$MODULES_FILE" 2>/dev/null; then
    sudo sed -i 's|^BLACKBOX_TARGETS_FILE=.*|BLACKBOX_TARGETS_FILE="'"$PROM_DIR/targets/blackbox_http.yml"'"|' "$MODULES_FILE"
  else
    echo 'BLACKBOX_TARGETS_FILE="'"$PROM_DIR/targets/blackbox_http.yml"'"' | sudo tee -a "$MODULES_FILE" >/dev/null
  fi

  # Порт на Blackbox Exporter (за Модул 10)
  if sudo grep -q '^BLACKBOX_EXPORTER_PORT=' "$MODULES_FILE" 2>/dev/null; then
    sudo sed -i 's|^BLACKBOX_EXPORTER_PORT=.*|BLACKBOX_EXPORTER_PORT=9115|' "$MODULES_FILE"
  else
    echo 'BLACKBOX_EXPORTER_PORT=9115' | sudo tee -a "$MODULES_FILE" >/dev/null
  fi

  # --- 5) Маркиране на резултат ---
  if sudo grep -q '^MON_RESULT_MODULE7=' "$SETUP_ENV_FILE" 2>/dev/null; then
    sudo sed -i 's|^MON_RESULT_MODULE7=.*|MON_RESULT_MODULE7=✅|' "$SETUP_ENV_FILE" && echo "MON_RESULT_MODULE7=✅"
  else
    echo "MON_RESULT_MODULE7=✅" | sudo tee -a "$SETUP_ENV_FILE"
  fi

fi
echo ""
echo ""


# =====================================================================
# [МОДУЛ 8] Базови алърти (Prometheus rules + reload)
# =====================================================================
log "[8] БАЗОВИ АЛЪРТИ: добавяне на rules и презареждане на Prometheus..."
log "===================================================================="
log ""

# Проверка дали модулът вече е изпълнен
if sudo grep -q '^MON_RESULT_MODULE8=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 8 вече е изпълнен успешно. Пропускане..."
  echo ""
else
  # --- 1) Директория за правила ---
  sudo mkdir -p "$PROM_DIR/rules"

  # --- 2) Базови правила (safe overwrite) ---
  sudo tee "$PROM_DIR/rules/base.rules.yml" >/dev/null <<'EOF'
groups:
  - name: basic-health
    rules:
      - alert: InstanceDown
        expr: up == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Instance {{ $labels.instance }} е недостъпен"
          description: "Поне една цел не отговаря (job={{ $labels.job }}, instance={{ $labels.instance }})"

      - alert: NodeExporterMissing
        expr: absent(up{job="node"})
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "Липсва node_exporter"
          description: "Prometheus не намира node_exporter метрики за скрапване."

      - alert: HighCPULoad
        expr: (100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)) > 85
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Високо CPU натоварване на {{ $labels.instance }}"
          description: "Средното CPU натоварване е >85% през последните 10 минути."

      - alert: LowDiskSpace
        expr: (node_filesystem_avail_bytes{fstype!~"tmpfs|devtmpfs"} / node_filesystem_size_bytes{fstype!~"tmpfs|devtmpfs"}) < 0.10
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Недостатъчно дисково пространство на {{ $labels.instance }}"
          description: "Свободното пространство е под 10% (изкл. tmpfs/devtmpfs)."
EOF

    # Правим файла четим (детерминирано)
  sudo chmod 0644 "$PROM_DIR/rules/base.rules.yml"

# --- 3) rule_files в prometheus.yml (твърдо, без условни проверки) ---
  tmp_prom="/tmp/prom.$$"
  sudo cp -a "$PROM_DIR/prometheus.yml" "${PROM_DIR}/prometheus.yml.bak.$(date +%F-%H%M%S)"

  sudo awk '
    BEGIN{inrf=0; injected=0}
    {
      # ако сме вътре в стар rule_files блок – прескачаме редовете с "- ..."
      if (inrf==1) {
        if ($0 ~ /^\s*-\s*/) next;
        else inrf=0;
      }
      # начало на rule_files блок – не го печатаме (ще инжектираме наш)
      if ($0 ~ /^\s*rule_files\s*:/) { inrf=1; next }

      # преди scrape_configs: инжектираме каноничния блок (само веднъж)
      if ($0 ~ /^\s*scrape_configs\s*:/ && injected==0) {
        print "rule_files:"
        print "  - /etc/prometheus/rules/*.yml"
        print ""
        injected=1
      }

      print
    }
    END{
      # ако липсваше scrape_configs:, инжектираме в края
      if(injected==0){
        print ""
        print "rule_files:"
        print "  - /etc/prometheus/rules/*.yml"
      }
    }
  ' "$PROM_DIR/prometheus.yml" > "$tmp_prom" && sudo mv "$tmp_prom" "$PROM_DIR/prometheus.yml"

  # Валидация на правилата
  sudo docker run --rm \
    -v "$PROM_DIR/rules:/rules:ro" \
    --entrypoint /bin/promtool \
    prom/prometheus:latest \
    check rules /rules/*.yml \
    || { err "Невалидни Prometheus rules в $PROM_DIR/rules"; exit 1; }

  # Валидация на основната конфигурация (с rule_files)
  sudo docker run --rm \
    -v "$PROM_DIR:/etc/prometheus:ro" \
    --entrypoint /bin/promtool \
    prom/prometheus:latest \
    check config /etc/prometheus/prometheus.yml \
    || { err "prometheus.yml е невалиден след добавяне на rule_files"; exit 1; }

  # --- 4) Презареди само Prometheus, за да вземе новите правила ---
  if [[ -d "$COMPOSE_DIR" ]]; then
    (cd "$COMPOSE_DIR" && sudo docker compose up -d prometheus)
    ok "Prometheus е презареден с правилата за алърти."
  else
    err "Липсва COMPOSE_DIR ($COMPOSE_DIR) – проверете Модул 5."
    exit 1
  fi

  resp="$(curl -fsS 'http://127.0.0.1:9090/api/v1/rules' || true)"
  echo "$resp" | grep -q '"basic-health"' \
    && ok "Rules loaded (group=basic-health)" \
    || warn "Rules not visible в API (провери rule_files и mounts)"

  # --- 5) Маркиране на резултат ---
  if sudo grep -q '^MON_RESULT_MODULE8=' "$SETUP_ENV_FILE" 2>/dev/null; then
    if sudo sed -i 's|^MON_RESULT_MODULE8=.*|MON_RESULT_MODULE8=✅|' "$SETUP_ENV_FILE"; then
      echo "MON_RESULT_MODULE8=✅"
    fi
  else
    echo "MON_RESULT_MODULE8=✅" | sudo tee -a "$SETUP_ENV_FILE"
  fi

fi
echo ""
echo ""


exit 0
# =====================================================================
# [МОДУЛ 9] Alertmanager → Telegram известия (интерактивен с валидиране)
# =====================================================================
log "[9] ALERTMANAGER: Telegram известия..."
log "======================================="
log ""

# Проверка дали модулът вече е изпълнен
if sudo grep -q '^MON_RESULT_MODULE9=✅' "$SETUP_ENV_FILE" 2>/dev/null; then
  echo "ℹ️ Модул 9 вече е изпълнен успешно. Пропускане..."
  echo ""
else

# Ако вече има telegram_configs в alertmanager.yml → извличаме BOT_TOKEN/CHAT_ID от YAML (без въпроси)
if [[ -f "$ALERT_DIR/alertmanager.yml" ]] && sudo grep -q '^[[:space:]]*telegram_configs:' "$ALERT_DIR/alertmanager.yml" 2>/dev/null; then
  _Y="$ALERT_DIR/alertmanager.yml"
  _Y_DIR="$(dirname "$_Y")"

  BOT_TOKEN=""; CHAT_ID=""; BOT_TOKEN_FILE=""; _BT_SOURCE=""

  # helper: почистване
  _clean() {
    _v="${1%%#*}"; _v="${_v//$'\r'/}"; _v="${_v//\"/}"; _v="${_v//\'/}"
    _v="${_v#"${_v%%[![:space:]]*}"}"; _v="${_v%"${_v##*[![:space:]]}"}"
    printf "%s" "$_v"
  }

  # --- chat_id (inline) ---
  _raw_ci="$(sudo sed -nE "/^[[:space:]]*chat_id[[:space:]]*:/{
    s/^[[:space:]]*chat_id[[:space:]]*:[[:space:]]*//; p; q
  }" "$_Y" 2>/dev/null)"
  CHAT_ID="$(_clean "$_raw_ci")"

  # --- bot_token (inline) ---
  _raw_bt="$(sudo sed -nE "/^[[:space:]]*bot_token[[:space:]]*:/{
    s/^[[:space:]]*bot_token[[:space:]]*:[[:space:]]*//; p; q
  }" "$_Y" 2>/dev/null)"
  BOT_TOKEN="$(_clean "$_raw_bt")"
  [ -n "$BOT_TOKEN" ] && _BT_SOURCE="inline"

  # --- ако няма inline: bot_token_file ---
  if [ -z "$BOT_TOKEN" ]; then
    _raw_file="$(sudo sed -nE "/^[[:space:]]*bot_token_file[[:space:]]*:/{
      s/^[[:space:]]*bot_token_file[[:space:]]*:[[:space:]]*//; p; q
    }" "$_Y" 2>/dev/null)"
    BOT_TOKEN_FILE="$(_clean "$_raw_file")"
    if [ -n "$BOT_TOKEN_FILE" ]; then
      [[ "$BOT_TOKEN_FILE" != /* ]] && BOT_TOKEN_FILE="$_Y_DIR/$BOT_TOKEN_FILE"
      if sudo test -r "$BOT_TOKEN_FILE"; then
        BOT_TOKEN="$(sudo head -c 4096 "$BOT_TOKEN_FILE" | tr -d '\r\n')"
        _BT_SOURCE="file"
      else
        _BT_SOURCE="file-unreadable"
      fi
    fi
  fi

  # --- твърда проверка: chat_id е задължителен ---
  if [ -z "$CHAT_ID" ]; then
    err "Намерих telegram_configs, но липсва chat_id в $_Y."
    exit 1
  fi

  ok "Alertmanager вече е конфигуриран за Telegram (chat_id зареден; bot_token: ${_BT_SOURCE:-none})."
else
    # --- 1) Изискване и валидиране на токен ---
    TELEGRAM_BOT_TOKEN=""
    while true; do
      echo ""
      read -r -p "Въведете TELEGRAM_BOT_TOKEN (или 'q' за отказ): " TELEGRAM_BOT_TOKEN || TELEGRAM_BOT_TOKEN=""
      [[ "$TELEGRAM_BOT_TOKEN" == "q" || "$TELEGRAM_BOT_TOKEN" == "Q" ]] && { warn "Отказано от оператора."; exit 0; }
      if [[ -z "$TELEGRAM_BOT_TOKEN" ]]; then
        echo "❌ Токенът е празен. Опитайте отново."
        continue
      fi
      okflag="$(curl -sS "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe" | jq -r '.ok' 2>/dev/null || echo "false")"
      [[ "$okflag" == "true" ]] && { ok "Токенът е валиден."; break; }
      echo "❌ Невалиден токен. Проверете в @BotFather и опитайте отново."
    done

    # --- 2) Въвеждане и валидиране на chat_id (с тестово съобщение) ---
    TELEGRAM_CHAT_ID=""
    while true; do
      echo "Съвет: изпратете едно съобщение на бота (личен чат или група), за да има 'update'."
      read -r -p "Въведете TELEGRAM_CHAT_ID (или 'q' за отказ): " TELEGRAM_CHAT_ID || TELEGRAM_CHAT_ID=""
      [[ "$TELEGRAM_CHAT_ID" == "q" || "$TELEGRAM_CHAT_ID" == "Q" ]] && { warn "Отказано от оператора."; exit 0; }
      if [[ -z "$TELEGRAM_CHAT_ID" ]]; then
        echo "❌ CHAT_ID е празен. Опитайте отново."
        continue
      fi
      test_ok="$(curl -sS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
                 -d chat_id="${TELEGRAM_CHAT_ID}" \
                 -d text="✅ MonHub тестово известие" | jq -r '.ok' 2>/dev/null || echo "false")"
      [[ "$test_ok" == "true" ]] && { ok "Успешно изпратено тестово съобщение към chat_id=${TELEGRAM_CHAT_ID}."; break; }
      echo "❌ Неуспешно изпращане към този chat_id. Проверете дали ботът е в чата (и не е блокиран) и опитайте пак."
    done

    # --- 3) Запис на alertmanager.yml с Telegram получател ---
    sudo mkdir -p "$ALERT_DIR"
    sudo tee "$ALERT_DIR/alertmanager.yml" >/dev/null <<EOF
route:
  receiver: 'telegram'
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 12h

receivers:
  - name: 'telegram'
    telegram_configs:
      - bot_token: '${TELEGRAM_BOT_TOKEN}'
        chat_id: '${TELEGRAM_CHAT_ID}'
        api_url: 'https://api.telegram.org'
        send_resolved: true
EOF
    sudo chown root:root "$ALERT_DIR/alertmanager.yml"
    sudo chmod 640 "$ALERT_DIR/alertmanager.yml"

    # --- 4) Презареждане само на Alertmanager ---
    if [[ -d "$COMPOSE_DIR" ]]; then
      (cd "$COMPOSE_DIR" && sudo docker compose up -d alertmanager)
      ok "Alertmanager е презареден с Telegram конфигурация."
    else
      err "Липсва COMPOSE_DIR ($COMPOSE_DIR) – проверете Модул 5."
      exit 1
    fi
  fi

  # --- Запис в todo.modules за следващите модули (без промяна на права/owner) ---
  if ! sudo test -f "$MODULES_FILE"; then
    echo "❌ Липсва $MODULES_FILE (изпълнете Модул 1 преди Модул 9)."
    exit 1
  fi
  if ! sudo sh -c "true >> '$MODULES_FILE'"; then
    echo "❌ Нямам права за запис в $MODULES_FILE (immutable/readonly)."
    exit 1
  fi

  # Хидратиране на BOT_TOKEN/CHAT_ID за set -u
  # Източник 1: monitoring.env; Източник 2: todo.modules
  if sudo test -f "$MON_ENV_FILE"; then
    BOT_TOKEN="$(sudo awk -F= '/^[[:space:]]*BOT_TOKEN[[:space:]]*=/ {val=$0; sub(/^[^=]*=/,"",val); gsub(/\r/,"",val); gsub(/^[[:space:]]+|[[:space:]]+$/,"",val); print val; exit}' "$MON_ENV_FILE" 2>/dev/null)"
  fi
  [ -z "${BOT_TOKEN:-}" ] && BOT_TOKEN="$(sudo awk -F= '/^[[:space:]]*BOT_TOKEN[[:space:]]*=/ {val=$0; sub(/^[^=]*=/,"",val); gsub(/\r/,"",val); gsub(/^[[:space:]]+|[[:space:]]+$/,"",val); print val; exit}' "$MODULES_FILE" 2>/dev/null)"

  if sudo test -f "$MON_ENV_FILE"; then
    CHAT_ID="$(sudo awk -F= '/^[[:space:]]*CHAT_ID[[:space:]]*=/ {val=$0; sub(/^[^=]*=/,"",val); gsub(/\r/,"",val); gsub(/^[[:space:]]+|[[:space:]]+$/,"",val); print val; exit}' "$MON_ENV_FILE" 2>/dev/null)"
  fi
  [ -z "${CHAT_ID:-}" ] && CHAT_ID="$(sudo awk -F= '/^[[:space:]]*CHAT_ID[[:space:]]*=/ {val=$0; sub(/^[^=]*=/,"",val); gsub(/\r/,"",val); gsub(/^[[:space:]]+|[[:space:]]+$/,"",val); print val; exit}' "$MODULES_FILE" 2>/dev/null)"

  # Твърда проверка – chat_id е задължителен, bot_token може да липсва (когато е bot_token_file в контейнера)
  if [ -z "${CHAT_ID:-}" ]; then
    echo "❌ Липсва CHAT_ID (Модул 9 не е завършен)."
    exit 1
  fi

  # BOT_TOKEN (записвай само ако е наличен)
  if [ -n "${BOT_TOKEN:-}" ]; then
    if sudo grep -q '^BOT_TOKEN=' "$MODULES_FILE" 2>/dev/null; then
      sudo sed -i "s|^BOT_TOKEN=.*|BOT_TOKEN=${BOT_TOKEN}|" "$MODULES_FILE"
    else
      echo "BOT_TOKEN=${BOT_TOKEN}" | sudo tee -a "$MODULES_FILE" >/dev/null
    fi
  fi

  # CHAT_ID
  if sudo grep -q '^CHAT_ID=' "$MODULES_FILE" 2>/dev/null; then
    sudo sed -i "s|^CHAT_ID=.*|CHAT_ID=${CHAT_ID}|" "$MODULES_FILE"
  else
    echo "CHAT_ID=${CHAT_ID}" | sudo tee -a "$MODULES_FILE" >/dev/null
  fi

  # --- 5) Маркиране на резултат ---
  if sudo grep -q '^MON_RESULT_MODULE9=' "$SETUP_ENV_FILE" 2>/dev/null; then
    sudo sed -i 's|^MON_RESULT_MODULE9=.*|MON_RESULT_MODULE9=✅|' "$SETUP_ENV_FILE" && echo "MON_RESULT_MODULE9=✅"
  else
    echo "MON_RESULT_MODULE9=✅" | sudo tee -a "$SETUP_ENV_FILE"
  fi
fi

echo ""
echo ""


# ==========================================================
# [МОДУЛ 10] Обобщение – Monitoring Stack + Telegram Alerts
# ==========================================================
log "[10] ОБОБЩЕНИЕ – Monitoring Stack + Telegram Alerts"
log "===================================================="
log ""

NETGALAXY_DIR="${NETGALAXY_DIR:-/etc/netgalaxy}"
SETUP_ENV_FILE="${SETUP_ENV_FILE:-$NETGALAXY_DIR/setup.env}"
MON_ENV_FILE="${MON_ENV_FILE:-$NETGALAXY_DIR/monitoring.env}"

IP4="$(hostname -I | awk '{print $1}')"

GRAFANA_URL="http://${IP4}:3000"
PROM_URL="http://${IP4}:9090"
ALERT_URL="http://${IP4}:9093"
LOKI_URL="http://${IP4}:3100"
NODE_URL="http://${IP4}:9100/metrics"
BLACKBOX_PROBE="http://${IP4}:9115/probe?target=https://example.org"

# Telegram (само четене на CHAT_ID; без токен)
CHAT_ID=""

# --- Зареждане на CHAT_ID (без awk/pipe; устойчиво на липсващ файл)
[ -r "$MON_ENV_FILE" ] && . "$MON_ENV_FILE"
[ -z "${CHAT_ID:-}" ] && [ -r "$MODULES_FILE" ] && . "$MODULES_FILE"
CHAT_ID="${CHAT_ID%$'\r'}"

if [ -z "${CHAT_ID:-}" ]; then
  echo "❌ CHAT_ID липсва. Модул 9 (Telegram Alerts) не е завършен."
  exit 1
fi

# 2) Fallback към todo.modules
[ -z "$CHAT_ID" ] && CHAT_ID="$(sudo awk -F= '/^[[:space:]]*CHAT_ID[[:space:]]*=/ {val=$0; sub(/^[^=]*=/,"",val); gsub(/\r/,"",val); gsub(/^[[:space:]]+|[[:space:]]+$/,"",val); print val; exit}' "$MODULES_FILE" 2>/dev/null)"

# 3) Твърда проверка
if [ -z "$CHAT_ID" ]; then
  echo "❌ CHAT_ID липсва. Модул 9 (Telegram Alerts) не е завършен."
  exit 1
fi

printf "\n"
printf "Мониторинг стек (линкове по IP на този сървър):\n"
printf "  • Grafana ........... %s  (default: admin / admin)\n" "$GRAFANA_URL"
printf "  • Prometheus ........ %s  (UI: /, /graph, /targets)\n" "$PROM_URL"
printf "  • Alertmanager ...... %s  (UI: /#/alerts, /#/silences)\n" "$ALERT_URL"
printf "  • Loki API .......... %s  (API; визуализация през Grafana)\n" "$LOKI_URL"
printf "  • node_exporter ..... %s\n" "$NODE_URL"
printf "  • Blackbox probe .... %s\n" "$BLACKBOX_PROBE"

printf "\nДиректории:\n"
printf "  • Логове ............ %s\n" "${LOG_DIR:-<не е зададено>}"
printf "  • Compose ........... %s\n" "${COMPOSE_DIR:-<не е зададено>}"

# Откриване на SSH порта (от sshd_config; по подразбиране 22)
SSH_PORT="$(sudo awk '/^[[:space:]]*Port[[:space:]]+[0-9]+/ {print $2; exit}' /etc/ssh/sshd_config 2>/dev/null)"
SSH_PORT="${SSH_PORT:-22}"

# Зареждане на CHAT_ID без awk/pipe; env → fallback към todo.modules
[ -r "$MON_ENV_FILE" ] && . "$MON_ENV_FILE"
[ -z "${CHAT_ID:-}" ] && [ -r "$MODULES_FILE" ] && . "$MODULES_FILE"
CHAT_ID="${CHAT_ID%$'\r'}"

if [ -z "${CHAT_ID:-}" ]; then
  echo "❌ CHAT_ID липсва. Модул 9 (Telegram Alerts) не е завършен."
  exit 1
fi

# --- Telegram: извличане САМО от inline ключове в alertmanager.yml ---
YAML="/opt/netgalaxy/monhub/alertmanager/alertmanager.yml"
sudo test -r "$YAML" || { echo "❌ Недостъпен файл: $YAML"; exit 1; }

# BOT_TOKEN (inline ред: [-] bot_token: <стойност>)
_line="$(sudo grep -m1 -E '^[[:space:]]*[-]?[[:space:]]*bot_token[[:space:]]*:' /opt/netgalaxy/monhub/alertmanager/alertmanager.yml 2>/dev/null || true)"
BOT_TOKEN="${_line#*:}"
BOT_TOKEN="${BOT_TOKEN%%#*}"
BOT_TOKEN="${BOT_TOKEN//$'\r'/}"
BOT_TOKEN="${BOT_TOKEN//\"/}"; BOT_TOKEN="${BOT_TOKEN//\'/}"
BOT_TOKEN="${BOT_TOKEN#"${BOT_TOKEN%%[![:space:]]*}"}"
BOT_TOKEN="${BOT_TOKEN%"${BOT_TOKEN##*[![:space:]]}"}"

# CHAT_ID (inline ред: [-] chat_id: <стойност>)
_line="$(sudo grep -m1 -E '^[[:space:]]*[-]?[[:space:]]*chat_id[[:space:]]*:' /opt/netgalaxy/monhub/alertmanager/alertmanager.yml 2>/dev/null || true)"
CHAT_ID="${_line#*:}"
CHAT_ID="${CHAT_ID%%#*}"
CHAT_ID="${CHAT_ID//$'\r'/}"
CHAT_ID="${CHAT_ID//\"/}"; CHAT_ID="${CHAT_ID//\'/}"
CHAT_ID="${CHAT_ID#"${CHAT_ID%%[![:space:]]*}"}"
CHAT_ID="${CHAT_ID%"${CHAT_ID##*[![:space:]]}"}"

: "${BOT_TOKEN:?❌ BOT_TOKEN липсва в /opt/netgalaxy/monhub/alertmanager/alertmanager.yml (очаква се ред: bot_token: <стойност>)}"
: "${CHAT_ID:?❌ CHAT_ID липсва в /opt/netgalaxy/monhub/alertmanager/alertmanager.yml (очаква се ред: chat_id: <стойност>)}"

printf "\nTelegram Alerts:\n"
printf "  • Бот ............... @netgalaxy_alerts_bot\n"
printf "  • CHAT_ID ........... %s\n" "$CHAT_ID"

printf "\nБърз тест (през браузър):\n"
printf "  https://api.telegram.org/bot%s/sendMessage?chat_id=%s&text=NetGalaxy%%20Monitoring%%20test\n" "$BOT_TOKEN" "$CHAT_ID"

# UFW/портове (SSH включен сред останалите)
printf "\nUFW: отворени портове → %s, 3000, 9090, 9093, 3100, 9100, 9115\n" "$SSH_PORT"

echo ""
echo ""

# --- Потвърждение от оператора ---
while true; do
  read -p "✅ Приемате ли конфигурацията като завършена? (y/n): " confirm
  case "$confirm" in
    [Yy]*)
      # ✅ Запис финален статус
      if grep -q '^SETUP_MONITORING_STATUS=' "$SETUP_ENV_FILE" 2>/dev/null; then
        sed -i 's|^SETUP_MONITORING_STATUS=.*|SETUP_MONITORING_STATUS=✅|' "$SETUP_ENV_FILE"
      else
        echo "SETUP_MONITORING_STATUS=✅" >> "$SETUP_ENV_FILE"
      fi
      echo "✅ Конфигурацията е приета и маркирана като завършена."
      break
      ;;
    [Nn]*)
      echo "❎ Конфигурацията НЕ е приета. Скриптът ще се прекрати без финален запис."
      exit 0
      ;;
    *)
      echo "❌ Невалиден избор! Моля, въведете 'y' или 'n'."
      ;;
  esac
done

# --- Почистване ---
if [[ -f "$MODULES_FILE" ]]; then
  rm -f "$MODULES_FILE"
  echo "🗑️ Временният файл todo.modules беше изтрит."
fi

# --- ЗАЩИТА: НЕ ИЗТРИВАЙ /etc/netgalaxy И setup.env ---
# Създаване на маркер и резервно копие; фиксиране на права и собственик.
sudo mkdir -p /etc/netgalaxy /var/backups/netgalaxy
sudo touch /etc/netgalaxy/.nodelete

# Резервно копие на setup.env (само ако има промяна)
if ! cmp -s /etc/netgalaxy/setup.env /var/backups/netgalaxy/setup.env 2>/dev/null; then
  sudo cp -a /etc/netgalaxy/setup.env /var/backups/netgalaxy/setup.env
fi

# ✅ Възстановяване на забраната за промяна/изтриване
if [[ -d "$NETGALAXY_DIR" ]]; then
  # Нормализираме собственост и права
  sudo chown root:root "$NETGALAXY_DIR" 2>/dev/null || true
  sudo chmod 755 "$NETGALAXY_DIR"       2>/dev/null || true

  [[ -f "$SETUP_ENV_FILE"      ]] && { sudo chown root:root "$SETUP_ENV_FILE"      2>/dev/null || true; sudo chmod 644 "$SETUP_ENV_FILE"      2>/dev/null || true; }
  [[ -f "$MODULES_FILE"        ]] && { sudo chown root:root "$MODULES_FILE"        2>/dev/null || true; sudo chmod 644 "$MODULES_FILE"        2>/dev/null || true; }
  [[ -f "$NETGALAXY_DIR/.nodelete" ]] && { sudo chown root:root "$NETGALAXY_DIR/.nodelete" 2>/dev/null || true; sudo chmod 644 "$NETGALAXY_DIR/.nodelete" 2>/dev/null || true; }

  # Връщаме immutable флага (файлове + директория)
  [[ -f "$SETUP_ENV_FILE"      ]] && sudo chattr +i "$SETUP_ENV_FILE"       2>/dev/null || true
  [[ -f "$MODULES_FILE"        ]] && sudo chattr +i "$MODULES_FILE"         2>/dev/null || true
  [[ -f "$NETGALAXY_DIR/.nodelete" ]] && sudo chattr +i "$NETGALAXY_DIR/.nodelete" 2>/dev/null || true
  sudo chattr +i "$NETGALAXY_DIR" 2>/dev/null || true
fi

# ВАЖНО: Скриптът не трябва никога да изтрива /etc/netgalaxy или setup.env.
# Изтрива се само за todo.modules и самия скрипт.

if [[ -f "$0" ]]; then
  echo "🗑️ Премахване на скрипта..."
  rm -- "$0"
fi
echo ""
echo ""

# ------------ Край на скрипта ------------
