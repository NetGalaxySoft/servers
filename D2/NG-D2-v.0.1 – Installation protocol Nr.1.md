# NetGalaxy Network

## Инсталационен протокол № 1

---

### Информация за документа

**Проект:** NetGalaxy  
**Document ID:** NG-D2-v.0.1 – Installation protocol Nr.1.md  
**Дата:** 26.03.2026  
**Заглавие:** Инсталационен протокол № 1  
**Задачи за изпълнение:**

### Етап 1 - Конфигуриране на административния достъп

  * Инсталиране на операционна система
  * Инсталиране на служебния софтуер (основа за управление)
  * Инсталиране на уеб сървър и база данни
  * Инсталиране на системи за сигурност
  * Инсталиране на инструменти за наблюдение и логове
  * Инсталиране на инструменти за наблюдение на мрежата и диагностика
  * Инсталиране на PHP и приложения
  * Смяна на порта за SSH достъп
  * Тестване на обновявения достъп
  * Създаване на потребител с root права
  * Конфигуриране на SSH достъп за новия потребител

---

**Срок за изпълнение:** 01.04.2026  
**Изпълнител:** Илко Йорданов  
**Статус:** Изпълнен на 26.03.2026  
**Локация на документа:** GitHub Repository: servers/D2/NG-D2-v.0.1 – Installation protocol Nr.1  
**Контакт:** 📧 [yordanov.netgalaxy@gmail.com](mailto:yordanov.netgalaxy@gmail.com)  

**Copyright:** © 2026 NetGalaxy™ by Ilko Iordanov. All rights reserved.  
***Лиценз:*** Този документ е част от проекта NetGalaxy. Предназначен е само за вътрешно ползване в рамките на мрежата NetGalaxy. Разпространението или публикуването извън мрежата не е разрешено.  
**Всички права запазени.**

&nbsp;

---

## Етап 1, Стъпка 1: Инсталиране на операционна система

Инсталиране на Ubuntu 24.04.3 LTS (GNU/Linux 6.8.0-90-generic x86_64)

**1.1. Стартиране на инсталацията**

Код за терминала:

``` 
installimage
```

---

**1.2. Избор на ОС от списъка**

```
👉 Ubuntu-2404-noble-amd64-base
```

---

**1.3. Проверка и промяна на конфигурационния файл**

*Намерете и проверете във файла следните редове:*

```text
DRIVE1 /dev/nvme0n1
DRIVE2 /dev/nvme1n1
```

👉 Заменете ги с тези, ако не са така.

---

*Намерете и проветере следния ред:*

```text
SWRAID 1
```

👉 трябва да е **1**

✔ това означава RAID1 (огледало)
❌ ако е 0 → променете го на 1

---

*Проверете реда, определящ файловата система:*

```text
FILESYSTEM ext4
```

👉 Трябва да бъде **ext4** (най-стабилно)

---

*Проверете реда, определящ BOOTLOADER:*

```text
BOOTLOADER grub
```

👉 Трябва да бъде така.

---

**Какво НЕ трябва да променяте**

❌ не променяйте размери
❌ не пипайте RAID layout
❌ не добавяйте нищо

---

**Финално действие**

👉 Натиснете последователно:

```text
F10
```

→ Save
→ Yes

---

**Очакван резултат (PASS):**

&nbsp;

```
                Hetzner Online GmbH - installimage

  Your server will be installed now, this will take some minutes
             You can abort at any time with CTRL+C ...

         :  Reading configuration                           done 
         :  Loading image file variables                    done 
         :  Loading ubuntu specific functions               done 
   1/16  :  Deleting partitions                             done 
   2/16  :  Test partition size                             done 
   3/16  :  Creating partitions and /etc/fstab              done 
   4/16  :  Creating software RAID level 1                  done 
   5/16  :  Formatting partitions
         :    formatting /dev/md/0 with swap                done 
         :    formatting /dev/md/1 with ext3                done 
         :    formatting /dev/md/2 with ext4                done 
   6/16  :  Mounting partitions                             done 
   7/16  :  Sync time via ntp                               done 
         :  Importing public key for image validation       done 
   8/16  :  Validating image before starting extraction     done 
   9/16  :  Extracting image (local)                        done 
  10/16  :  Setting up network config                       done 
  11/16  :  Executing additional commands
         :    Setting hostname                              done 
         :    Generating new SSH keys                       done 
         :    Generating mdadm config                       done 
         :    Generating ramdisk                            done 
         :    Generating ntp config                         done 
  12/16  :  Setting up miscellaneous files                  done 
  13/16  :  Configuring authentication
         :    Setting root password                         done 
         :    Enabling SSH root login with password         done 
  14/16  :  Installing bootloader grub                      done 
  15/16  :  Running some ubuntu specific functions          done 
  16/16  :  Clearing log files                              done 

                  INSTALLATION COMPLETE
   You can now reboot and log in to your new system with the
 same credentials that you used to log into the rescue system.
```

---

### Етап 1, Стъпка 2. Рестартиране на системата и създаване на SSH ключове за root потребителя.

**2.1. Реатартиране на системата**

```
reboot
```

---

**2.2. Смяна на ключа за root:**

```
ssh-keygen -f ~/.ssh/known_hosts -R 65.108.12.147
```

*Какво прави това:*

👉 изтрива стария ключ (от rescue режима)  
👉 освобождава място за новия

*На съобщението:*

```
Are you sure you want to continue connecting?
```

👉 отговорете с `yes`.

---

### Етап 1, Стъпка 3 – Обновяване на системата

Актуализиране на всички пакети до последните стабилни версии.

**Код за изпълнение**

```bash
sudo apt update && sudo apt -y upgrade
```

** Очакван резултат**

* списъкът с пакети се обновява
* наличните пакети се ъпгрейдват
* няма грешки

**PASS проверка**

```bash
sudo apt update | grep -i "up to date"
```

*Очакван резултат:*

```
All packages are up to date.
```

***Важно (малко, но съществено)***

Ако видите:

```text
*** System restart required ***
```

👉 НЕ рестартирайте системата  
👉 ще направите това контролирано в следващия етап на конфигурацията

---

## Етап 1, Стъпка 2: Инсталиране на служебния софтуер (основа за управление)

Инсталираме базовите инструменти за редактиране, файлова работа, наблюдение, заявки и работа с Git.

  * Nano – базов редактор
  * Midnight Commander – файлов мениджър за бърза работа
  * htop – мониторинг на процеси и натоварване
  * curl / wget – заявки и тестове
  * git – управление на код и версии
  
**Код за изпълнение**

```bash
sudo apt update && sudo apt install -y nano mc htop curl wget git
```

**PASS проверка**

```bash
nano --version | head -n 1 && mc --version | head -n 1 && htop --version && curl --version | head -n 1 && wget --version | head -n 1 && git --version
```

**Очакван резултат**

Пакетите `nano`, `mc`, `htop`, `curl`, `wget` и `git` са инсталирани без грешки.

*Пример за ОК:*

```
GNU nano, version 7.2
GNU Midnight Commander 4.8.30
htop 3.3.0
curl 8.5.0 (x86_64-pc-linux-gnu) libcurl/8.5.0 OpenSSL/3.0.13 zlib/1.3 brotli/1.1.0 zstd/1.5.5 libidn2/2.3.7 libpsl/0.21.2 (+libidn2/2.3.7) libssh/0.10.6/openssl/zlib nghttp2/1.59.0 librtmp/2.3 OpenLDAP/2.6.10
GNU Wget 1.21.4 built on linux-gnu.
git version 2.43.0
```

---

## Етап 1, Стъпка 3: Инсталиране на уеб сървър и база данни

Инсталиране на уеб сървър (Nginx) и база данни (MariaDB).

**Код за изпълнение**

```bash
sudo apt install -y nginx mariadb-server
```

**PASS проверка**

```bash
systemctl is-active nginx && systemctl is-active mariadb
```

**Очакван резултат**

* Nginx е инсталиран и стартиран
* MariaDB е инсталирана и стартирана
* няма грешки по време на инсталацията

```text
active
active
```

---

## Етап 1, Стъпка 4: Инсталиране на инструменти за сигурност

Инсталиране на базови инструменти за защита и управление на логове.

**Код за изпълнение**

```bash
sudo apt install -y ufw fail2ban logrotate
```

**PASS проверка**

```bash
ufw status && systemctl is-active fail2ban && logrotate --version
```

**Очакван резултат**

* UFW е инсталиран
* Fail2Ban е инсталиран
* logrotate е наличен
* няма грешки

```text
Status: inactive
active
logrotate ...
```

---

## Етап 1, Стъпка 5: Инсталиране на инструменти за наблюдение и логове

Осигуряване на системни логове и базов мониторинг.

**Код за изпълнение**

```bash
sudo apt install -y rsyslog netdata
```

**PASS проверка**

```bash
systemctl is-active systemd-journald && systemctl is-active rsyslog && systemctl is-active netdata
```

**Очакван резултат**

* journald работи (по подразбиране)
* rsyslog е инсталиран и активен
* netdata е инсталиран и стартиран

```text
active
active
active
```

---

## Етап 1, Стъпка 6: Инсталиране на инструменти за наблюдение на мрежата и диагностика

Инсталиране на инструменти за проверка на мрежата и анализ на трафик.

**Код за изпълнение**

```bash
sudo apt install -y net-tools iproute2 nmap tcpdump
```

**PASS проверка**

```bash
ifconfig --version 2>/dev/null | head -n 1 && ip -V && nmap --version | head -n 1 && tcpdump --version | head -n 1
```

**Очакван резултат**

* net-tools е инсталиран (ifconfig наличен)
* iproute2 е наличен (ip команда)
* nmap е инсталиран
* tcpdump е инсталиран
* няма грешки

```text
net-tools ...
ip utility ...
Nmap version ...
tcpdump version ...
```

---

## Етап 1, Стъпка 7: Инсталиране на PHP и приложения

Инсталиране на PHP и PHP-FPM за обработка на заявки от Nginx.

**Код за изпълнение**

```bash
sudo apt install -y php8.3 php8.3-fpm php8.3-mysql
```

**PASS проверка**

```bash
php -v | head -n 1 && systemctl is-active php8.3-fpm
```

**Очакван резултат**

* PHP 8.3 е инсталиран
* PHP-FPM е инсталиран и стартиран
* има поддръжка за MariaDB (mysql модул)
* няма грешки

```text
PHP 8.3 ...
active
```

---

## Етап 1, Стъпка 8: Смяна на порта за SSH достъп

Смяна на стандартния SSH порт (22) с нов порт и изключване на socket activation.

**Избор на свободен порт (пример: 59623)**

```bash
ss -tuln | grep 59623
```

**Конфигуриране на порта**

Отворете с редактора `nano`:

```bash
sudo nano /etc/ssh/sshd_config
```

*Добавете след* `# Port 22`:

```text
# Port 22
Port 59623
```

*Запишете и излезте от редактора*

**Презареждане на SSH**

```bash
sudo systemctl restart ssh
```

**Изключване на socket activation**

```bash
sudo systemctl stop ssh.socket
sudo systemctl disable ssh.socket
sudo systemctl enable ssh.service
sudo systemctl restart ssh.service
```

**Проверка на портовете**

```bash
ss -tulpn | grep sshd
```

**PASS проверка**

```bash
ss -tulpn | grep sshd | grep 59623
```

**Очакван резултат**

👉 вижда се само новият порт:

```text
:59623
```

---

## Етап 1, Стъпка 9: Тестване на обновявения достъп

**Изход от сървъра**

```bash
exit
```

**Проверка**

```bash
ssh -p 22 d2
```

👉 Трябва да получите отказ за достъп.

**Обновяване на бързия достъп**

❗Изпълнява се на компютъра

```bash
nano ~/.ssh/config
```

Добави/редактирай:

```sshconfig
Host d2
    HostName 65.108.12.147
    User root
    Port 59623
    IdentityFile ~/.ssh/id_ed25519_d2
    IdentitiesOnly yes
```

**Тест на входа с командата за бърз достъп**

```bash
ssh d2
```

---

## Етап 1, Стъпка 10: Създаване на потребител с root права.

👉 Това е потребителят, който ще се използва за управление на сървъра след забрана на директния вход с root.

**1. Създаване на потребителя**

```bash
adduser robinzon
```

👉 Въведете следните данни за новия потребител

* въведете парола (KichkaBodurova#77)
* повторете паролата
* въведете име (напр. Supervisor)
* останалите полета може да оставите празни
* потвърдете с `Y`

**2. Дайте на потребителя административни (sudo) права**

```bash
usermod -aG sudo robinzon
```

**3. Проверете правата**

```bash
id robinzon
```

👉 В изхода трябва да присъства:

```text
sudo
```

**4. Премахване на паролата за sudo** (за новия потребител)

Отворете файла:

```bash
sudo visudo
```

👉 Добавете в края на файла:

```text
robinzon ALL=(ALL) NOPASSWD:ALL
```

👉 Запишете и излезте.

**5. PASS проверка**

```bash
sudo -l -U robinzon
```

**Очакван резултат**

```text
(robinzon) NOPASSWD: ALL
```

---

## Етап 1, Стъпка 11: Конфигуриране на SSH достъп за новия потребител

**Излезте от сървъра**

```bash
exit
```

**Изпълнете от локалния компютър**

Копиране на публичния SSH ключ от локалния компютър в профила на административния потребител на сървъра за вход без парола.

```bash
ssh-copy-id -i ~/.ssh/id_ed25519_d2.pub -p 59623 robinzon@65.108.12.147
```

👉 Въведете паролата!

**Очакван резултат:**

```
Number of key(s) added: 1

Now try logging into the machine, with:   "ssh -p 59623 'robinzon@65.108.12.147'"
and check to make sure that only the key(s) you wanted were added.
```

**Тест на достъпа**

```bash
ssh -i ~/.ssh/id_ed25519_d2 -p 59623 robinzon@65.108.12.147
```

👉 Системата е коректно конфигурирана, ако:

* влиза без парола (с ключ)
* командата `sudo` работи

**PASS**

```text
PASS: robinzon user created
PASS: sudo privileges granted
PASS: passwordless sudo enabled
PASS: SSH access for robinzon working
```

---

## Етап 1, Стъпка 12: Въвеждане на забрана за вход с парола.

**Отворете конфигурационния файл:**

```bash
sudo nano /etc/ssh/sshd_config
```

👉 Намерете следните записи, разкоментирайте ги (ако са коментирани) и им задайте следните стойности:

```text
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
```

👉 Ако някой от редовете не съществува — добавете го в края на файла.  
👉 След промените, запишете и затвирете файла.

**Презареждане на SSH**

```bash
sudo systemctl restart ssh
```

**Тест на достъпа с парола**

👉 НЕ затваряйте текущата сесия! Отворете нов терминал и опитайте влезте в сървъра с командата:

```bash
ssh -o PreferredAuthentications=password -p 59623 admin@65.108.12.147
```

👉 Въведете паролата. 

**Очакван резултат**

```text
Permission denied, please try again.
```

---

## ФИНАЛЕН ОТЧЕТ ЗА ИЗПЪЛНЕНИЕ
**Към Инсталационен протокол № 1 (NG-D2-v.0.1)**

**Дата на завършване:** 26.03.2026  
**Изпълнител:** Илко Йорданов  
**Обект:** Сървър D2 (IP: 65.108.12.147)  
**Статус:** <span style="color:green">✅ УСПЕШНО ЗАВЪРШЕН</span>

---

### 1. РЕЗЮМЕ НА ИЗПЪЛНЕНИЕТО / EXECUTIVE SUMMARY
Всички заложени задачи по Етап 1 от инсталационния протокол са изпълнени съгласно утвърдените стандарти на проекта NetGalaxy. Системата е подготвена за работа, защитена и конфигурирана за отдалечено управление чрез SSH ключове.

* **OS:** Ubuntu 24.04.3 LTS (RAID1, ext4)
* **Web & DB:** Nginx, MariaDB, PHP 8.3-FPM
* **Security:** SSH Port 59623, Key-only access, Fail2Ban, UFW

---

### 2. ДЕТАЙЛЕН ПРЕГЛЕД НА ЗАДАЧИТЕ / TASK DETAILS

| Задача / Task | Статус | Коментар / Technical Note |
| :--- | :---: | :--- |
| **OS Installation** | PASS | Ubuntu 24.04.3 LTS, Software RAID 1 configured. |
| **System Update** | PASS | `apt update && upgrade` executed. |
| **Core Software** | PASS | Installed: nano, mc, htop, curl, wget, git. |
| **Web & Database** | PASS | Nginx & MariaDB services are active. |
| **PHP Stack** | PASS | PHP 8.3-FPM configured and running. |
| **Network & Monitoring**| PASS | Netdata, rsyslog, nmap, tcpdump installed. |
| **SSH Hardening** | PASS | Port changed to **59623**. Password auth **DISABLED**. |
| **Admin User** | PASS | User `robinzon` created with passwordless sudo. |

---

### 3. ПОДДРЪЖКА НА ЕЗИЦИ / LANGUAGE COMPLIANCE
В съответствие с изискванията на NetGalaxy, конфигурацията и документацията поддържат работните езици:
1.  **Български:** Пълна поддръжка и документация.
2.  **English:** System environment and technical logs.
3.  **Русский:** Поддержка локализации и документации обеспечена.

---

### 4. КЛЮЧОВИ КОНФИГУРАЦИИ / KEY CONFIGURATIONS
За бъдещи справки и автоматизация, достъпът се осъществява чрез следните параметри:

```bash
# Тест на защитения достъп (от локална машина):
ssh -i ~/.ssh/id_ed25519_d2 -p 59623 robinzon@65.108.12.147

# Проверка на административни права:
sudo -l -U robinzon # Очакван резултат: (ALL) NOPASSWD: ALL
```

---

### 5. ЗАКЛЮЧЕНИЕ / CONCLUSION
Сървър **D2** е в пълна оперативна готовност. Всички PASS проверки преминаха успешно. Системата е стабилна, сигурността е подсилена чрез премахване на паролния достъп и socket activation на SSH. 

**Следваща стъпка:** Преминаване към Етап 2 съгласно проектния план.

---
**Подпис:** ............................  
*(Илко Йорданов)*

**Copyright:** © 2026 NetGalaxy™ | **Confidential**

==================================

### ДЕТАЙЛНА СПЕЦИФИКАЦИЯ НА ТРУДА (BY STEPS)
*Тази таблица служи за проверка на реално извършената дейност спрямо технологичния норматив.*

| Стъпка от Протокола | Описание на дейността | Категория | Норматив (мин) |
| :--- | :--- | :---: | :---: |
| **Стъпка 1** | Инсталация на Ubuntu 24.04 & RAID1 | **Level C** | 15 |
| **Стъпка 2** | Конфигуриране на SSH ключове (Root) | **Level B** | 10 |
| **Стъпка 3** | Пълно обновяване на пакетите (Update) | **Level C** | 10 |
| **Стъпка 4** | Инсталиране на служебен софтуер (MC, Git) | **Level C** | 5 |
| **Стъпка 5** | Инсталиране на Nginx & MariaDB | **Level B** | 10 |
| **Стъпка 6** | Инсталиране на Сигурност (Fail2Ban, UFW) | **Level A** | 15 |
| **Стъпка 7** | Мрежова диагностика и Netdata | **Level B** | 10 |
| **Стъпка 8** | Инсталиране на PHP 8.3 & FPM | **Level B** | 10 |
| **Стъпка 9** | Смяна на SSH порт & Socket Disable | **Level A** | 15 |
| **Стъпка 10** | Създаване на Sudo потребител (Robinzon) | **Level B** | 10 |
| **Стъпка 11** | Конфигуриране на No-Password Sudo | **Level A** | 5 |
| **Стъпка 12** | Забрана на Password Auth (Final Hardening) | **Level A** | 10 |
| **Отчет** | Документиране на 3 езика | **Level B** | 5 |

---

### СУМАРНА КАРТА НА ТРУДОВИЯ ПРИНОС (LABOR VALUE MAP)
*Автоматично генерирано резюме за Смарт Контракта.*

| Група дейности | Категория труд | Общо мин. | Ставка (€/час) | Стойност (€) |
| :--- | :---: | :---: | :---: | :---: |
| **I. Базова инсталация & Update** | **Level C** | 30 | 100.00 | **50.00** |
| **II. Системна администрация & Web** | **Level B** | 45 | 150.00 | **112.50** |
| **III. Киберсигурност & Hardening** | **Level A** | 55 | 250.00 | **229.17** |
| --- | --- | --- | --- | --- |
| **ОБЩО ЗА ПРОТОКОЛА:** | | **130 мин.** | **Средна: 180.77** | **391.67 €** |

---

### ДАННИ ЗА СМАРТ КОНТРАКТ (SMART CONTRACT PAYOUT)
* **ID на задачата:** NG-D2-INSTALL-P1
* **Валута на изчисление:** EUR / NetGalaxy Token (NGT)
* **Обща стойност:** **391.67 €**
* **Разпределение:** * 💵 **Cash (40%):** 156,67 €
    * 💎 **Tokens (95%):** 235,00 € (еквивалент в NGT)

---
