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
  # --- 1) Директории и .env ---
  sudo mkdir -p "$PROM_DIR" "$ALERT_DIR" "$LOKI_DIR/data" "$GRAFANA_DIR/provisioning/datasources" "$COMPOSE_DIR/blackbox" "$GRAFANA_DIR/data"

  # .env за docker compose (пътища и базови креденшъли)
  sudo tee "$COMPOSE_DIR/.env" >/dev/null <<EOF
PROM_DIR=$PROM_DIR
ALERT_DIR=$ALERT_DIR
LOKI_DIR=$LOKI_DIR
GRAFANA_DIR=$GRAFANA_DIR

# Базови Grafana креденшъли (сменете по-късно чрез security скрипта)
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
      - targets: ['localhost:9100']

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
  prometheus:
    image: prom/prometheus:latest
    container_name: monhub_prometheus
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.retention.time=15d
    volumes:
      - ${PROM_DIR}/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ${PROM_DIR}/data:/prometheus
    ports:
      - "9090:9090"
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
    restart: unless-stopped
    networks: [monhub]

  blackbox:
    image: prom/blackbox-exporter:latest
    container_name: monhub_blackbox
    volumes:
      - ${PWD}/blackbox/blackbox.yml:/etc/blackbox_exporter/config.yml:ro
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
    restart: unless-stopped
    networks: [monhub]

  promtail:
    image: grafana/promtail:2.9.8
    container_name: monhub_promtail
    command: -config.file=/etc/promtail/config.yml
    volumes:
      - /var/log:/var/log:ro
      - /var/log/journal:/var/log/journal:ro
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
    depends_on:
      - prometheus
      - loki
    restart: unless-stopped
    networks: [monhub]

networks:
  monhub:
    driver: bridge
EOF

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
  # --- 1) Инсталация на Node Exporter (systemd пакет) ---
  sudo apt-get update -y
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y prometheus-node-exporter

  # Уверяваме се, че услугата е активирана и стартирана
  sudo systemctl enable --now prometheus-node-exporter
  sudo systemctl is-active --quiet prometheus-node-exporter && ok "node_exporter е стартиран на порт 9100." || warn "node_exporter не изглежда активен."

  # --- 2) Откриване на SERVER_IP за достъп от контейнера Prometheus ---
  SERVER_IP_VALUE=""
  if [[ -f "$MODULES_FILE" ]]; then
    SERVER_IP_VALUE="$(awk -F= '/^SERVER_IP=/{gsub(/"/,"",$2); print $2}' "$MODULES_FILE" | tail -n1)"
  fi
  if [[ -z "$SERVER_IP_VALUE" ]]; then
    # fallback – засичане на публичния IPv4 (без въпроси към оператора)
    SERVER_IP_VALUE="$(curl -s -4 ifconfig.me || true)"
  fi
  if [[ -z "$SERVER_IP_VALUE" ]]; then
    err "Неуспешно откриване на SERVER_IP. Моля, задайте SERVER_IP в $MODULES_FILE и стартирайте отново."
    exit 1
  fi
  ok "Използван SERVER_IP за Prometheus target: $SERVER_IP_VALUE:9100"

  # --- 3) Актуализация на Prometheus конфигурацията (target към хоста) ---
  if [[ -f "$PROM_DIR/prometheus.yml" ]]; then
    # Заменяме 'localhost:9100' или "localhost:9100" с "<SERVER_IP>:9100"
    sudo sed -i -E "s@(['\"])localhost:9100\1@\"${SERVER_IP_VALUE}:9100\"@g" "$PROM_DIR/prometheus.yml"
  else
    err "Липсва файл $PROM_DIR/prometheus.yml – Модул 5 вероятно не е изпълнен."
    exit 1
  fi

  # --- 4) Рестарт само на Prometheus контейнера, за да прочете новата конфигурация ---
  if [[ -d "$COMPOSE_DIR" ]]; then
    (cd "$COMPOSE_DIR" && sudo docker compose up -d prometheus)
    ok "Prometheus е презареден с новия target."
  else
    err "Липсва COMPOSE_DIR ($COMPOSE_DIR) – проверете Модул 5."
    exit 1
  fi

  # --- 5) Маркиране на резултат ---
  if sudo grep -q '^MON_RESULT_MODULE6=' "$SETUP_ENV_FILE" 2>/dev/null; then
    if sudo sed -i 's|^MON_RESULT_MODULE6=.*|MON_RESULT_MODULE6=✅|' "$SETUP_ENV_FILE"; then
      echo "MON_RESULT_MODULE6=✅"
    fi
  else
    echo "MON_RESULT_MODULE6=✅" | sudo tee -a "$SETUP_ENV_FILE"
  fi
fi

echo ""
echo ""













exit 0
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
