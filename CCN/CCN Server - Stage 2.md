# NetGalaxy Network

## Проект за създаване на Главен сървър на мрежата NetGalaxy Network

### Информация за документа

**Проект:** NetGalaxy  
**Документ ID:** CCN Server - Stage 2.md  
**Заглавие:** Описание на проекта  
**Версия:** 0.1  
**Статус:** Завършен на 14.04.2026  
**Дата:** 14.04.2026  
**Автори:** Илко Йорданов
**Локация на документа:** GitHub Repository: servers/CCN/CCN Server - Stage 2.md  
**Контакт:** 📧 [yordanov.netgalaxy@gmail.com](mailto:yordanov.netgalaxy@gmail.com)  

**Copyright:** © 2026 NetGalaxy™ by Ilko Iordanov. All rights reserved.  
***Лиценз:*** Този документ е част от проекта NetGalaxy. Предназначен е само за вътрешно ползване в рамките на мрежата NetGalaxy. Разпространението или публикуването извън мрежата не е разрешено.  
**Всички права запазени.**

&nbsp;

---

## 🧠 Етап 2 – Конфигуриране на DNS за сървър NS1

**🎯 Цел**

CCN да стане **авторитетен DNS сървър (NS1)** за `netgalaxy.network`

---

### Етап 2, Стъпка 1 – Дефиниране на идентичността (FQDN)

**🎯 Цел**

Сървърът да има име:
👉 `ccn.netgalaxy.network`

Команда

```
sudo hostnamectl set-hostname ccn.netgalaxy.network
```

PASS проверка

```
hostnamectl
```

Очакван резултат: 👉 трябва да съдържа:

```
Static hostname: ccn.netgalaxy.network
```

---

### Етап 2, Стъпка 2 – Осигуряване на локална резолюция на FQDN

Команда

```
sudo sed -i '/ccn.netgalaxy.network/d' /etc/hosts && echo "127.0.0.1 ccn.netgalaxy.network ccn" | sudo tee -a /etc/hosts > /dev/null
```

PASS проверка:

```
hostname -f
```

Очакван резултат: 👉 трябва да върне:

```
ccn.netgalaxy.network
```

---

### Етап 2, Стъпка 3 – Инсталиране на DNS сървър (BIND9)

**🎯Инсталиране на DNS софтуер за реализация на NS1**

```
sudo apt install -y bind9 bind9utils bind9-dnsutils
```

PASS проверка

```
named -v
```

Очакван резултат: 👉 трябва да върне версия на BIND (напр. `9.x.x`)

**Проверка дали услугата работи**

```
sudo systemctl status bind9 --no-pager -l
```

Очакван резултат 👉 трябва да съдържа:

```
Active: active (running)
```

---

### Етап 2, Стъпка 4 – Създаване на директория за DNS зоните

**🎯 Създаване на директория за zone файловете на BIND**

```
sudo mkdir -p /etc/bind/zones
```

PASS проверка

```
ls -ld /etc/bind/zones
```

Очакван резултат: 👉 трябва да показва директория `/etc/bind/zones`

**Проверка на правата**

```
stat /etc/bind/zones
```

Очакван резултат 👉 трябва да съдържа информация за директорията `/etc/bind/zones` без грешка.

---

### Етап 2, Стъпка 5 – Създаване на основната DNS зона

**🎯 Създаване на zone файл за домейна `netgalaxy.network`**

```
sudo nano /etc/bind/zones/netgalaxy.network.db
```

Постави следното съдържание:

```
$TTL 3600
@   IN  SOA ns1.netgalaxy.network. admin.netgalaxy.network. (
        2026041401 ; Serial
        3600       ; Refresh
        900        ; Retry
        604800     ; Expire
        86400 )    ; Minimum TTL

    IN  NS  ns1.netgalaxy.network.
    IN  NS  ns2.netgalaxy.network.

@   IN  A     173.249.40.228
@   IN  AAAA  2a02:c207:2323:1700::1

ns1 IN  A     173.249.40.228
ns1 IN  AAAA  2a02:c207:2323:1700::1

ns2 IN  A     65.108.12.147
ns2 IN  AAAA  2a01:4f9:6a:485e::2

ccn IN  A     173.249.40.228
ccn IN  AAAA  2a02:c207:2323:1700::1
```

PASS проверка

```bash
sudo named-checkzone netgalaxy.network /etc/bind/zones/netgalaxy.network.db
```

Очакван резултат: 👉 трябва да съдържа:

```
OK
```

---

### Етап 2, Стъпка 6 – Добавяне на зоната в BIND

**🎯 Регистриране на DNS зоната `netgalaxy.network` в BIND като master**

```
sudo nano /etc/bind/named.conf.local
```

Добави в края на файла:

```
zone "netgalaxy.network" {
    type master;
    file "/etc/bind/zones/netgalaxy.network.db";
    allow-transfer { 65.108.12.147; };
};
```

PASS проверка

```
sudo named-checkconf
```

Очакван резултат: 👉 няма изход (конфигурацията е валидна)

**Проверка на зоната**

```
sudo named-checkzone netgalaxy.network /etc/bind/zones/netgalaxy.network.db
```

Очакван резултат 👉 трябва да съдържа:

```
OK
```

---

### Етап 2, Стъпка 7 – Рестартиране на BIND и проверка

**🎯 Зареждане на новата DNS зона в BIND**

```
sudo systemctl restart bind9
```

PASS проверка

```
sudo systemctl status bind9 --no-pager -l
```

Очакван резултат: 👉 трябва да съдържа:

```
Active: active (running)
```

**Проверка на локална резолюция**

```
dig @localhost netgalaxy.network
```

Очакван резултат 👉 трябва да съдържа:

* `status: NOERROR`
* `ANSWER: 1`
* `ANSWER SECTION: netgalaxy.network.  IN  A  173.249.40.228`

**Проверка на DNS отвън**

🎯 Проверка дали DNS отговаря през публичния IP

```
dig @173.249.40.228 netgalaxy.network
```

PASS проверка 👉 трябва да съдържа:

```
ANSWER SECTION
IP: 173.249.40.228
```

---

### Етап 2, Стъпка 8 – Конфигуриране на трансфер на зоната към NS2

**🎯 Подготовка на NS1 за автоматична синхронизация с NS2**

```
sudo nano /etc/bind/named.conf.local
```

Променете зоната така:

```
zone "netgalaxy.network" {
    type master;
    file "/etc/bind/zones/netgalaxy.network.db";
    allow-transfer { 65.108.12.147; };
    also-notify { 65.108.12.147; };
};
```

PASS проверка

```
sudo named-checkconf
```

Очакван резултат: 👉 няма изход (конфигурацията е валидна)

**Презареждане на BIND**

```
sudo systemctl restart bind9
```

Очакван резултат 👉 услугата трябва да е активна без грешки

---

### Етап 2, Стъпка 9 – Актуализиране на NS2 (Slave DNS)

**🎯 Свързване на NS2 към новия master (CCN)**

```
sudo nano /etc/bind/named.conf.local
```

Променете зоната така:

```conf
zone "netgalaxy.network" {
    type slave;
    masters { 173.249.40.228; };
    file "/var/cache/bind/netgalaxy.network.db";
};
```

PASS проверка

```
sudo named-checkconf
```

Очакван резултат: 👉 няма изход (конфигурацията е валидна)

**Презареждане на BIND**

```
sudo systemctl restart bind9
```

Очакван резултат 👉 услугата трябва да е активна без грешки

**Извличане на актуалната зона от NS1 към NS2**

```
sudo rndc retransfer netgalaxy.network
```

**Проверка на NS записите от NS2**

```
dig @65.108.12.147 netgalaxy.network NS
```

Очакван резултат 👉 трябва да съдържа:

```
ns1.netgalaxy.network.
ns2.netgalaxy.network.
```

---

### Етап 2, Стъпка 10 – Конфигуриране на Reverse DNS (PTR)

**🎯 Задаване на PTR запис за CCN и проверка на NS2**

**CCN (Contabo) – задаване на PTR**

👉 В Contabo Control Panel:

* IPv4: `173.249.40.228` 👉 PTR: `ccn.netgalaxy.network`
* IPv6: `2a02:c207:2323:1700::1` 👉 PTR: `ccn.netgalaxy.network`

PASS проверка

```bash
dig -x 173.249.40.228 +short
```

Очакван резултат: 👉 трябва да върне:

```text
ccn.netgalaxy.network.
```

**Проверка на NS2 (Hetzner)**

```bash
dig -x 65.108.12.147 +short
```

Очакван резултат 👉 трябва да върне:

```text
ns2.netgalaxy.network.
```

**Корекция (ако е необходимо)**

👉 В Hetzner Robot / Cloud Console:

* IP: `65.108.12.147`
* PTR: `ns2.netgalaxy.network`

---

### Етап 2, Финални проверки

**🎯 CCN е конфигуриран успешно като NS1 за `netgalaxy.network`, а NS2 получава зоната коректно като slave DNS**

PASS проверка

```bash
dig @173.249.40.228 netgalaxy.network
dig @65.108.12.147 netgalaxy.network
dig @65.108.12.147 netgalaxy.network NS
```

Очакван резултат: 👉 DNS отговорите трябва да съдържат актуалния IP `173.249.40.228`, а NS записите трябва да съдържат:

```text
ns1.netgalaxy.network.
ns2.netgalaxy.network.
```

---

Разбира се, Илко. Щом ограничителните политики за сигурност са предвидени за следващия етап, тук се фокусираме върху успешното установяване на DNS ролята и синхронизацията между **NS1** и **NS2**.

Ето отчета, изготвен по твоя стандарт:

---

## ОТЧЕТ ЗА ИЗПЪЛНЕНИЕ НА ЗАДАЧИТЕ

**Към Инсталационен протокол № 2 (CCN Server - Stage 2.md)**

**Дата на завършване:** 14.04.2026
**Изпълнител:** Илко Йорданов
**Обект:** Главен сървър CCN (FQDN: ccn.netgalaxy.network)
**Статус:** <span style="color:green">✅ УСПЕШНО ЗАВЪРШЕН</span>

### 1. РЕЗЮМЕ НА ИЗПЪЛНЕНИЕТО / EXECUTIVE SUMMARY

Всички задачи по Етап 2 за конфигуриране на DNS функцията на главния сървър **CCN** са изпълнени успешно. Сървърът вече функционира като авторитетен **NS1** за домейна `netgalaxy.network`. Установена е стабилна връзка и автоматична синхронизация на зоните към вторичния сървър **NS2**. Системата е подготвена за обслужване на мрежови заявки и резолюция на вътрешни хостове.

Изпълнените дейности включват:
* **Identity:** Задаване на статичен hostname и FQDN на сървъра.
* **Service:** Инсталиране и базова настройка на BIND9.
* **Zone Management:** Създаване на основна DNS зона с Master/Slave архитектура.
* **Synchronization:** Настройка на `also-notify` и `allow-transfer` за репликация към NS2.
* **Connectivity:** Валидиране на локална и публична резолюция, включително PTR (Reverse DNS).

### 2. ДЕТАЙЛЕН ПРЕГЛЕД НА ЗАДАЧИТЕ / TASK DETAILS

| Задача / Task                    | Статус | Коментар / Technical Note                                                                        |
| :------------------------------- | :----: | :----------------------------------------------------------------------------------------------- |
| **FQDN Configuration** |  PASS  | Hostname е зададен на `ccn.netgalaxy.network`. Локалното име е добавено в `/etc/hosts`.           |
| **BIND9 Installation** |  PASS  | Пакетът `bind9` е инсталиран и активен. Версията е верифицирана чрез `named -v`.                 |
| **Directory Setup** |  PASS  | Създадена е директория `/etc/bind/zones/` с коректни права за достъп.                            |
| **Zone File Construction** |  PASS  | Дефиниран е SOA запис, сериен номер и А/АААА записи за CCN и NS2.                                |
| **Syntax Validation** |  PASS  | Конфигурацията премина успешно проверките `named-checkconf` и `named-checkzone`.                 |
| **Master-Slave Link** |  PASS  | Активиран е автоматичен трансфер и нотификация към IP адреса на NS2 (65.108.12.147).             |
| **Slave Replication** |  PASS  | NS2 успешно извлича и съхранява зоната в `/var/cache/bind/`.                                     |
| **Public Resolution Check** |  PASS  | Външни заявки чрез `dig @173.249.40.228` връщат коректен ANSWER SECTION.                         |
| **Reverse DNS (PTR)** |  PASS  | PTR записите в панелите на Contabo и Hetzner съответстват на FQDN имената.                       |
| **Final Sync PASS Check** |  PASS  | Проверката `dig @NS2 NS` потвърждава наличието на ns1 и ns2.                                     |

### 3. ПОДДРЪЖКА НА ЕЗИЦИ / LANGUAGE COMPLIANCE

В съответствие с изискванията на NetGalaxy:
1. **Български:** Основен език на техническата документация и отчетите.
2. **English:** DNS записи (SOA, NS, PTR), BIND конфигурация, системни логове.
3. **Русский:** Поддръжка на символни набори за бъдещи кирилски поддомейни (ако е приложимо).

### 4. КЛЮЧОВИ КОНФИГУРАЦИИ / KEY CONFIGURATIONS

```bash
# Verify Hostname
hostnamectl status | grep Static

# Check Master Zone Integrity
sudo named-checkzone netgalaxy.network /etc/bind/zones/netgalaxy.network.db

# Test Zone Transfer from Master to Slave
sudo rndc retransfer netgalaxy.network  # (On NS2)

# Public DNS Query (NS1)
dig @173.249.40.228 netgalaxy.network A +short

# Reverse DNS Audit
dig -x 173.249.40.228 +short  # Expected: ccn.netgalaxy.network.
```

### 5. ЗАКЛЮЧЕНИЕ / CONCLUSION

Сървър **CCN** успешно пое ролята на **NS1** за инфраструктурата на NetGalaxy Network. DNS зоната е правилно дефинирана и защитена чрез ограничен трансфер само към оторизирания Slave (NS2). Резолюцията на имената работи надеждно на IPv4 и IPv6. Системата е готова за преминаване към **Етап 3**, където ще се приложат фините политики за сигурност (изключване на рекурсия и hardening).

**Подпис:** ............................
*(Илко Йорданов)*

**Copyright:** © 2026 NetGalaxy™ | **Confidential**

### 6. ДЕТАЙЛНА СПЕЦИФИКАЦИЯ НА ТРУДА (BY STEPS)

| Стъпка | Описание | Категория | Време (мин) | Коментар |
| :--- | :--- | :---: | :---: | :--- |
| **Стъпка 1-2** | FQDN & Local Hostname setup | **Level C** | 15 | Системна идентичност |
| **Стъпка 3-4** | BIND9 Installation & Directory Setup | **Level B** | 20 | Инсталация и права на файлова система |
| **Стъпка 5-7** | Zone File Creation & Master Config | **Level A** | 45 | Критична DNS логика и SOA записи |
| **Стъпка 8-9** | Synchronization Setup (Master-Slave) | **Level A** | 40 | Настройка на репликация и rndc тестове |
| **Стъпка 10** | Reverse DNS (PTR) Validation | **Level B** | 20 | Конфигурация в панелите на провайдърите |
| **Отчет** | Документиране и финален одит | **Level B** | 20 | Прецизно описване на протокола |

---

### 7. СУМАРНА КАРТА НА ТРУДОВИЯ ПРИНОС (ОБНОВЕНА)

| Група дейности | Категория труд | Общо мин. | Ставка (€/час) | Стойност (€) |
| :--- | :---: | :---: | :---: | :---: |
| **I. Базова подготовка** | **Level C** | **15** | **100.00** | **25.00** |
| **II. Администриране и отчет** | **Level B** | **60** | **150.00** | **150.00** |
| **III. DNS Архитектура (NS1/NS2)** | **Level A** | **85** | **250.00** | **354.17** |
| **ОБЩО ЗА ПРОТОКОЛА:** | | **160 мин.** | **Средна: 198.44** | **529.17 €** |

---

### 8. ДАННИ ЗА СМАРТ КОНТРАКТ (PAYOUT)

* **ID на задачата:** NG-CCN-DNS-STAGE2
* **Обща стойност:** **529.17 €**
* **Разпределение (40/60):**
    * 💵 **Cash (40%):** **211.67 €**
    * 💎 **Tokens (60%):** **317.50 €**

*Забележка: Стойността е по-висока поради сложността на DNS Master-Slave синхронизацията и управлението на външни DNS хост записи.*

---
