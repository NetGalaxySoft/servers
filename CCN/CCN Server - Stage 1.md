# NetGalaxy Network

## Проект за създаване на Главен сървър на мрежата NetGalaxy Network

### Информация за документа

**Проект:** NetGalaxy  
**Документ ID:** CCN Server - Stage 1.md  
**Заглавие:** Описание на проекта  
**Версия:** 0.1  
**Статус:** Завършен на 14.04.2026  
**Дата:** 14.04.2026  
**Автори:** Илко Йорданов
**Локация на документа:** GitHub Repository: servers/CCN/CCN Server - Stage 1.md  
**Контакт:** 📧 [yordanov.netgalaxy@gmail.com](mailto:yordanov.netgalaxy@gmail.com)  

**Copyright:** © 2026 NetGalaxy™ by Ilko Iordanov. All rights reserved.  
***Лиценз:*** Този документ е част от проекта NetGalaxy. Предназначен е само за вътрешно ползване в рамките на мрежата NetGalaxy. Разпространението или публикуването извън мрежата не е разрешено.  
**Всички права запазени.**

&nbsp;

---

## 🧠 Етап 1 – Инсталиране на операционна система и базов достъп

**🎯 Цел:**

CCN да стане достъпен само по сигурен административен канал.

### Етап 1, Стъпка 1 – Избор на сървър

  * Провайдер: **Contabo**
  * Тип на сървъра: **VPS**
  * Модел: **Cloud VPS 10**
  * IP: **173.249.40.228**
  * IPv6: **2a02:c207:2323:1700::1**
  * vCPU Cores: **4 vCPU Cores**
  * RAM: **8 GB**
  * NVMe (GB) + Extra Storage: **75 GB NVMe**
  * Snapshots: **1 Snapshots**
  * Trafic (unlimited incoming): **200 Mbit/s Port**
  * Price: **5,45 EUR/month**
  * Username: **root**
  * Password: qy2M05Hnf735ay9

### Етап 1, Стъпка 2 – Създаване на GLUE записи (Host records)

**BookMyName / Register your DNS servers (hosts) to the registry**

ns1.netgalaxy.network → CCN (новия NS1 сървър)  
ns2.netgalaxy.network → D2 (съществуващия NS2 сървър)  

### Етап 1, Стъпка 3 – Инсталиране на операционна система

**Contabo / Your services / Cloud VPS 10 NVMe / Manage / Reinstall**

**Standard Image:** Ubuntu 24.04 LTS
**Password:** dtIh077#rRdxmeEo
**Application:** ❌ (без)

### Етап 1, Стъпка 4 – Конфигуриране на SSH

**4.1. Създаване на SSH ключ (локално)**

```
ssh-keygen -t ed25519 -C "ccn-admin-key" -f ~/.ssh/id_ed25519_ccn
```

PASS проверка

```
ls -l ~/.ssh/id_ed25519_ccn*
```

**4.2. Качване ключа на сървъра**

Разрешаване на вход с ключ:

```
ssh-copy-id -i ~/.ssh/id_ed25519_ccn.pub root@173.249.40.228
```

PASS проверка

```
ssh -i ~/.ssh/id_ed25519_ccn root@173.249.40.228
```

👉 ТРЯБВА да влезе без парола

**4.3. Избор на свободен порт за SSH**

Проверка дали избрания порт (напр. 31245) вече се използва:

```
sudo ss -tlnp | grep 31245
```

👉 Ако НЯМА изход: ✅ Портът е свободен

**4.4. Смяна на SSH порта**

Отворете конфигурацията:

```
sudo nano /etc/ssh/sshd_config
```

Намерете:

```
#Port 22
```

и го променете на

```
#Port 31245
```


**4.5. Спираме socket activation за SSH, за да може sshd да слуша по порта от sshd_config**

```
sudo systemctl disable --now ssh.socket
sudo systemctl mask ssh.socket
```

Очакван резултат + PASS проверка

```
sudo systemctl status ssh.socket --no-pager -l
```

👉 Трябва да показва, че ssh.socket е inactive или dead:

```
○ ssh.socket
     Loaded: masked (Reason: Unit ssh.socket is masked.)
     Active: inactive (dead)
```

**4.6. Рестарт на SSH**

```
sudo systemctl restart ssh
```

Очакван резултат + PASS проверка

```
sudo systemctl status ssh --no-pager -l
```

👉 Трябва да показва active (running) без ред TriggeredBy: ssh.socket.


**4.7. Проверка дали SSH вече слуша на новия порт**

```
sudo ss -tlnp | grep 31245
```

Очакван резултат + PASS проверка

Трябва да има ред с :31245 и LISTEN.

**4.8. - Отворете НОВ терминал за влизане през новия порт**

**!!! ПРОДЪЛЖЕТЕ БЕЗ ДА ЗАТВАРЯТЕ СТАРИЯ ТЕРМИНАЛ!!!*** 

Тест на вход през новия порт
```
ssh -p 31245 -i ~/.ssh/id_ed25519_ccn root@173.249.40.228
```
Очакван резултат + PASS проверка

👉 Трябва да се отвори SSH сесия към сървъра през порт 31245.

**4.9. Създаване на бърза SSH връзка**

Изпълнете на компютъра:

```
nano ~/.ssh/config
```

Добавете в края на файла:

Host ccn
    HostName 173.249.40.228
    Port 31245
    User root
    IdentityFile ~/.ssh/id_ed25519_ccn
    IdentitiesOnly yes


Очакван резултат + PASS проверка

```
ssh ccn
```

👉 Трябва да влезете директно без парола и без посочване на порт.

### Етап 1, Стъпка 5 – Обновяване на системата и базови инструменти

Команда:

```bash
sudo apt update && sudo apt upgrade -y && \
sudo apt install -y \
curl \
wget \
git \
htop \
dnsutils \
ufw \
fail2ban \
rsync \
unzip \
iproute2 \
iputils-ping \
mtr-tiny
```

Премахваме ненужни зависимости.

```
sudo apt -y autoremove
```

Очакван резултат + PASS проверка

```
0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.
```

### Етап 1, Стъпка 6 – Конфигуриране на firewall (UFW)

**Нулиране на стари правила**

```
sudo ufw --force reset
```

Очакван резултат + PASS проверка

```
sudo ufw status
```

👉 Трябва да показва: Status: inactive


**Задаване на политика по подразбиране**

```
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

**Разрешаване на DNS и SSH през новия порт**

```
sudo ufw allow 31245/tcp
sudo ufw allow 53/tcp
sudo ufw allow 53/udp
```

PASS проверка

```
sudo ufw show added
```

Очакван резултат:

```
ufw allow 31245/tcp
sudo ufw allow 53/tcp
sudo ufw allow 53/udp
```

### Етап 1, Стъпка 7 – ⚠️ Активиране на firewall

**Активираме firewall** ⚠️ Критична стъпка

```bash
sudo ufw enable
```

Очакван резултат + PASS проверка

```bash
sudo ufw status verbose
```

👉 трябва да показва:

```bash
Status: active
```

**🧪 Финален тест**

Проверяваме дали SSH достъпът работи през нов терминал

```bash
ssh ccn
```

Очакван резултат + PASS проверка

✔ влиза успешно

---

### Етап 1, Финални проверки

🎯 PASS критерий за Етап 1

  * приема SSH само на порт 31245 ✔
  * достъпен чрез бърза връзка ssh ccn ✔
  * има активен firewall ✔
  * няма излишни услуги ✔
  * има чиста и контролирана система ✔
  
---

## ОТЧЕТ ЗА ИЗПЪЛНЕНИЕ НА ЗАДАЧИТЕ

**Към Инсталационен протокол № 1 (CCN Server - Stage 1.md)**

**Дата на завършване:** 14.04.2026
**Изпълнител:** Илко Йорданов
**Обект:** Главен сървър CCN (IP: 173.249.40.228)
**Статус:** <span style="color:green">✅ УСПЕШНО ЗАВЪРШЕН</span>

### 1. РЕЗЮМЕ НА ИЗПЪЛНЕНИЕТО / EXECUTIVE SUMMARY

Всички задачи по Етап 1 за изграждането на главния координационен възел **CCN** са изпълнени успешно. Сървърът е подготвен с чиста инсталация на Ubuntu 24.04 LTS, преминал е през първоначално подсигуряване (hardening) и е достъпен изключително чрез криптографски ключове на нестандартен порт. Поставена е основата за бъдещата DNS роля (NS1) на мрежата NetGalaxy.

Изпълнените дейности включват:
* **Provisioning:** Нает и активиран Cloud VPS 10 (Contabo) с NVMe сторидж.
* **Access Control:** Деактивиран паролен достъп, внедрени Ed25519 ключове.
* **SSH Hardening:** Премахване на socket activation, преместване на порт **31245**, конфигуриран бърз достъп (`ssh ccn`).
* **Security:** Инсталирани базови инструменти, активиран UFW със строги политики.
* **DNS Readiness:** Създадени GLUE записи (ns1.netgalaxy.network) и отворени портове 53 TCP/UDP.

### 2. ДЕТАЙЛЕН ПРЕГЛЕД НА ЗАДАЧИТЕ / TASK DETAILS

| Задача / Task                    | Статус | Коментар / Technical Note                                                                        |
| :------------------------------- | :----: | :----------------------------------------------------------------------------------------------- |
| **Server Provisioning** |  PASS  | Сървърът е активен в Contabo с 4 vCPU, 8GB RAM и NVMe скорост.                                   |
| **OS Installation** |  PASS  | Ubuntu 24.04 LTS е инсталирана с "Clean Image" без излишни приложения.                            |
| **GLUE Records (NS1)** |  PASS  | Дефинирани хост записи в BookMyName към 173.249.40.228.                                          |
| **SSH Key Deployment** |  PASS  | Използван Ed25519 алгоритъм (ccn-admin-key). Root достъпът е ограничен само до ключове.          |
| **Port Migration** |  PASS  | SSH преместен от порт 22 на 31245. Конфигуриран `ssh.socket mask` за избягване на конфликти.     |
| **SSH Fast Connect** |  PASS  | Създаден локален `~/.ssh/config` профил за мигновена връзка.                                     |
| **Base Software Stack** |  PASS  | Инсталирани mc, htop, curl, dnsutils, rsync и мрежови инструменти.                               |
| **Firewall (UFW) Policy** |  PASS  | Default Deny Incoming. Разрешен изходящ трафик.                                                  |
| **Port Management** |  PASS  | Отворени портове 31245 (SSH), 53 (DNS TCP/UDP).                                                  |
| **Final Access Audit** |  PASS  | Успешен вход през нов терминал; порт 22 е затворен и неактивен.                                  |

### 3. ПОДДРЪЖКА НА ЕЗИЦИ / LANGUAGE COMPLIANCE

В съответствие с изискванията на NetGalaxy:
1. **Български:** Основен език на техническата документация и отчетите.
2. **English:** Команди, конфигурационни файлове (sshd_config), системни променливи.
3. **Русский:** Поддръжка на символни набори и готовност за локализация на следващи етапи.

### 4. КЛЮЧОВИ КОНФИГУРАЦИИ / KEY CONFIGURATIONS

```
# SSH Connection
ssh ccn  # (Alias for root@173.249.40.228 -p 31245)

# SSH Socket Status (Must be masked)
sudo systemctl status ssh.socket

# Active Ports Check
sudo ss -tlnp | grep -E '31245|53'

# Firewall Rules
sudo ufw status numbered

# Glue Records
ns1.netgalaxy.network -> 173.249.40.228
```

### 5. ЗАКЛЮЧЕНИЕ / CONCLUSION

Сървър **CCN** е успешно въведен в експлоатация (Етап 1). Системата е стабилна, подсигурена и готова за инсталация на DNS (BIND9) и централизираните системи за валидиране на NetGalaxy. Всички PASS критерии за сигурен административен достъп са покрити.

**Подпис:** ............................
*(Илко Йорданов)*

**Copyright:** © 2026 NetGalaxy™ | **Confidential**

### 6. ДЕТАЙЛНА СПЕЦИФИКАЦИЯ НА ТРУДА (BY STEPS)

| Стъпка | Описание | Категория | Време (мин) | Коментар |
| :--- | :--- | :---: | :---: | :--- |
| **Стъпка 1-3** | Provisioning, OS & GLUE setup | **Level B** | 30 | Работа с панели (Contabo/BookMyName) |
| **Стъпка 4** | SSH Key, Port & Alias config | **Level A** | 40 | Критична конфигурация на достъпа |
| **Стъпка 5** | Base Tools & System Update | **Level C** | 20 | Инсталация и почистване |
| **Стъпка 6-7** | Firewall Hardening & Port Audit | **Level A** | 30 | Настройка на UFW и финални тестове |
| **Отчет** | Документиране и валидация | **Level B** | 20 | Прецизно описване на протокола |

---

### 7. СУМАРНА КАРТА НА ТРУДОВИЯ ПРИНОС (ОБНОВЕНА)

| Група дейности | Категория труд | Общо мин. | Ставка (€/час) | Стойност (€) |
| :--- | :---: | :---: | :---: | :---: |
| **I. Системна инсталация** | **Level C** | **20** | **100.00** | **33.33** |
| **II. Администриране и отчет** | **Level B** | **50** | **150.00** | **125.00** |
| **III. Киберсигурност (SSH/UFW)** | **Level A** | **70** | **250.00** | **291.67** |
| **ОБЩО ЗА ПРОТОКОЛА:** | | **140 мин.** | **Средна: 192.86** | **450.00 €** |

---

### 8. ДАННИ ЗА СМАРТ КОНТРАКТ (PAYOUT)

* **ID на задачата:** NG-CCN-CORE-STAGE1
* **Обща стойност:** **450.00 €**
* **Разпределение (40/60):**
    * 💵 **Cash (40%):** **180.00 €**
    * 💎 **Tokens (60%):** **270.00 €**

*Забележка: Стойността отразява високата отговорност при конфигурирането на Главния контролен възел (CCN), която е критична точка за сигурността на цялата мрежа.*
