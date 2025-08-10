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

# =====================================================================
# vps-monhub-qsetup.sh — Централен сървър за наблюдение и логове
# Версия: 1.0 (Ubuntu 24.04 amd64)
# Лиценз: NetGalaxySoft internal
# =====================================================================

# -------------------- Общи променливи --------------------
SETUP_DIR="/etc/netgalaxy"
SETUP_ENV_FILE="$SETUP_DIR/setup.env"
MODULES_FILE="$SETUP_DIR/todo.modules"
STAMP_DIR="$SETUP_DIR/stamps"
COMPOSE_DIR="/opt/netgalaxy/monhub"
PROM_DIR="$COMPOSE_DIR/prometheus"
ALERT_DIR="$COMPOSE_DIR/alertmanager"
LOKI_DIR="$COMPOSE_DIR/loki"
GRAFANA_DIR="$COMPOSE_DIR/grafana"
LOG_DIR="/var/log/netgalaxy"
DOMAIN_EXPECTED="${DOMAIN_EXPECTED:-}"     # Позволяваме подаване отвън: DOMAIN_EXPECTED=ns-monitor.netgalaxy.eu bash ...
IP_EXPECTED="${IP_EXPECTED:-}"             # Позволяваме подаване отвън: IP_EXPECTED=203.0.113.10 bash ...

# -------------------- Помощни функции --------------------
WRITES_ENABLED=0

log()  { echo -e "$*"; }
ok()   { echo -e "✅ $*"; }
warn() { echo -e "⚠️  $*"; }
err()  { echo -e "❌ $*" >&2; }

die()  { err "$*"; exit 1; }

# Разрешава записи ЕДВА след като Модул 1 потвърди, че може.
# Тази функция НЕ създава setup.env и НЕ пипа /etc/netgalaxy — само включва флага.
enable_writes() {
  WRITES_ENABLED=1
}

# Проверка дали даден „stamp“ файл съществува (без да създаваме нищо)
already_done() {
  local stamp="$1"
  [[ -f "$STAMP_DIR/$stamp" ]]
}

# Слага „stamp“ само ако е разрешен запис и базовата папка съществува.
stamp() {
  local stamp="$1"
  [[ "$WRITES_ENABLED" -eq 1 ]] || die "Забранен запис (stamp): опитай след Модул 1."
  [[ -d "$SETUP_DIR" ]] || die "Липсва $SETUP_DIR; базовият скрипт не е завършил коректно."
  # Създаваме само поддиректорията за stamps, но НЕ пипаме setup.env
  sudo mkdir -p "$STAMP_DIR"
  sudo touch "$STAMP_DIR/$stamp"
}

# Маркира успех в setup.env, без да го създава. Грешка, ако файлът липсва.
mark_success() {
  local key="$1"
  [[ "$WRITES_ENABLED" -eq 1 ]] || die "Забранен запис (mark_success): опитай след Модул 1."
  [[ -f "$SETUP_ENV_FILE" ]] || die "Липсва $SETUP_ENV_FILE; базовият скрипт не е завършил коректно."
  if sudo grep -q "^$key=" "$SETUP_ENV_FILE" 2>/dev/null; then
    sudo sed -i "s|^$key=.*|$key=✅|" "$SETUP_ENV_FILE"
  else
    echo "$key=✅" | sudo tee -a "$SETUP_ENV_FILE" >/dev/null
  fi
}


NETGALAXY_DIR="/etc/netgalaxy"
MODULES_FILE="$NETGALAXY_DIR/todo.modules"
SETUP_ENV_FILE="$NETGALAXY_DIR/setup.env"

# =====================================================================
# [МОДУЛ 1] ПРЕДВАРИТЕЛНИ ПРОВЕРКИ И ИНИЦИАЛИЗАЦИЯ
# =====================================================================
echo "[1] ПРЕДВАРИТЕЛНИ ПРОВЕРКИ НА СИСТЕМА..."
echo "-----------------------------------------------------------"
echo ""

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
      break
    fi
  done

  # ✅ Временно премахване на забраната за промяна/изтриване
  if [[ -d "$NETGALAXY_DIR" ]]; then
    sudo chown root:root "$NETGALAXY_DIR" "$SETUP_ENV_FILE" "$NETGALAXY_DIR/.nodelete" 2>/dev/null
    sudo chmod 755 "$NETGALAXY_DIR" 2>/dev/null
    sudo chmod 644 "$SETUP_ENV_FILE" 2>/dev/null
    sudo chmod 644 "$NETGALAXY_DIR/.nodelete" 2>/dev/null
    sudo chattr -i "$NETGALAXY_DIR/.nodelete" 2>/dev/null || true
    sudo chattr -i "$MODULES_FILE" 2>/dev/null || true
  fi

  # ✅ Запис или обновяване на SERVER_IP в todo.modules
  if sudo grep -q '^SERVER_IP=' "$MODULES_FILE" 2>/dev/null; then
    sudo sed -i "s|^SERVER_IP=.*|SERVER_IP=\"$SERVER_IP\"|" "$MODULES_FILE"
  else
    echo "SERVER_IP=\"$SERVER_IP\"" | sudo tee -a "$MODULES_FILE" > /dev/null
  fi

  # ✅ Запис на резултат за Модул 1
  if sudo grep -q '^MON_RESULT_MODULE1=' "$SETUP_ENV_FILE" 2>/dev/null; then
    sudo sed -i 's|^MON_RESULT_MODULE1=.*|MON_RESULT_MODULE1=✅|' "$SETUP_ENV_FILE"
  else
    echo "MON_RESULT_MODULE1=✅" | sudo tee -a "$SETUP_ENV_FILE" > /dev/null
  fi
fi
echo ""
echo ""


exit 0
















# =====================================================================
# [МОДУЛ 1] Инициализация и валидации (FQDN/IP, системни директории)
# =====================================================================
log ""
log "=============================================="
log "[1] ИНИЦИАЛИЗАЦИЯ И ВАЛИДАЦИИ..."
log "=============================================="
log ""

if ! already_done "M1.init"; then
  ensure_env_files

  HOST_FQDN="$(hostname -f 2>/dev/null || hostname)"
  HOST_IPv4="$(curl -fsS http://checkip.amazonaws.com 2>/dev/null || true)"
  [[ -z "$HOST_IPv4" ]] && HOST_IPv4="$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null || true)"

  # Записваме каквото знаем
  if ! sudo grep -q '^MONHUB_HOST_FQDN=' "$SETUP_ENV_FILE" 2>/dev/null; then
    echo "MONHUB_HOST_FQDN=${HOST_FQDN}" | sudo tee -a "$SETUP_ENV_FILE" >/dev/null
  else
    sudo sed -i "s|^MONHUB_HOST_FQDN=.*|MONHUB_HOST_FQDN=${HOST_FQDN}|" "$SETUP_ENV_FILE"
  fi
  if ! sudo grep -q '^MONHUB_HOST_IP=' "$SETUP_ENV_FILE" 2>/dev/null; then
    echo "MONHUB_HOST_IP=${HOST_IPv4}" | sudo tee -a "$SETUP_ENV_FILE" >/dev/null
  else
    sudo sed -i "s|^MONHUB_HOST_IP=.*|MONHUB_HOST_IP=${HOST_IPv4}|" "$SETUP_ENV_FILE"
  fi

  # Задължителни твърдения, ако са подадени
  if [[ -n "$DOMAIN_EXPECTED" ]] && [[ "$HOST_FQDN" != "$DOMAIN_EXPECTED" ]]; then
    err "FQDN не съвпада. Очакван: $DOMAIN_EXPECTED, реален: $HOST_FQDN"
    exit 10
  fi
  if [[ -n "$IP_EXPECTED" ]] && [[ "$HOST_IPv4" != "$IP_EXPECTED" ]]; then
    err "Публичният IP не съвпада. Очакван: $IP_EXPECTED, реален: $HOST_IPv4"
    exit 11
  fi

  # Създаваме директории за стековете
  sudo mkdir -p "$COMPOSE_DIR" "$PROM_DIR" "$ALERT_DIR" "$LOKI_DIR" "$GRAFANA_DIR" "$LOG_DIR"

  stamp "M1.init"
  mark_success "MONHUB_MODULE1"
  ok "Модул 1 завърши."
else
  warn "Модул 1 вече е изпълнен. Пропускане."
fi

# =====================================================================
# [МОДУЛ 2] Системни ъпдейти, ssh твърдяване, UFW
# =====================================================================
log ""
log "=============================================="
log "[2] СИСТЕМНИ НАСТРОЙКИ: ъпдейти, SSH, UFW..."
log "=============================================="
log ""

if ! already_done "M2.sys"; then
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

  stamp "M2.sys"
  mark_success "MONHUB_MODULE2"
  ok "Модул 2 завърши."
else
  warn "Модул 2 вече е изпълнен. Пропускане."
fi

# =====================================================================
# [МОДУЛ 3] Инсталация на Docker Engine + Compose (LTS)
# =====================================================================
log ""
log "=============================================="
log "[3] DOCKER ENGINE + COMPOSE..."
log "=============================================="
log ""

if ! already_done "M3.docker"; then
  # Официално хранилище на Docker
  sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # Разрешаваме docker срвс
  sudo systemctl enable --now docker

  stamp "M3.docker"
  mark_success "MONHUB_MODULE3"
  ok "Модул 3 завърши."
else
  warn "Модул 3 вече е изпълнен. Пропускане."
fi

# =====================================================================
# [МОДУЛ 4] Конфигурации за Prometheus/Alertmanager/Grafana/Loki/Promtail/Exporters
# =====================================================================
log ""
log "=============================================="
log "[4] КОНФИГУРАЦИИ НА MON STACK..."
log "=============================================="
log ""

if ! already_done "M4.cfg"; then
  # --- Prometheus config ---
  sudo tee "$PROM_DIR/prometheus.yml" >/dev/null <<'YAML'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['prometheus:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['node_exporter:9100']

  - job_name: 'blackbox_http'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
        - https://example.org
        - https://netgalaxy.eu
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox:9115

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']
YAML

  # --- Alertmanager config (dummy, без SMTP за сега) ---
  sudo tee "$ALERT_DIR/alertmanager.yml" >/dev/null <<'YAML'
route:
  receiver: 'dev-null'
  group_by: ['alertname', 'instance']
  group_wait: 10s
  group_interval: 2m
  repeat_interval: 1h

receivers:
  - name: 'dev-null'
YAML

  # --- Loki config ---
  sudo tee "$LOKI_DIR/loki-config.yml" >/dev/null <<'YAML'
auth_enabled: false
server:
  http_listen_port: 3100
common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h
ruler:
  alertmanager_url: http://alertmanager:9093
YAML

  # --- Promtail config (системни логове) ---
  sudo tee "$COMPOSE_DIR/promtail-config.yml" >/dev/null <<'YAML'
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
      - targets: [localhost]
        labels:
          job: varlogs
          __path__: /var/log/*.log
  - job_name: journal
    journal:
      max_age: 12h
      labels:
        job: systemd-journal
    relabel_configs:
      - source_labels: ['__journal__systemd_unit']
        target_label: 'unit'
YAML

  # --- docker-compose.yml ---
  sudo tee "$COMPOSE_DIR/docker-compose.yml" >/dev/null <<'YAML'
services:
  prometheus:
    image: prom/prometheus:latest
    restart: unless-stopped
    volumes:
      - ./prometheus:/etc/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
    ports:
      - '9090:9090'
    networks: [mon]

  alertmanager:
    image: prom/alertmanager:latest
    restart: unless-stopped
    volumes:
      - ./alertmanager:/etc/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
    ports:
      - '9093:9093'
    networks: [mon]

  node_exporter:
    image: prom/node-exporter:latest
    restart: unless-stopped
    pid: host
    ports:
      - '9100:9100'
    networks: [mon]

  blackbox:
    image: prom/blackbox-exporter:latest
    restart: unless-stopped
    ports:
      - '9115:9115'
    networks: [mon]

  loki:
    image: grafana/loki:2.9.8
    restart: unless-stopped
    command: [ "-config.file=/etc/loki/loki-config.yml" ]
    volumes:
      - ./loki:/etc/loki
      - loki-data:/loki
    ports:
      - '3100:3100'
    networks: [mon]

  promtail:
    image: grafana/promtail:2.9.8
    restart: unless-stopped
    volumes:
      - /var/log:/var/log:ro
      - /var/lib/systemd:/var/lib/systemd:ro
      - ./promtail-config.yml:/etc/promtail/config.yml:ro
    command: [ "-config.file=/etc/promtail/config.yml" ]
    networks: [mon]

  grafana:
    image: grafana/grafana:10.4.8
    restart: unless-stopped
    ports:
      - '3000:3000'
    volumes:
      - grafana-data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
    networks: [mon]

volumes:
  grafana-data: {}
  loki-data: {}

networks:
  mon:
    driver: bridge
YAML

  # Права
  sudo chown -R root:root "$COMPOSE_DIR"
  sudo chmod -R 755 "$COMPOSE_DIR"

  stamp "M4.cfg"
  mark_success "MONHUB_MODULE4"
  ok "Модул 4 завърши."
else
  warn "Модул 4 вече е изпълнен. Пропускане."
fi

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
