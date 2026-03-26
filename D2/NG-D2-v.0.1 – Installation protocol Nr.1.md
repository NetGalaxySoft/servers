# NetGalaxy Network

## Инсталационен протокол № 1

---

### Информация за документа

**Проект:** NetGalaxy  
**Document ID:** NG-D2-v.0.1 – Installation protocol Nr.1  
**Заглавие:** Инсталационен протокол № 1  
**Изпълнител:** Илко Йорданов  
**Дата:** 26.03.2026  

**Локация на документа:** GitHub Repository: servers/D2/NG-D2-v.0.1 – Installation protocol Nr.1  
**Контакт:** 📧 [yordanov.netgalaxy@gmail.com](mailto:yordanov.netgalaxy@gmail.com)  

**Copyright:** © 2026 NetGalaxy™ by Ilko Iordanov. All rights reserved.  
***Лиценз:*** Този документ е част от проекта NetGalaxy. Предназначен е само за вътрешно ползване в рамките на мрежата NetGalaxy. Разпространението или публикуването извън мрежата не е разрешено.  
**Всички права запазени.**

&nbsp;

---

# Задачи за изпълнение

### Реализация на Етап 1 и Етап 2 от проекта NG-D2 за добавяне на нов сървър в мрежата NetGalaxy

---

## Етап 1 - Конфигуриране на административния достъп.

### Етап 1, Стъпка 1. Инсталиране на операционна система

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

### Какво НЕ трябва да променяте

❌ не променяйте размери
❌ не пипайте RAID layout
❌ не добавяйте нищо

---

### Финално действие

👉 Натиснете последователно:

```text
F10
```

→ Save
→ Yes

---

### Очакван резултат (PASS):

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

## Етап 2 - Инсталиране на служебния софтуер (основа за управление)

### Етап 2, Стъпка 1 - Системни инструменти**

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

### Етап 2, Стъпка 2 — Уеб и база данни

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

### Етап 2, Стъпка 3 — Сигурност

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

Продължаваме стриктно.

---

### Етап 2, Стъпка 4 — Наблюдение и логове

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

### Етап 2, Стъпка 5 — Мрежа и диагностика

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

### Етап 2, Стъпка 6 — PHP с приложения

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

## Всички задачи са изпълнени!



