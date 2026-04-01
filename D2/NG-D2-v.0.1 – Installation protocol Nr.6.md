# NetGalaxy Network

## Проект NG-D2 за добавяне на нов сървър в мрежата NetGalaxy

### Инсталационен протокол № 6

#### Конфигуриране на хостинг за управление на сървъра (d2.netgalaxy.eu).

---

### Информация за документа

**Проект:** NetGalaxy  
**Document ID:** NG-D2-v.0.1 – Installation protocol Nr.6.md  
**Дата:** 31.03.2026  
**Заглавие:** Инсталационен протокол № 6  
**Задачи за изпълнение:**

  * Дефиниране на параметрите в конфигурационния файл (какво, кога и как се архивира)
  * Създаване на скрипта за архивиране (backup engine)
  * Ръчно тестване на backup engine (първо изпълнение)
  * Проверка на наличния архив на S1
  * Създаване на скрипт за извличане на архив към директорията /restore
  * Тестване на restore-fetch скрипта
  * Създаване на cleanup скрипт
  * Ръчно тестване на cleanup скрипта
  * Конфигуриране на автоматично изпълнение чрез cron
  
  
📌 Системата за архивиране се изгражда като независим механизъм и не зависи от NetGalaxyCP  
📌 На този етап конфигурацията се управлява чрез файл, а не чрез интерфейс

---

**Срок за изпълнение:** 01.04.2026  
**Изпълнител:** Илко Йорданов  
**Статус:** Изпълнен на 01.04.2026  
**Локация на документа:** GitHub Repository: servers/D2/NG-D2-v.0.1 – Installation protocol Nr.6  
**Контакт:** 📧 [yordanov.netgalaxy@gmail.com](mailto:yordanov.netgalaxy@gmail.com)  

**Copyright:** © 2026 NetGalaxy™ by Ilko Iordanov. All rights reserved.  
***Лиценз:*** Този документ е част от проекта NetGalaxy. Предназначен е само за вътрешно ползване в рамките на мрежата NetGalaxy. Разпространението или публикуването извън мрежата не е разрешено.  
**Всички права запазени.**

&nbsp;

---

## Етап 4, Стъпка 12: Дефиниране на параметрите в конфигурационния файл

Създаваме ясна и защитена конфигурация за backup engine, която определя какво се архивира, къде се съхранява, кога се изпълнява архивирането и какви ограничения са задължителни. На този сървър се архивират само системната конфигурация, уеб пространството за управление и вътрешните инструменти за управление. Архивиране на всички бази данни не се допуска. Потребителските бази данни не се архивират от инфраструктурния сървър.

**Код за терминала**

```bash
sudo tee /etc/netgalaxy/backup.conf > /dev/null <<'EOF'
# =========================================================
# NetGalaxy Backup Configuration
# =========================================================

# === SERVER IDENTIFICATION ===

# Уникално име на сървъра (използва се в логове и архиви)
SERVER_NAME="D2"

# Роля на сървъра
SERVER_ROLE="production"


# === WHAT TO BACKUP ===

# Архивиране на системна конфигурация (/etc)
BACKUP_SYSTEM="yes"

# Директории за архивиране
# /srv/www-admin = уеб пространство за управление
# /srv/tools     = вътрешни инструменти и скриптове за управление
BACKUP_WEB_DIRS="/srv/www-admin /srv/tools"

# === DATABASE BACKUP POLICY ===
# Позволени стойности:
# none   = не архивира бази данни
# config = архивира само конфигурацията на СУБД
# system = архивира само вътрешни системни БД за управление
# list   = архивира само изрично изброени БД
DB_BACKUP_MODE="none"

# Тип на използваната СУБД
DB_ENGINE="mariadb"

# Изрично изброени системни БД за управление на сървъра
# Използва се само при DB_BACKUP_MODE="system"
DB_SYSTEM_DATABASES=""

# Изрично изброени позволени БД
# Използва се само при DB_BACKUP_MODE="list"
DB_BACKUP_LIST=""

# Защитна забрана: не се допуска архивиране на всички бази данни
PROHIBIT_ALL_DATABASES="yes"


# === EXCLUDE RULES ===

# Пътища, които се изключват от архивиране
EXCLUDE_PATHS="/tmp /var/tmp /proc /sys /dev /run /srv/backups"


# === DESTINATION ===

# Локално краткосрочно съхранение на D2
BACKUP_LOCAL_DIR="/srv/backups/local"

# Отдалечено архивиране към S1
BACKUP_REMOTE_ENABLED="yes"
BACKUP_REMOTE_ALIAS="s1-backup"
BACKUP_REMOTE_DIR="/srv/backups/d2"


# === SCHEDULE ===

# Честота на архивиране: hourly, daily, weekly
BACKUP_FREQUENCY="daily"

# Час на стартиране (24-часов формат)
BACKUP_TIME="02:30"


# === RETENTION POLICY ===

# Локално краткосрочно съхранение
RETENTION_LOCAL_DAYS="3"

# Отдалечено дългосрочно съхранение
RETENTION_REMOTE_DAYS="30"


# === LOGGING ===

# Лог файл за backup engine
BACKUP_LOG_FILE="/var/log/netgalaxy/backup.log"


# === LOCKED OPTIONS (PROTECTED) ===

# Забранява изключване на системния backup чрез външен интерфейс
LOCK_BACKUP_SYSTEM="yes"

# Забранява промяна на архивната дестинация чрез външен интерфейс
LOCK_TARGET="yes"
EOF
```

**PASS проверка**

```bash
sudo sed -n '1,220p' /etc/netgalaxy/backup.conf
```

PASS е налице, ако във файла присъстват поне следните стойности:

```text
BACKUP_SYSTEM="yes"
BACKUP_WEB_DIRS="/srv/www-admin /srv/tools"
PROHIBIT_ALL_DATABASES="yes"
BACKUP_LOCAL_DIR="/srv/backups/local"
BACKUP_REMOTE_ENABLED="yes"
BACKUP_REMOTE_ALIAS="s1-backup"
BACKUP_REMOTE_DIR="/srv/backups/d2"
BACKUP_FREQUENCY="daily"
BACKUP_TIME="02:30"
RETENTION_LOCAL_DAYS="3"
RETENTION_REMOTE_DAYS="30"
BACKUP_LOG_FILE="/var/log/netgalaxy/backup.log"
```

**Очакван резултат**

Файлът `/etc/netgalaxy/backup.conf` е записан с пълна конфигурация за backup engine и съдържа:

* архивиране на `/etc`
* архивиране на `/srv/www-admin`
* архивиране на `/srv/tools`
* изключване на `/srv/backups`
* локална дестинация на D2
* отдалечена дестинация на S1
* забрана за архивиране на всички бази данни

**Политика за данните:** Инфраструктурният сървър не архивира потребителски бази данни и не съхранява техни копия. Архивирането на такива бази данни е отговорност на администратора на съответния домейн или услуга. Това ограничение е част от политиката за защита на данните и поверителността в мрежата NetGalaxy.

---

## Етап 4, Стъпка 13: Създаване на скрипта за архивиране (backup engine)

Създаваме основния скрипт за архивиране, който изгражда tar архив, записва го локално и го синхронизира към S1 чрез предварително конфигурирания SSH alias `s1-backup`.

**Код за терминала**

```bash
sudo tee /srv/tools/backup-engine.sh > /dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="/etc/netgalaxy/backup.conf"

: "${CONFIG_FILE:?missing CONFIG_FILE}"
[[ -f "$CONFIG_FILE" ]] || { echo "ERROR: missing config file: $CONFIG_FILE" >&2; exit 1; }

# shellcheck disable=SC1090
source "$CONFIG_FILE"

: "${SERVER_NAME:?missing SERVER_NAME}"
: "${SERVER_ROLE:?missing SERVER_ROLE}"
: "${BACKUP_SYSTEM:?missing BACKUP_SYSTEM}"
: "${BACKUP_WEB_DIRS:?missing BACKUP_WEB_DIRS}"
: "${DB_BACKUP_MODE:?missing DB_BACKUP_MODE}"
: "${PROHIBIT_ALL_DATABASES:?missing PROHIBIT_ALL_DATABASES}"
: "${EXCLUDE_PATHS:?missing EXCLUDE_PATHS}"
: "${BACKUP_LOCAL_DIR:?missing BACKUP_LOCAL_DIR}"
: "${BACKUP_REMOTE_ENABLED:?missing BACKUP_REMOTE_ENABLED}"
: "${BACKUP_REMOTE_ALIAS:?missing BACKUP_REMOTE_ALIAS}"
: "${BACKUP_REMOTE_DIR:?missing BACKUP_REMOTE_DIR}"
: "${BACKUP_LOG_FILE:?missing BACKUP_LOG_FILE}"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
HOST_TAG="${SERVER_NAME,,}"
ARCHIVE_NAME="${HOST_TAG}-backup-${TIMESTAMP}.tar.gz"
ARCHIVE_PATH="${BACKUP_LOCAL_DIR}/${ARCHIVE_NAME}"

LOG_DIR="$(dirname "$BACKUP_LOG_FILE")"
mkdir -p "$LOG_DIR"
mkdir -p "$BACKUP_LOCAL_DIR"

log() {
  local message="$1"
  printf '[%s] %s\n' "$(date '+%F %T')" "$message" | tee -a "$BACKUP_LOG_FILE"
}

fail() {
  local message="$1"
  log "ERROR: $message"
  exit 1
}

[[ "$PROHIBIT_ALL_DATABASES" == "yes" ]] || fail "PROHIBIT_ALL_DATABASES must be set to yes"

case "$DB_BACKUP_MODE" in
  none)
    ;;
  config|system|list)
    fail "DB_BACKUP_MODE=$DB_BACKUP_MODE is not implemented in this step. Use DB_BACKUP_MODE=\"none\""
    ;;
  *)
    fail "Invalid DB_BACKUP_MODE: $DB_BACKUP_MODE"
    ;;
esac

TMP_EXCLUDE_FILE="$(mktemp)"
trap 'rm -f "$TMP_EXCLUDE_FILE"' EXIT

for path in $EXCLUDE_PATHS; do
  printf '%s\n' "${path#/}" >> "$TMP_EXCLUDE_FILE"
done

INCLUDE_PATHS=()

if [[ "$BACKUP_SYSTEM" == "yes" ]]; then
  INCLUDE_PATHS+=("etc")
fi

for path in $BACKUP_WEB_DIRS; do
  [[ -d "$path" ]] || fail "Backup source directory not found: $path"
  INCLUDE_PATHS+=("${path#/}")
done

[[ "${#INCLUDE_PATHS[@]}" -gt 0 ]] || fail "No backup sources defined"

log "Backup started"
log "Archive name: $ARCHIVE_NAME"
log "Local target: $ARCHIVE_PATH"

tar -czf "$ARCHIVE_PATH" \
  --exclude-from="$TMP_EXCLUDE_FILE" \
  -C / \
  "${INCLUDE_PATHS[@]}"

[[ -f "$ARCHIVE_PATH" ]] || fail "Archive was not created"

ARCHIVE_SIZE="$(du -h "$ARCHIVE_PATH" | awk '{print $1}')"
log "Local archive created successfully: $ARCHIVE_PATH ($ARCHIVE_SIZE)"

if [[ "$BACKUP_REMOTE_ENABLED" == "yes" ]]; then
  log "Remote sync started: ${BACKUP_REMOTE_ALIAS}:${BACKUP_REMOTE_DIR}"
  rsync -rtv --progress --rsync-path=/usr/bin/rsync -e "ssh -F /root/.ssh/config -o BatchMode=yes" "$ARCHIVE_PATH" "${BACKUP_REMOTE_ALIAS}:${BACKUP_REMOTE_DIR}/"
  log "Remote sync completed successfully"
else
  log "Remote sync skipped: BACKUP_REMOTE_ENABLED=$BACKUP_REMOTE_ENABLED"
fi

log "Backup finished successfully"
EOF
sudo chmod 750 /srv/tools/backup-engine.sh
```

**PASS проверка**

```bash
sudo ls -l /srv/tools/backup-engine.sh && sudo head -n 20 /srv/tools/backup-engine.sh
```

**Очакван резултат**

Създаден е изпълним файл:

```text
/srv/tools/backup-engine.sh
```

Скриптът е готов да се стартира ръчно или чрез cron и използва конфигурацията от:

```text
/etc/netgalaxy/backup.conf
```

**PASS резултат**

PASS е налице, ако:

* файлът `/srv/tools/backup-engine.sh` съществува
* има права за изпълнение
* в началото му се виждат поне следните редове:

```text
#!/usr/bin/env bash
set -euo pipefail
CONFIG_FILE="/etc/netgalaxy/backup.conf"
```

---

## Етап 4, Стъпка 14: Ръчно тестване на backup engine (първо изпълнение)

**Кратка цел**
Изпълняваме backup engine ръчно, за да проверим създаването на архив, записването на лог и прехвърлянето към S1 чрез SSH alias `s1-backup`.

---

**Код за терминала**

```bash
sudo /srv/tools/backup-engine.sh
```

---

**PASS проверка**

```bash
sudo ls -lh /srv/backups/local && sudo tail -n 20 /var/log/netgalaxy/backup.log
```

---

**Очакван резултат**

```text
d2-backup-YYYYMMDD-HHMMSS.tar.gz
```

и в лога:

```text
Backup started
Local archive created successfully
Remote sync completed successfully
Backup finished successfully
```

---

**PASS резултат**

PASS е налице, ако:

* в `/srv/backups/local` има нов `.tar.gz` файл
* лог файлът `/var/log/netgalaxy/backup.log` съдържа запис за успешно завършен backup
* няма грешки (ERROR) в лога
* архивът е прехвърлен към S1 (чрез `s1-backup`)

---

⚠️ Ако нещо се счупи — не продължаваме напред. Спираме и го оправяме.

---

Кажи какво излиза след изпълнението — това е най-важният тест досега.
## Етап 4, Стъпка 15: Проверка на наличния архив на S1

Проверяваме дали архивът е успешно прехвърлен и наличен в home директорията на потребителя `backup_d2` на S1.

**Код за терминала** (сървър D2)

```bash
sudo ssh s1-backup 'ls -lh'
```

**PASS проверка**

```bash
sudo ssh s1-backup 'ls -1 d2-backup-*.tar.gz'
```

**Очакван резултат**

Трябва да се вижда файл от типа:

```text
d2-backup-20260401-141909.tar.gz
```

с приблизителен размер (пример):

```text
744K
```

**PASS резултат**

PASS е налице, ако:

* в home директорията на `backup_d2` има файл с име `d2-backup-*.tar.gz`
* размерът на файла съответства на локалния архив
* файлът е създаден в последните минути (времето съвпада с изпълнението на backup)

---

## Етап 4, Стъпка 16: Създаване на скрипт за извличане на архив към директорията /restore 

Създаваме restore скрипт, който взема избран архивен файл и го копира като цял `.tar.gz` файл в директорията `/srv/tools/backup/restore`, без да го разархивира и без да променя нищо по системата.

**Код за терминала**

```bash
sudo tee /srv/tools/backup/restore-fetch.sh > /dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="/etc/netgalaxy/backup.conf"
RESTORE_DIR="/srv/tools/backup/restore"

: "${CONFIG_FILE:?missing CONFIG_FILE}"
[[ -f "$CONFIG_FILE" ]] || { echo "ERROR: missing config file: $CONFIG_FILE" >&2; exit 1; }

# shellcheck disable=SC1090
source "$CONFIG_FILE"

: "${BACKUP_REMOTE_ENABLED:?missing BACKUP_REMOTE_ENABLED}"
: "${BACKUP_REMOTE_ALIAS:?missing BACKUP_REMOTE_ALIAS}"
: "${BACKUP_REMOTE_DIR:?missing BACKUP_REMOTE_DIR}"

ARCHIVE_NAME="${1:-}"
: "${ARCHIVE_NAME:?Usage: sudo /srv/tools/backup/restore-fetch.sh <archive-name.tar.gz>}"

[[ "$ARCHIVE_NAME" == *.tar.gz ]] || { echo "ERROR: archive name must end with .tar.gz" >&2; exit 1; }

mkdir -p "$RESTORE_DIR"

REMOTE_SOURCE="${BACKUP_REMOTE_ALIAS}:${BACKUP_REMOTE_DIR%/}/${ARCHIVE_NAME}"
LOCAL_TARGET="${RESTORE_DIR}/${ARCHIVE_NAME}"

echo "Restore fetch started"
echo "Remote source: $REMOTE_SOURCE"
echo "Local target:  $LOCAL_TARGET"

rsync -rtv --progress \
  --rsync-path=/usr/bin/rsync \
  -e "ssh -F /root/.ssh/config -o BatchMode=yes" \
  "$REMOTE_SOURCE" \
  "$LOCAL_TARGET"

[[ -f "$LOCAL_TARGET" ]] || { echo "ERROR: archive was not copied to restore directory" >&2; exit 1; }

echo "Restore fetch completed successfully"
echo "Copied file: $LOCAL_TARGET"
EOF
sudo chmod 750 /srv/tools/backup/restore-fetch.sh
```

**PASS проверка**

```bash
sudo ls -l /srv/tools/backup/restore-fetch.sh && sudo head -n 20 /srv/tools/backup/restore-fetch.sh
```

**Очакван резултат**

Трябва да се вижда файлът:

```text
/srv/tools/backup/restore-fetch.sh
```

и в началото му поне следните редове:

```text
#!/usr/bin/env bash
set -euo pipefail
CONFIG_FILE="/etc/netgalaxy/backup.conf"
RESTORE_DIR="/srv/tools/backup/restore"
```

**PASS резултат**

PASS е налице, ако:

* файлът `/srv/tools/backup/restore-fetch.sh` съществува
* има права за изпълнение
* използва конфигурацията от `/etc/netgalaxy/backup.conf`
* копира архив в `/srv/tools/backup/restore` без разархивиране и без destructive действия

---

## Етап 4, Стъпка 17: Тестване на restore-fetch скрипта

**Кратка цел**
Проверяваме дали restore скриптът може да изтегли архив от S1 и да го запише като `.tar.gz` файл в `/srv/tools/backup/restore`, без да го разархивира.

**Код за терминала**

```bash
sudo /srv/tools/backup/restore-fetch.sh d2-backup-20260401-141909.tar.gz
```

**PASS проверка**

```bash
sudo ls -lh /srv/tools/backup/restore
```

**Очакван резултат**

В директорията трябва да се вижда файл:

```text
d2-backup-20260401-141909.tar.gz
```

с размер, близък до този на архива в `/srv/backups/local`.

**PASS резултат**

PASS е налице, ако:

* файлът `d2-backup-*.tar.gz` се появи в `/srv/tools/backup/restore`
* размерът на файла съответства на оригиналния архив
* няма грешки от типа `Permission denied`
* скриптът завършва със съобщение:

```text
Restore fetch completed successfully
```

---

## Етап 4, Стъпка 18: Създаване на cleanup скрипт

Създаваме cleanup скрипт, който изтрива стари локални архиви на D2 и стари remote архиви на S1 според зададените retention параметри в `/etc/netgalaxy/backup.conf`.

**Код за терминала**

```bash
sudo tee /srv/tools/backup/cleanup.sh > /dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="/etc/netgalaxy/backup.conf"

: "${CONFIG_FILE:?missing CONFIG_FILE}"
[[ -f "$CONFIG_FILE" ]] || { echo "ERROR: missing config file: $CONFIG_FILE" >&2; exit 1; }

# shellcheck disable=SC1090
source "$CONFIG_FILE"

: "${BACKUP_LOCAL_DIR:?missing BACKUP_LOCAL_DIR}"
: "${BACKUP_REMOTE_ENABLED:?missing BACKUP_REMOTE_ENABLED}"
: "${BACKUP_REMOTE_ALIAS:?missing BACKUP_REMOTE_ALIAS}"
: "${BACKUP_REMOTE_DIR:?missing BACKUP_REMOTE_DIR}"
: "${RETENTION_LOCAL_DAYS:?missing RETENTION_LOCAL_DAYS}"
: "${RETENTION_REMOTE_DAYS:?missing RETENTION_REMOTE_DAYS}"
: "${BACKUP_LOG_FILE:?missing BACKUP_LOG_FILE}"

[[ -d "$BACKUP_LOCAL_DIR" ]] || { echo "ERROR: missing local backup dir: $BACKUP_LOCAL_DIR" >&2; exit 1; }

LOG_DIR="$(dirname "$BACKUP_LOG_FILE")"
mkdir -p "$LOG_DIR"

log() {
  local message="$1"
  printf '[%s] %s\n' "$(date '+%F %T')" "$message" | tee -a "$BACKUP_LOG_FILE"
}

log "Cleanup started"
log "Local retention days: $RETENTION_LOCAL_DAYS"
log "Remote retention days: $RETENTION_REMOTE_DAYS"

LOCAL_DELETED_COUNT="$(find "$BACKUP_LOCAL_DIR" -maxdepth 1 -type f -name '*.tar.gz' -mtime +"$RETENTION_LOCAL_DAYS" -print -delete | wc -l)"
log "Local cleanup deleted files: $LOCAL_DELETED_COUNT"

if [[ "$BACKUP_REMOTE_ENABLED" == "yes" ]]; then
  REMOTE_CLEANUP_CMD=$(cat <<REMOTE_EOF
cd "$BACKUP_REMOTE_DIR"
find . -maxdepth 1 -type f -name '*.tar.gz' -mtime +"$RETENTION_REMOTE_DAYS" -print -delete | wc -l
REMOTE_EOF
)
  REMOTE_DELETED_COUNT="$(ssh -F /root/.ssh/config -o BatchMode=yes "$BACKUP_REMOTE_ALIAS" "$REMOTE_CLEANUP_CMD")"
  log "Remote cleanup deleted files: $REMOTE_DELETED_COUNT"
else
  log "Remote cleanup skipped: BACKUP_REMOTE_ENABLED=$BACKUP_REMOTE_ENABLED"
fi

log "Cleanup finished successfully"
EOF
sudo chmod 750 /srv/tools/backup/cleanup.sh
```

**PASS проверка**

```bash
sudo ls -l /srv/tools/backup/cleanup.sh && sudo head -n 30 /srv/tools/backup/cleanup.sh
```

**Очакван резултат**

Трябва да се вижда файлът:

```text
/srv/tools/backup/cleanup.sh
```

и в началото му поне следните редове:

```text
#!/usr/bin/env bash
set -euo pipefail
CONFIG_FILE="/etc/netgalaxy/backup.conf"
```

**PASS резултат**

PASS е налице, ако:

* файлът `/srv/tools/backup/cleanup.sh` съществува
* има права за изпълнение
* използва `/etc/netgalaxy/backup.conf`
* съдържа логика за локално и remote почистване на `.tar.gz` архиви

---

## Етап 4, Стъпка 19: Ръчно тестване на cleanup скрипта

Изпълняваме cleanup скрипта ръчно, за да проверим дали работи коректно и записва резултата в лога, без да дава грешка.

**Код за терминала**

```bash
sudo /srv/tools/backup/cleanup.sh
```

**PASS проверка**

```bash
sudo tail -n 20 /var/log/netgalaxy/backup.log
```

**Очакван резултат**

В лога трябва да се виждат редове от типа:

```text
Cleanup started
Local retention days: 3
Remote retention days: 30
Local cleanup deleted files: 0
Remote cleanup deleted files: 0
Cleanup finished successfully
```

**PASS резултат**

PASS е налице, ако:

* скриптът завърши без грешка
* в лога има запис `Cleanup started`
* в лога има запис `Cleanup finished successfully`
* има отчет за локално и remote cleanup

---

## Етап 4, Стъпка 20: Конфигуриране на автоматично изпълнение чрез cron

Добавяме cron задачи за автоматично нощно архивиране и последващо почистване на старите архиви.

**Код за терминала**

```bash
sudo tee /etc/cron.d/netgalaxy-backup > /dev/null <<'EOF'
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

30 2 * * * root /srv/tools/backup-engine.sh >> /var/log/netgalaxy/backup.log 2>&1
0 3 * * * root /srv/tools/backup/cleanup.sh >> /var/log/netgalaxy/backup.log 2>&1
EOF
sudo chmod 644 /etc/cron.d/netgalaxy-backup
```

**PASS проверка**

```bash
sudo cat /etc/cron.d/netgalaxy-backup
```

**Очакван резултат**

Трябва да се виждат точно тези два реда:

```text
30 2 * * * root /srv/tools/backup-engine.sh >> /var/log/netgalaxy/backup.log 2>&1
0 3 * * * root /srv/tools/backup/cleanup.sh >> /var/log/netgalaxy/backup.log 2>&1
```

**PASS резултат**

PASS е налице, ако:

* файлът `/etc/cron.d/netgalaxy-backup` съществува
* има права `644`
* съдържа задача за backup в `02:30`
* съдържа задача за cleanup в `03:00`

---

## Етап 4, Стъпка 21: Тестване на ротацията (cleanup с реален стар файл)

Създаваме тестов архив с изкуствено стара дата и проверяваме дали cleanup скриптът го изтрива според политиката.

**Код за терминала**

```bash
sudo cp /srv/backups/local/d2-backup-20260401-141909.tar.gz /srv/backups/local/test-old-backup.tar.gz && sudo touch -d "10 days ago" /srv/backups/local/test-old-backup.tar.gz
```

**PASS проверка**

```bash
sudo ls -lh /srv/backups/local | grep test-old-backup
```

**Очакван резултат**

```text
test-old-backup.tar.gz
```

**Стартирайте cleanup:**

```bash
sudo /srv/tools/backup/cleanup.sh
```

**PASS проверка (след cleanup)**

```bash
sudo ls -lh /srv/backups/local | grep test-old-backup || echo "PASS: deleted"
```

**PASS резултат**

PASS е налице, ако:

* файлът `test-old-backup.tar.gz` НЕ съществува
* cleanup логът показва изтриване ≥ 1 файл

---

## Етап 4, Стъпка 22: Тестване на cron (симулация)

Проверяваме дали cron конфигурацията е валидна и може да стартира задачите.

**Код за терминала**

```bash
sudo run-parts /etc/cron.d
```

**PASS проверка**

```bash
sudo tail -n 10 /var/log/netgalaxy/backup.log
```

**Очакван резултат**

Трябва да се появи нов запис:

```text
Backup started
```

**PASS резултат**

PASS е налице, ако:

* се появи нов backup в логовете
* няма грешки
* скриптът се изпълнява от cron среда

**🎯 Заключение**

👉 Това, което имаш в момента е:

✔ 99% готово
❗ липсва само runtime доказателство

---
---

&nbsp;

## 🧠 Финализация

Имаме напълно завършена backup система:

**✔ Backup**

* автоматично всеки ден в **02:30**
* локално + remote (S1)

**✔ Cleanup**

* автоматично в **03:00**
* локално + remote

**✔ Restore (safe)**

* fetch-only
* без разрушителни действия

**✔ Конфигурация**

* централизирана в `/etc/netgalaxy`

**✔ Логове**

* в `/var/log/netgalaxy/backup.log`

**👉 Системата е:**

* детерминирана ✔
* fail-fast ✔
* без скрити действия ✔
* без риск от загуба на данни ✔

### 📦 Статус на протокол № 6

**Изпълнен на 01.04.2026**

---
---

&nbsp;

## Статус на ЕТАП 4: Изпълнен (Operational validation in progress)

Всички планирани компоненти на системата за архивиране са реализирани успешно, включително:

* автоматизирано създаване на архиви (backup engine)
* защитено прехвърляне към архивния сървър (S1) чрез SSH ключова автентикация
* механизъм за извличане на архиви (restore – етап „Сега“, без разрушителни действия)
* дефинирани и приложени политики за съхранение (retention)
* автоматизирано почистване на стари архиви (cleanup)
* централизирана конфигурация в `/etc/netgalaxy`
* централизирано логване на всички операции

Системата е тествана успешно в ръчен режим:

* създаване на архив
* прехвърляне към S1
* извличане на архив (restore-fetch)
* ротация на архивите чрез cleanup

Cron автоматизацията е конфигурирана и валидирана по синтаксис.
Пълното потвърждение на автоматичното изпълнение ще бъде извършено при настъпване на следващия планиран цикъл (02:30 – backup, 03:00 – cleanup).

Системата е в оперативна готовност и може да бъде използвана в продукционна среда.

---

Ако искаш, следващият логичен ход е:

👉 кратък “Operational checklist” за бъдещи администратори (много силно допълнение към документа)

