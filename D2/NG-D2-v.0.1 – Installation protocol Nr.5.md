# NetGalaxy Network

## Инсталационен протокол № 5

### Етап 5 - Създаване на системата за архивиране на данни

---

### Информация за документа

**Проект:** NetGalaxy  
**Document ID:** NG-D2-v.0.1 – Installation protocol Nr.5.md  
**Дата:** 31.03.2026  
**Заглавие:** Инсталационен протокол № 5  
**Задачи за изпълнение:**

  * Създаване на структура за архивната система (директории за скриптове, временни архиви и логове)
  * Създаване на конфигурационен файл за управление на архивирането (backup.conf)
  * Създаване на директория за архиви на сървъра S1
  * Създаване на потребител за архивиране на сървъра S1
  * Добавяне на сървъра D2 в Tailscale мрежата
  * Осигуряване на постоянна връзка чрез Tailscale
  * Създаване на SSH ключ за достъп от D2 към S1
  * Подготовка на потребителя `backup_d2` за работа с SSH ключове в Synology
  * Конфигуриране на SSH ключа за оторизация в S1
  * Забрана на вход с парола за потребителя `backup_d2`
  * Конфигуриране на бърза SSH връзка от D2 към S1
  
📌 Системата за архивиране се изгражда като независим механизъм и не зависи от NetGalaxyCP  
📌 На този етап конфигурацията се управлява чрез файл, а не чрез интерфейс
  
**Срок за изпълнение:** 31.03.2026  
**Изпълнител:** Илко Йорданов  
**Статус:** Изпълнен на 31.03.2026  
**Локация на документа:** GitHub Repository: servers/D2/NG-D2-v.0.1 – Installation protocol Nr.5.md  
**Контакт:** 📧 [yordanov.netgalaxy@gmail.com](mailto:yordanov.netgalaxy@gmail.com)  

**Copyright:** © 2026 NetGalaxy™ by Ilko Iordanov. All rights reserved.  
***Лиценз:*** Този документ е част от проекта NetGalaxy. Предназначен е само за вътрешно ползване в рамките на мрежата NetGalaxy. Разпространението или публикуването извън мрежата не е разрешено.  
**Всички права запазени.**

&nbsp;

---

## Етап 5, Стъпка 1: Създаване на структура за архивната система

Създаваме основната структура на системата за архивиране, която включва директории за скриптове, конфигурация, временни архиви и логове.

**Код за терминала**

```bash
sudo mkdir -p /srv/tools/backup/lib
sudo mkdir -p /srv/tools/backup/restore
sudo mkdir -p /etc/netgalaxy
sudo mkdir -p /srv/backups/local
sudo mkdir -p /srv/backups/tmp
sudo mkdir -p /srv/backups/logs

sudo touch /srv/tools/backup/backup.sh
sudo touch /srv/tools/backup/restore.sh
sudo touch /srv/tools/backup/cleanup.sh

sudo touch /srv/tools/backup/lib/config.sh
sudo touch /srv/tools/backup/lib/logger.sh
sudo touch /srv/tools/backup/lib/rsync.sh
sudo touch /srv/tools/backup/lib/archive.sh
sudo touch /srv/tools/backup/lib/validate.sh

sudo touch /etc/netgalaxy/backup.conf

sudo touch /srv/backups/logs/backup.log
sudo touch /srv/backups/logs/restore.log
sudo touch /srv/backups/logs/cleanup.log
```

**PASS проверка**

```bash
sudo ls -R /srv/tools/backup
sudo ls -R /srv/backups
sudo ls /etc/netgalaxy
```

**Очакван резултат**

Създадена е следната структура:

```text
/srv/tools/backup/
├── backup.sh
├── restore.sh
├── cleanup.sh
├── lib/
│   ├── config.sh
│   ├── logger.sh
│   ├── rsync.sh
│   ├── archive.sh
│   └── validate.sh

/etc/netgalaxy/
├── backup.conf

/srv/backups/
├── tmp/
├── logs/

/srv/backups/logs/
├── backup.log
├── restore.log
├── cleanup.log
```

---

## Етап 5, Стъпка 2: Създаване на конфигурационен файл за управление на архивирането

Създаваме конфигурационен файл, който ще определя параметрите на архивната система.

**Код за терминала**

```bash
sudo tee /etc/netgalaxy/backup.conf > /dev/null << 'EOF'
# =========================================================
# NetGalaxy Backup Configuration
# =========================================================

# === SERVER IDENTIFICATION ===

# Уникално име на сървъра (използва се в логове и архиви)
SERVER_NAME="D2"

# Роля на сървъра (напр. production, staging, dns, db)
SERVER_ROLE="production"


# === WHAT TO BACKUP ===

# Архивиране на системна конфигурация (/etc)
# yes = включено, no = изключено
BACKUP_SYSTEM="yes"

# Директории с уеб съдържание (разделени с интервал)
# пример: "/srv/www-admin /srv/sites"
BACKUP_WEB_DIRS=""

# Списък с бази данни (разделени с интервал)
# празно = всички бази
BACKUP_DATABASES=""


# === EXCLUDE RULES ===

# Пътища, които се изключват от архивиране
# използва се за временни и системни директории
EXCLUDE_PATHS="/tmp /var/tmp /proc /sys /dev"


# === DESTINATION ===

# Адрес на архивния сървър (S1)
# формат: user@host:/path
BACKUP_TARGET_S1="user@s1:/srv/backups/d2"


# === SCHEDULE ===

# Честота на архивиране
# възможни стойности: hourly, daily, weekly
BACKUP_FREQUENCY="daily"


# === RETENTION POLICY ===

# Краткосрочно съхранение (в дни)
# използва се за бързо възстановяване
RETENTION_DAYS_SHORT="3"

# Дългосрочно съхранение (в дни)
# използва се за исторически архиви
RETENTION_DAYS_LONG="30"


# === LOCKED OPTIONS (PROTECTED) ===

# Забранява изключване на системния backup чрез външен интерфейс
LOCK_BACKUP_SYSTEM="yes"

# Забранява промяна на архивния сървър (S1)
LOCK_TARGET="yes"

EOF
```

**PASS проверка**

```bash
sudo cat /etc/netgalaxy/backup.conf
```

**Очакван резултат**

```text
# NetGalaxy Backup Configuration

# === SERVER ===
SERVER_NAME="D2"
SERVER_ROLE="production"

# === WHAT TO BACKUP ===
BACKUP_SYSTEM="yes"
BACKUP_WEB_DIRS=""
BACKUP_DATABASES=""

# === EXCLUDES ===
EXCLUDE_PATHS="/tmp /var/tmp /proc /sys /dev"

# === DESTINATION ===
BACKUP_TARGET_S1="user@s1:/srv/backups/d2"

# === SCHEDULE ===
BACKUP_FREQUENCY="daily"

# === RETENTION ===
RETENTION_DAYS_SHORT="3"
RETENTION_DAYS_LONG="30"

# === OPTIONS (LOCKED) ===
LOCK_BACKUP_SYSTEM="yes"
LOCK_TARGET="yes"
```

---

## Етап 5, Стъпка 3: Създаване на директория за архиви на сървъра S1

Създаваме основна директория за съхранение на архивите на сървъра S1 чрез графичния интерфейс на Synology DSM.

---

**Действия (през графичния интерфейс на Synology DSM)**

  1. Влезте в **Control Panel**
  2. Отворете контролния панел и изберете **Shared Folder**
  3. Натиснете бутона **Create**

---

**Основни настройки:**

  * **Name:** `backups_d2`
  * **Description:** D2 Backup Storage
  * **Location:** по подразбиране
  * ❌ Enable Recycle Bin (изключете тази опция)

  **Продължете с [Next]**

---

**Encryption:**

  * Оставете изключено

  **Продължете с [Next]**

---

**Confirm settings:**

  * Проверете въведената информация

  **Натиснете [Apply]**

---

**Permissions:**

  * Оставете навсякъде празно

  **Натиснете [OK]**

---

**PASS проверка**

В **Control Panel:** съществува папка `backups_d2`

---

## Етап 5, Стъпка 4: Създаване на потребител за архивиране на сървъра S1

Създаване на потребител в Synology (S1), който ще приема архивите от D2.

**Действия (през графичния интерфейс на Synology DSM)**

  1. Влезте в **Control Panel** на сървъра S1
  2. Отворете контролния панел и изберете **User**
  3. Натиснете бутона **Create → Create User**

**Основни настройки:**

  * **Name:** `backup_d2`
  * **Description:** Backup user for D2
  * **Email:** admin@netgalaxy.eu
  * **Password:** (Генерирайте силна парола) Ya^3komo^2:ffSL@

  **Продължете с [Next]**
  
---

**Joint to groups:**

  👉 Изберете `administrators`
  
  **Продължете с [Next]**

---

**Permissions:**

  * `Read/Write` → само за тази директория
  * `No access` → за всички останали

  **Продължете с [Next]**

  ---

**Quota setting**
  
  * Не слагайте квота засега
  
  **Продължете с [Next]**

---

**Application permissions:**

Забранете всичко на този екран:

  * rsync (Shared ...) **Allow**
  * **❌ Deny** - всичко друго

  **Продължете с [Next]**

---

**Speed Limit Setting**

  * Не променайте нищо

  **Продължете с [Next]**

---

**Confirm settings:**

  * Проверете настройките преди прилагането им

Завършете с **Apply**

---

**PASS проверка**

👉 Влезте в **Control Panel → User**

Проверете:

* съществува ли потребител `backup_d2`
* има ли достъп само до backup директорията
* няма достъп до други ресурси

---

**Очакван резултат**

Създаден е ограничен потребител на S1, който:

* има достъп само до директорията за архиви
* може да приема връзки от D2
* не може да достъпва други части на системата

---

## Етап 5, Стъпка 5: Добавяне на сървъра D2 в Tailscale мрежата

Добавяме сървъра D2 в Tailscale мрежата, за да осигурим защитена връзка със сървъра S1.

**Код за терминала (на D2)**

```bash
curl -fsSL https://tailscale.com/install.sh | sudo sh
```

```bash
sudo tailscale up
```

👉 Отворете линка, който се появява в терминала, и влезте с акаунта си.

**PASS проверка**

```bash
tailscale ip
```

**Очакван резултат**

Показва се IP адрес от вида:

```text
100.x.x.x
```

👉 Сървърът D2 вече е част от Tailscale мрежата и може да комуникира със S1.

---

## Етап 5, Стъпка 6: Осигуряване на постоянна връзка чрез Tailscale

Конфигурираме Tailscale така, че връзката да се въз## Етап 4, Стъпка 4: Създаване на SSH ключ за достъп от D2 към S1

Създаваме SSH ключ на сървъра D2, който ще се използва за удостоверяване към S1 без парола.

**Код за терминала**

```bash
ssh-keygen -t ed25519 -C "backup_d2@s1" -f ~/.ssh/id_ed25519_backup_d2 -N ""
```

**PASS проверка**

```bash
ls -l ~/.ssh/id_ed25519_backup_d2*
```

**Очакван резултат**

Създадени са два файла:

```text
~/.ssh/id_ed25519_backup_d2
~/.ssh/id_ed25519_backup_d2.pub
```

**Код за терминала (на D2)**

```bash id="ng6_1"
sudo systemctl enable tailscaled
sudo systemctl start tailscaled
```

```bash id="ng6_2"
sudo tailscale up --ssh
```

**PASS проверка**

```bash id="ng6_3"
tailscale status
```

**Очакван резултат**

* Сървърът D2 е в състояние **online**
* Виждате списък с устройства (включително S1)
* Има активен Tailscale IP от вида:

```text id="ng6_4"
100.x.x.x
```

---

## Етап 5, Стъпка 7: Създаване на SSH ключ за достъп от D2 към S1

Създаване на специфичен SSH ключ на сървъра D2, който ще се използва за автоматизирано удостоверяване към архивния сървър S1 без въвеждане на парола.

**Код за терминала**

```bash
ssh-keygen -t ed25519 -C "backup_d2@s1" -f ~/.ssh/id_ed25519_backup_d2 -N ""
```

**PASS проверка**

```bash
ls -l ~/.ssh/id_ed25519_backup_d2*
```

**Очакван резултат**

В директорията са създадени два файла (частен и публичен ключ):

```text
-rw------- 1 yordanov users 411 Mar 31 19:15 /home/yordanov/.ssh/id_ed25519_backup_d2
-rw-r--r-- 1 yordanov users  96 Mar 31 19:15 /home/yordanov/.ssh/id_ed25519_backup_d2.pub
```

---

## Етап 5, Стъпка 8: Подготовка на потребителя `backup_d2` за работа с SSH ключове в Synology

Конфигурираме home директорията и правата на потребителя `backup_d2`, така че SSH да приема ключова автентикация (изискване на StrictModes).

**Код за терминала (на S1)**

```bash
# Премахваме специфичните Synology ACL записи, които пречат на SSH
sudo synoacltool -del /volume1/homes/backup_d2
sudo synoacltool -del /volume1/homes/backup_d2/.ssh
sudo synoacltool -del /volume1/homes/backup_d2/.ssh/authorized_keys

# Налагаме стандартните Linux права (StrictModes compliance)
sudo chmod 711 /volume1/homes
sudo chmod 700 /volume1/homes/backup_d2
sudo chmod 700 /volume1/homes/backup_d2/.ssh
sudo chmod 600 /volume1/homes/backup_d2/.ssh/authorized_keys

# Задаваме правилната собственост
sudo chown backup_d2:users /volume1/homes/backup_d2
sudo chown -R backup_d2:users /volume1/homes/backup_d2/.ssh
```

**PASS проверка**

```bash
ls -ld /volume1/homes /volume1/homes/backup_d2 /volume1/homes/backup_d2/.ssh
ls -l /volume1/homes/backup_d2/.ssh/authorized_keys
```

**Очакван резултат**

```text
drwx--x--x  /volume1/homes
drwx------  /volume1/homes/backup_d2
drwx------  /volume1/homes/backup_d2/.ssh
-rw-------  authorized_keys (без знак "+" в края на правата)
```

**📌 Забележки:**  

1. Използва се реалният път /volume1/homes, а не символната връзка /var/services/homes, за да се избегнат рестрикциите на OpenSSH.

2. Използването на synoacltool -del премахва разширените права на Synology, които често стоят „над“ стандартните Linux права и блокират достъпа с ключове.

---

## Етап 5, Стъпка 9: Конфигуриране на SSH ключа за оторизация в S1

Добавяме публичния SSH ключ от **D2** към потребителя `backup_d2` в **S1**, използвайки реалния физически път и коректни права за съвместимост със Synology и OpenSSH.

**1. Копиране на ключа от D2**

```bash
cat ~/.ssh/id_ed25519_backup_d2.pub
```

👉 Копирайте целия изведен ред.

**2. Конфигуриране на S1 (Synology)**

```bash
sudo mkdir -p /volume1/homes/backup_d2/.ssh
echo "ПОСТАВЕТЕ_КОПИРАНИЯ_КЛЮЧ_ТУК" | sudo tee /volume1/homes/backup_d2/.ssh/authorized_keys > /dev/null
sudo chown -R backup_d2:users /volume1/homes/backup_d2/.ssh
sudo chmod 700 /volume1/homes/backup_d2/.ssh
sudo chmod 600 /volume1/homes/backup_d2/.ssh/authorized_keys
```

**3. Прилагане на промените**

Рестартирайте SSH услугата през DSM:

👉 Control Panel → Terminal & SNMP
👉 Изключете и включете SSH

**PASS проверка (от D2)**

```bash
ssh s1-backup
```

**Очакван резултат**

✔ Влизане без парола
✔ Достъп до shell на `backup_d2`

---

## Етап 5, Стъпка 10: Забрана на вход с парола за потребителя `backup_d2`

Ограничаваме достъпа до `backup_d2` само чрез SSH ключ, без да засягаме други потребители.

**Код за терминала (на S1)**

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d-%H%M%S)

sudo bash -c 'cat >> /etc/ssh/sshd_config <<EOF

Match User backup_d2
  PasswordAuthentication no
  PubkeyAuthentication yes
EOF'
```

**Прилагане на промените**

👉 Control Panel → Terminal & SNMP
👉 Изключете и включете SSH

**PASS проверка**

```bash
ssh -p 63316 -i ~/.ssh/id_ed25519_backup_d2 backup_d2@100.92.182.37
```

👉 трябва да влезе без парола

**Допълнителна проверка (забрана на парола)**

```bash
ssh -o PreferredAuthentications=password -p 63316 backup_d2@100.92.182.37
```

**Очакван резултат**

* ✔ вход с ключ → работи
* ❌ вход с парола → отказан

**🔐 Забележка**

👉 `backup_d2` вече е:

* достъпен само с ключ
* изолиран
* безопасен за backup операции

---

## Етап 5, Стъпка 11: Конфигуриране на бърза SSH връзка от D2 към S1

Проверяваме дали конфигурацията на ключовете е успешна и дали сървърът D2 може да се свърже към архивния сървър S1 автоматично, без въвеждане на парола.

**Код за терминала (на D2)**

```bash
mkdir -p ~/.ssh

cat > ~/.ssh/config << 'EOF'
Host s1-backup
    HostName 100.92.182.37
    Port 63316
    User backup_d2
    IdentityFile ~/.ssh/id_ed25519_backup_d2
    IdentitiesOnly yes
EOF

chmod 600 ~/.ssh/config
```

**PASS проверка**

```bash
ssh s1-backup
```

**Очакван резултат**

Терминалът показва, че вече сте влезли в **S1** като потребител `backup_d2`, без да е поискана парола:

```text
backup_d2@S1:~$
```

За връщане към D2 изпълнете:

```bash
exit
```

---

## Етап 5, Стъпка 12: ФИНАЛНА ПРОВЕРКА (BACKUP INFRASTRUCTURE AUDIT)

**🎯 Цел**
Валидиране на защитения канал и правата за запис между D2 и S1.

**12.1. Тест на мрежовата свързаност (Tailscale)**
```bash
tailscale ping 100.92.182.37
```
* **PASS:** Трябва да показва директна или ретранслирана връзка с ниско закъснение.

**12.2. Валидация на SSH Handshake (без парола)**
```bash
ssh -o BatchMode=yes s1-backup "echo 'Connection OK'"
```
* **PASS:** Трябва да върне `Connection OK`, без да иска парола или потвърждение.

**12.3. Тест на правата за запис в S1**
```bash
ssh s1-backup "touch /volume1/backups_d2/test_write"
ssh s1-backup "rm /volume1/backups_d2/test_write"
```
* **PASS:** Трябва да изпълни операциите без `Permission denied`.

**12.4. Одит на забраната за парола**
```bash
ssh -o PreferredAuthentications=password s1-backup
```
* **PASS:** Трябва веднага да върне `Permission denied (publickey)`.

---

## ОТЧЕТ ЗА ИЗПЪЛНЕНИЕ НА ЗАДАЧИТЕ

**Към Инсталационен протокол № 5 (NG-D2-v.0.1)**

**Дата на завършване:** 31.03.2026
**Изпълнител:** Илко Йорданов
**Обект:** Сървър D2 (IP: 65.108.12.147) + архивен сървър S1
**Статус:** <span style="color:green">✅ УСПЕШНО ЗАВЪРШЕН</span>

### 1. РЕЗЮМЕ НА ИЗПЪЛНЕНИЕТО / EXECUTIVE SUMMARY

Всички заложени задачи по Инсталационен протокол № 5 са изпълнени успешно съгласно стандартите на проекта NetGalaxy. Изградена е независима система за архивиране на данни, която не зависи от NetGalaxyCP и се управлява чрез конфигурационен файл. Осигурена е защитена връзка между **D2** и **S1** чрез **Tailscale** и **SSH ключова автентикация**, създадена е локална структура за архивиране, подготвен е отделен потребител за приемане на архивите на **Synology S1**, а входът с парола за този потребител е забранен.

Изпълнените дейности включват:

* **Backup framework:** директории, скриптове, библиотечни файлове, логове, временни архиви
* **Configuration layer:** централен файл `/etc/netgalaxy/backup.conf`
* **Remote storage:** отделна директория за архиви на S1
* **Secure transport:** Tailscale + SSH ключове
* **Synology hardening:** StrictModes-съвместими права и изчистване на ACL
* **Operational access:** бърза SSH връзка `s1-backup` от D2 към S1

### 2. ДЕТАЙЛЕН ПРЕГЛЕД НА ЗАДАЧИТЕ / TASK DETAILS

| Задача / Task                         | Статус | Коментар / Technical Note                                                                                          |
| :------------------------------------ | :----: | :----------------------------------------------------------------------------------------------------------------- |
| **Backup Structure Creation**         |  PASS  | Създадени са `/srv/tools/backup`, `/srv/backups/local`, `/srv/backups/tmp`, `/srv/backups/logs` и нужните файлове. |
| **Backup Configuration File**         |  PASS  | Създаден е `/etc/netgalaxy/backup.conf` с параметри за роля, target, retention и lock опции.                       |
| **Remote Backup Directory on S1**     |  PASS  | На S1 е създадена отделна директория `backups_d2` за приемане на архивите.                                         |
| **Backup User on S1**                 |  PASS  | Създаден е потребител `backup_d2` с ограничен достъп само до backup ресурса.                                       |
| **Tailscale Installation on D2**      |  PASS  | D2 е добавен успешно в Tailscale мрежата и получава Tailscale IP.                                                  |
| **Persistent Tailscale Connectivity** |  PASS  | `tailscaled` е активиран и стартира автоматично; връзката е постоянна.                                             |
| **SSH Key Generation**                |  PASS  | Създаден е отделен ключ `id_ed25519_backup_d2` за достъп от D2 към S1.                                             |
| **Synology SSH Key Preparation**      |  PASS  | Home директорията и `.ssh` са подготвени по правилата на OpenSSH StrictModes.                                      |
| **Authorized Key Deployment**         |  PASS  | Публичният ключ от D2 е добавен в `authorized_keys` на `backup_d2` в S1.                                           |
| **Password Login Disabled**           |  PASS  | За `backup_d2` е забранен вход с парола, разрешен е само достъп с ключ.                                            |
| **Quick SSH Alias Configuration**     |  PASS  | Конфигуриран е бърз SSH достъп чрез `Host s1-backup` в `~/.ssh/config`.                                            |
| **Operational Connection Test**       |  PASS  | От D2 се осъществява вход към S1 без парола чрез `ssh s1-backup`.                                                  |

### 3. ПОДДРЪЖКА НА ЕЗИЦИ / LANGUAGE COMPLIANCE

В съответствие с изискванията на NetGalaxy, документацията и работната среда поддържат:

1. **Български:** основен език на протокола и техническите описания
2. **English:** системни логове, shell output, SSH/Tailscale команди
3. **Русский:** поддръжка на локализационна съвместимост в рамките на проекта

### 4. КЛЮЧОВИ КОНФИГУРАЦИИ / KEY CONFIGURATIONS

За бъдещи справки и автоматизация са валидни следните параметри:

```bash
# Основна конфигурация на backup системата
/etc/netgalaxy/backup.conf

# Локална backup структура
/srv/tools/backup
/srv/backups/local
/srv/backups/tmp
/srv/backups/logs

# Логове
/srv/backups/logs/backup.log
/srv/backups/logs/restore.log
/srv/backups/logs/cleanup.log

# SSH ключ за backup връзката
~/.ssh/id_ed25519_backup_d2
~/.ssh/id_ed25519_backup_d2.pub

# Бърза SSH връзка от D2 към S1
ssh s1-backup

# Tailscale проверка
tailscale status
tailscale ip

# Проверка на backup потребителя в Synology
/volume1/homes/backup_d2
/volume1/homes/backup_d2/.ssh/authorized_keys
```

### 5. ЗАКЛЮЧЕНИЕ / CONCLUSION

Системата за архивиране на данни за **D2** е успешно изградена и подготвена за работа. Налице е независим механизъм за архивиране с ясна структура, централизирана конфигурация и защитен канал към архивния сървър **S1**. Връзката между двата сървъра е стабилизирана чрез **Tailscale**, а SSH достъпът е ограничен до ключова автентикация за специализирания потребител `backup_d2`.

Всички PASS проверки по протокола са преминати успешно. Системата е готова за следващия етап: реално изграждане и автоматизация на backup, restore и cleanup логиката.

**Подпис:** ............................
*(Илко Йорданов)*

**Copyright:** © 2026 NetGalaxy™ | **Confidential**

### 6. ДЕТАЙЛНА СПЕЦИФИКАЦИЯ НА ТРУДА (BY STEPS)

*Тази таблица служи за проверка на реално извършената дейност спрямо технологичния норматив.*

| Стъпка от Протокола | Описание на дейността                                |  Категория  | Норматив (мин) |
| :------------------ | :--------------------------------------------------- | :---------: | :------------: |
| **Стъпка 1**        | Създаване на локалната структура за backup системата | **Level B** |       10       |
| **Стъпка 2**        | Създаване на конфигурационен файл `backup.conf`      | **Level B** |       10       |
| **Стъпка 3**        | Създаване на backup директория на S1                 | **Level C** |       10       |
| **Стъпка 4**        | Създаване на потребител `backup_d2` в Synology       | **Level A** |       15       |
| **Стъпка 5**        | Добавяне на D2 в Tailscale                           | **Level B** |       10       |
| **Стъпка 6**        | Осигуряване на постоянна Tailscale връзка            | **Level B** |       10       |
| **Стъпка 7**        | Създаване на SSH ключ за достъп от D2 към S1         | **Level B** |       10       |
| **Стъпка 8**        | Подготовка на `backup_d2` за SSH ключове в Synology  | **Level A** |       15       |
| **Стъпка 9**        | Конфигуриране на `authorized_keys` в S1              | **Level A** |       10       |
| **Стъпка 10** | Забрана на вход с парола за `backup_d2` | Level A | 10 |
| **Стъпка 11** | Конфигуриране на SSH Alias (`s1-backup`) | Level B | 10 |
| **Стъпка 12** | Финална проверка (Audit)** | **Level A** | 20 |
| **Отчет** | Документиране и калкулиране на изпълнението | **Level B** | 15 |

---

### 7. СУМАРНА КАРТА НА ТРУДОВИЯ ПРИНОС (LABOR VALUE MAP)

| Група дейности | Категория труд | Общо мин. | Ставка (€/час) | Стойност (€) |
| :--- | :---: | :---: | :---: | :---: |
| **I. Базова структура и графика (DSM)** | **Level C** | **10** | **100.00** | **16.67** |
| **II. Конфигурация, Tailscale и отчет** | **Level B** | **65** | **150.00** | **162.50** |
| **III. Сигурност и Synology Hardening** | **Level A** | **70** | **250.00** | **291.67** |
| **ОБЩО ЗА ПРОТОКОЛА:** | | **145 мин.** | **Средна: 194.83** | **470.83 €** |

---

### 8. ДАННИ ЗА СМАРТ КОНТРАКТ (SMART CONTRACT PAYOUT)

* **ID на задачата:** NG-D2-INSTALL-P5
* **Обща стойност:** **470.83 €**
* **Разпределение (40/60):**
    * 💵 **Cash (40%):** **188.33 €**
    * 💎 **Tokens (60%):** **282.50 €**

---
