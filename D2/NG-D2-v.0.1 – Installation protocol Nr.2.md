# NetGalaxy Network

## Инсталационен протокол № 2

### Етап 2 - Конфигуриране на Домейн (DNS & Security)

🎯 ЦЕЛ

Изграждане на напълно функционираща DNS инфраструктура с:

  * Master DNS (ns1 – cp205)
  * Slave DNS (ns2 – D2)
  * DNSSEC защита
  * Глобална резолюция и валидиране

---

### Информация за документа

**Проект:** NetGalaxy  
**Document ID:** NG-D2-v.0.1 – Installation protocol Nr.2.md  
**Дата:** 02.04.2026  
**Заглавие:** Инсталационен протокол № 2  
**Задачи за изпълнение:**

  * Инсталиране на DNS сървър (Bind9)
  * Конфигуриране на firewall за DNS достъп (cp205 Server)
  * Конфигуриране на firewall за DNS достъп (D2 Server)
  * Регистрация и "Glue Records"
  * Конфигуриране на Master сървър (ns1)
  * Създаване на зоновия файл (Master)
  * Настройка на Reverse DNS
  * Конфигуриране на вторичен сървър (Slave / ns2)
  * Подготовка на инфраструктурата за DNSSEC
  * Активиране на DNSSEC и автоматичното подписване
  * Извличане на DNSSEC ключове (DS записи)
  * Регистрация на ключа в BookMyName
  * Финална проверка
  
**Срок за изпълнение:** 02.04.2026  
**Изпълнител:** Илко Йорданов  
**Статус:** Изпълнен на 02.04.2026  
**Локация на документа:** GitHub Repository: servers/D2/NG-D2-v.0.1 – Installation protocol Nr.2.md  
**Контакт:** 📧 [yordanov.netgalaxy@gmail.com](mailto:yordanov.netgalaxy@gmail.com)  

**Copyright:** © 2026 NetGalaxy™ by Ilko Iordanov. All rights reserved.  
***Лиценз:*** Този документ е част от проекта NetGalaxy. Предназначен е само за вътрешно ползване в рамките на мрежата NetGalaxy. Разпространението или публикуването извън мрежата не е разрешено.  
**Всички права запазени.**

&nbsp;

---

## Етап 2, Стъпка 1: Инсталиране на DNS сървър (Bind9)

Инсталиране на DNS сървър BIND9 и необходимите инструменти за управление и диагностика на двата сървъра, определени за ns1 и ns2.

**1.1. Инсталиране на BIND на cp205**

```bash
sudo apt update && sudo apt install -y bind9 bind9-utils dnsutils
```

Очакван резултат**

* Пакетите bind9, bind9-utils и dnsutils са инсталирани
* DNS услугата е налична в системата

**1.2. Стартиране и активиране**

Активирайте услугата и включете автоматичното стартиране:

```
sudo systemctl enable bind9
sudo systemctl start bind9
```

PASS проверка:

```bash
systemctl is-active bind9 && systemctl is-enabled bind9
```

Очакван резултат: 

```
active
enabled
```

**1.3. Повторете същите операции на сървър D2**

---

## Етап 2, Стъпка 2: Конфигуриране на firewall за DNS достъп (cp205 Server)

**🎯 Цел**

Осигуряване на достъп до DNS услугата (порт 53 на сървъра cp205) и гарантиране на непрекъснат SSH достъп преди активиране на firewall.


**⚠️ ВАЖНО! Всички команди в тази стъпка се изпълняват на сървър cp205.**

👉 Преди активиране на UFW **задължително** трябва да бъде разрешен SSH портът, използван на сървъра.
👉 Проверете активният порт за SSH в конфигурационния файл на SSH демона (sshd_config):

```
grep -E "^Port [0-9]+" /etc/ssh/sshd_config || echo "Port 22 (Default)"
```

**2.1. Инсталиране на UFW**

```
sudo apt update && sudo apt install -y ufw
```

*PASS проверка (инсталация)*

```
ufw --version
```

*Очакван резултат*

```
ufw <версия>
```

**2.2. Добавяне на правила**

```
sudo ufw allow 32240/tcp
sudo ufw allow 53/tcp
sudo ufw allow 53/udp
```

*PASS проверка (преди активиране)*

```
sudo ufw show added
```

*Очакван резултат*

```
Status: inactive

ufw allow 32240/tcp
ufw allow 53/tcp
ufw allow 53/udp
```

👉 Всички правила трябва да присъстват **преди активиране на firewall**.

**2.3. Активиране на firewall**

```
sudo ufw enable
```

*Очакван резултат:*

```
Command may disrupt existing ssh connections. Proceed with operation (y|n)? 
```

Системата пита: "Сигурен ли сте, че искате да активирате защитната стена? При грешно посочен порт може да бъде прекъсната текущата SSH сесия. Въведете **y**, ако сте разрешили правилния порт." 

*PASS проверка (след активиране)*

```
sudo ufw status
```

*Очакван резултат*

```
53/tcp                     ALLOW       Anywhere                  
53/udp                     ALLOW       Anywhere                  
32240/tcp                  ALLOW       Anywhere                  
53/tcp (v6)                ALLOW       Anywhere (v6)             
53/udp (v6)                ALLOW       Anywhere (v6)             
32240/tcp (v6)             ALLOW       Anywhere (v6)  
```

---

## Етап 2, Стъпка 3: Конфигуриране на firewall за DNS достъп (D2 Server)

**🎯 Цел**

Осигуряване на достъп до DNS услугата (порт 53 на сървъра D2) и гарантиране на непрекъснат SSH достъп преди активиране на firewall.


**⚠️ ВАЖНО! Всички команди в тази стъпка се изпълняват на сървър D2.**

👉 Преди активиране на UFW **задължително** трябва да бъде разрешен SSH портът, използван на сървъра.
👉 Проверете активният порт за SSH в конфигурационния файл на SSH демона (sshd_config):

```
grep -E "^Port [0-9]+" /etc/ssh/sshd_config || echo "Port 22 (Default)"
```

**3.1. Инсталиране на UFW**

```
sudo apt update && sudo apt install -y ufw
```

*PASS проверка (инсталация)*

```
ufw --version
```

*Очакван резултат*

```
ufw <версия>
```

**3.2. Добавяне на правила**

```
sudo ufw allow 59623/tcp
sudo ufw allow 53/tcp
sudo ufw allow 53/udp
```

*PASS проверка (преди активиране)*

```
sudo ufw show added
```

*Очакван резултат*

```
Status: inactive

ufw allow 59623/tcp
ufw allow 53/tcp
ufw allow 53/udp
```

👉 Всички правила трябва да присъстват **преди активиране на firewall**.

**3.3. Активиране на firewall**

```
sudo ufw enable
```

*Очакван резултат:*

```
Command may disrupt existing ssh connections. Proceed with operation (y|n)? 
```

Системата пита: "Сигурен ли сте, че искате да активирате защитната стена? При грешно посочен порт може да бъде прекъсната текущата SSH сесия. Въведете **y**, ако сте разрешили правилния порт." 

*Очакван резултат*

```
Firewall is active and enabled on system startup
```

**PASS проверка (след активиране):**

```
sudo ufw status
```

*Очакван резултат*

```
53/tcp                     ALLOW       Anywhere                  
53/udp                     ALLOW       Anywhere                  
59623/tcp                  ALLOW       Anywhere                  
53/tcp (v6)                ALLOW       Anywhere (v6)             
53/udp (v6)                ALLOW       Anywhere (v6)             
59623/tcp (v6)             ALLOW       Anywhere (v6)  
```

---

## Етап 2, Стъпка 4: Регистрация и "Glue Records"

След купуването на домейна, първата стъпка е създадаването на Glue Records при регистратора. Трябва да обвържете имената ns1.netgalaxy.network и ns2.netgalaxy.network с техните IP адреси, за да знае светът къде да търси тези сървъри.

**Изпълнете в контролния панел на регистратора BookMyName**

**4.1.** Отворете **> Register your DNS servers (hosts) to the registry**

**4.2.** Въведете името на домейна **netgalaxy.network** натиснете **Submit**

**4.3.** Въведете следните GLUE записи**

```text
ns1.netgalaxy.network → 38.242.249.205
ns2.netgalaxy.network → 65.108.12.147
```

**4.4.** Добавете и съответните IPv6 адреси:

```text
ns1.netgalaxy.network → 2a02:c206:2240:6856::1
ns2.netgalaxy.network → 2a01:4f9:6a:485e::2
```

**4.5.** Проверете зададените DNS сървъри за домейна `netgalaxy.network` - PASS:

```text
ns1.netgalaxy.network
ns2.netgalaxy.network
```

*PASS Проверка 1: Валидация на Glue записи (директно от регистъра)*
```bash
dig +norecurse @a.nic.network ns1.netgalaxy.network
```
*Очакван резултат: В `ADDITIONAL SECTION` се вижда IP 38.242.249.205.*

*PASS Проверка 2: Пълна DNS делегация (Trace)*
```bash
dig NS netgalaxy.network +trace
```
*Очакван резултат: В края на списъка се виждат твоите неймсървъри `ns1` и `ns2`.*

**Краен резултат**

Домейнът **netgalaxy.network** е успешно делегиран към собствените DNS сървъри.

GLUE записите сочат към:

```text
ns1.netgalaxy.network → 38.242.249.205
ns2.netgalaxy.network → 65.108.12.147
```

Делегацията е активна и DNS заявките се насочват към тези сървъри.

---

## Етап 2, Стъпка 5: Конфигуриране на Master сървър (ns1)

Настройване на основния DNS сървър (cp205) за управление на зоната и разрешаване на трансфера към вторичния сървър.

**5.1. Глобални настройки на Bind9**

Редактирайте `/etc/bind/named.conf.options`, за да добавите поддръжка за големи DNSSEC пакети и трансферни права:

```bash
sudo nano /etc/bind/named.conf.options
```

Добавете/редактирайте следните редове вътре в блока `options { ... };`:

```text
    listen-on { any; };
    listen-on-v6 { any; };
    allow-query { any; };

    dnssec-validation auto;
    auth-nxdomain no;
    allow-recursion { 127.0.0.1; ::1; };
    edns-udp-size 1232;
    max-udp-size 1232;

    allow-transfer { 65.108.12.147; };
    also-notify    { 65.108.12.147; };
    notify yes;
```

**5.2. Дефиниране на зоната**

Добавете дефиницията на домейна в `/etc/bind/named.conf.local`:

Отворете файла:

```bash
sudo nano /etc/bind/named.conf.local
```

Въведете следния блок:

```text
zone "netgalaxy.network" {
    type master;
    file "/etc/bind/zones/netgalaxy.network.db";
};
```

*PASS проверка на конфигурацията:*

```bash
sudo named-checkconf
```

**Очакван резултат:** Командата не трябва да връща никакъв изход (това означава липса на синтактични грешки).

---

## Етап 2, Стъпка 6: Създаване на зоновия файл (Master)

Създаване на основния файл с DNS записи за домейна на сървър **cp205**.

**6.1. Създаване на файла**

Изпълнете командата за създаване на празен файл в правилната директория:

```bash
sudo mkdir -p /etc/bind/zones
sudo chown bind:bind /etc/bind/zones
sudo nano /etc/bind/zones/netgalaxy.network.db
sudo chown bind:bind /etc/bind/zones/netgalaxy.network.db
```

**6.2. Попълване на DNS записите**

Копирайте и поставете следното съдържание (заменете датата в Serial, ако е необходимо):

```text
$TTL 86400
@   IN  SOA ns1.netgalaxy.network. admin.netgalaxy.network. (
        2026040601 ; Serial (YYYYMMDDnn)
        86400      ; Refresh
        7200       ; Retry
        2419200    ; Expire
        3600 )     ; Minimum TTL

@       IN  NS  ns1.netgalaxy.network.
@       IN  NS  ns2.netgalaxy.network.

ns1     IN  A     38.242.249.205
ns1     IN  AAAA  2A02:C206:2240:6856::1

ns2     IN  A     65.108.12.147
ns2     IN  AAAA  2A01:4F9:6A:485E::2

@       IN  A     38.242.249.205
www     IN  CNAME netgalaxy.network.
```

**6.3. Проверка на синтаксиса на зоната**

Преди да презаредите Bind, проверете дали файлът е написан правилно:

```bash
sudo named-checkzone netgalaxy.network /etc/bind/zones/netgalaxy.network.db
```

*Очакван резултат PASS:*
`zone netgalaxy.network/IN: loaded serial 2026040601`
`OK`

**6.4. Активиране на зоната**

Презаредете конфигурацията на Bind, за да започне обслужването на зоната:

```bash
sudo rndc reload
sudo rndc zonestatus netgalaxy.network
```

*Очакван резултат:*

В изхода трябва да присъстват редове от типа:

```
type: master
file: /etc/bind/zones/netgalaxy.network.db
```

---

## Етап 2, Стъпка 7: Настройка на Reverse DNS

Настройването на PTR записи (Reverse DNS) е критично за избягване на спам филтри и за преминаване на DNSSEC тестовете за валидация.

**7.1. Конфигурация на сървъра cp205**

>7.1.1. Влезте в провайдерския профил на сървъра cp205.  
7.1.2. Отворете секцията **Reverse DNS Management**.  
7.1.3. Конфигурирайте IPv4 адреса **38.242.249.205** със следните стойности:

   * **TTL:** `86400`
   * **PTR Record:** `ns1.netgalaxy.network`

>7.1.4. Конфигурирайте IPv6 адреса: **2a02:c206:2240:6856::1** със същите стойности:

   * **TTL:** `86400`
   * **PTR Record:** `ns1.netgalaxy.network`

**7.2. Конфигурация на сървъра D2**

>**7.2.1.** Влезте в провайдерския профил на сървъра D2.  
**7.2.2.** Навигирайте до **Robot / Server**.  
**7.2.3.** Изберете сървъра **D2** с IP **65.108.12.147**  
**7.2.4.** В полето **Reverse DNS entry** въведете `ns2.netgalaxy.network` и натиснете **Enter**  
**7.2.5.** Под заглавието `Subnets` кликнете върху малката икона плюс (+) точно пред квадратчето до IPv6 адреса.   Това ще разгърне списъка и ще ти позволи да добавяте записи за конкретни IPv6 адреси в рамките на тази мрежа.  
**7.2.6.** Кликнете върху линка `Add new Reverse DNS entry` за въвеждане на PTR записа.  
**7.2.7.** Въведете в полето `IP adresses`:

```
2a01:4f9:6a:485e::2.
```

>**7.2.8.** Въведете в полето `Reverse DNS entry`:

```
ns2.netgalaxy.network
```

>**7.2.9.** Кликнете върху бутона `Create` или натиснете `Enter` за запазване на настройката.

**ВАЖНО:** Промяната на Reverse DNS не е моментална. Изчакайте между **30 и 60 минути**, преди да преминете към проверката, за да може информацията да се разпространи в глобалната мрежа.

**7.3. PASS проверка: Валидация на PTR записите**

Изпълнете следните команди от вашия терминал (iMac или локален сървър), за да потвърдите, че обратните записи (Reverse DNS) са активни и се разпознават правилно от света.

**Проверка за сървър ns1 (cp205):**

```bash
# Проверка за IPv4
host 38.242.249.205

# Проверка за IPv6
host 2a02:c206:2240:6856::1
```

*Очакван резултат PASS (ns1):*

Командите трябва да върнат следните низове:

`38.242.249.205.in-addr.arpa domain name pointer ns1.netgalaxy.network.`
`1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.6.5.8.6.0.4.2.2.6.0.2.c.2.0.a.2.ip6.arpa domain name pointer ns1.netgalaxy.network.`

**Проверка за сървър ns2 (D2):**

```bash
# Проверка за IPv4
host 65.108.12.147

# Проверка за IPv6
host 2a01:4f9:6a:485e::2
```

*Очакван резултат PASS (ns2):*

Командите трябва да върнат следните низове:

`147.12.108.65.in-addr.arpa domain name pointer ns2.netgalaxy.network.`
`2.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.e.5.8.4.a.6.0.0.9.f.4.1.0.a.2.ip6.arpa domain name pointer ns2.netgalaxy.network.`

**Забележка:** Ако вместо името на сървъра получите съобщение `not found` или `NXDOMAIN`, проверете отново настройките в панелите на Contabo и Hetzner и изчакайте още 15-30 минути за опресняване на глобалните DNS кешове.

---

## Етап 2, Стъпка 8: Конфигуриране на вторичен сървър (Slave / ns2)

Целта на тази стъпка е да настроим сървъра **D2** автоматично да репликира (копира) зоната от основния сървър в **cp205**.

**8.1. Дефиниране на зоната на сървър D2 (Hetzner)**

На този сървър **не** се създават ръчно файлове със записи и **не** се генерират ключове. Той само приема данни. Отворете конфигурационния файл:

```bash
sudo nano /etc/bind/named.conf.local
```

*Добавете следния блок:*

```text
zone "netgalaxy.network" {
    type slave;
    masters { 38.242.249.205; };
    file "/var/cache/bind/netgalaxy.network.db";
};
```

**8.2. Проверка и активиране**

Проверете конфигурацията за грешки и презаредете Bind на **D2**:

```bash
sudo named-checkconf
sudo rndc reload
```

*PASS проверка: Валидация на трансфера*

Проверете дали файлът на зоната е пристигнал успешно от Master сървъра и дали е достъпен в кеша:

```bash
ls -l /var/cache/bind/netgalaxy.network.db
```

*Очакван резултат PASS:*

Трябва да видите файла в списъка. След това изпълнете финалния тест от вашия iMac:

```bash
dig @65.108.12.147 netgalaxy.network SOA +short
```

**Краен резултат:** Командата трябва да върне същия сериен номер, който виждате на ns1 (например `2026040601`).

**Техническа бележка:**
Обърнете внимание, че на **ns2** файлът се съхранява в `/var/cache/bind/`. Това е стандартната директория за Slave зони в Ubuntu, тъй като Bind има права да пише в нея автоматично, без да се налага да променяме AppArmor настройките (както направихме на ns1).

---



## Етап 2, Стъпка 9: Подготовка на инфраструктурата за DNSSEC

Преди да активираме подписването, трябва да подготвим директориите и да дадем нужните права на Bind9, за да може той да управлява ключовете и зоновите файлове.

**9.1. Създаване на директория за ключовете**

Изпълнете на **cp205**:
```bash
sudo mkdir -p /etc/bind/keys
sudo chown bind:bind /etc/bind/keys
sudo chmod 750 /etc/bind/keys
```

**9.2. Задаване на права върху зоните**

Bind се нуждае от права за запис в папката със зони, за да създава `.signed` и `.jnl` файловете.
```bash
sudo chown bind:bind /etc/bind/zones
sudo chmod 775 /etc/bind/zones
sudo chown bind:bind /etc/bind/zones/netgalaxy.network.db
```

**9.3. Настройка на AppArmor (Критично)**

За да може системата да позволи на Bind да записва в новата папка `/etc/bind/keys`, трябва да добавим изключение:
```bash
echo "/etc/bind/keys/** rw," | sudo tee -a /etc/apparmor.d/local/usr.sbin.named
sudo systemctl reload apparmor
```

---

## Етап 2, Стъпка 10: Активиране на DNSSEC и автоматичното подписване

След като инфраструктурата е готова, преминаваме към реалното пускане на защитата.

**10.1. Промяна на конфигурационния файл**

Отворете `/etc/bind/named.conf.local` и добавете параметрите за сигурност:

```bash
sudo nano /etc/bind/named.conf.local
```

Добавете в блока на зоната:

```text
    key-directory "/etc/bind/keys";
    dnssec-policy default;
    inline-signing yes;
```

Трябва да стане така:

```
zone "netgalaxy.network" {
    type master;
    file "/etc/bind/zones/netgalaxy.network.db";
    allow-transfer { 65.108.12.147; };

    key-directory "/etc/bind/keys";
    dnssec-policy default;
    inline-signing yes;
};
```

**10.2. Актуализиране на серийния номер (Serial)**

Отворете зоновия файл и увеличете серийния номер (например от `...01` на `...02`), за да отразите промяната:
```bash
sudo nano /etc/bind/zones/netgalaxy.network.db
```

**10.3. Стартиране на процеса по подписване**

Презаредете конфигурацията, за да започне автоматичното генериране на ключове:
```bash
sudo rndc reload netgalaxy.network
sudo rndc notify netgalaxy.network
```

**10.4. Проверка (PASS)**

Изчакайте 10 секунди, докато Bind извърши математическите изчисления, и проверете за наличие на цифрови подписи:
```bash
dig @38.242.249.205 netgalaxy.network +dnssec
```
**Очакван резултат:** В секцията `ANSWER` трябва да видите редове с **`RRSIG`**.

---

## Етап 2, Стъпка 11: Извличане на DNSSEC ключове (DS записи)

След като в Стъпка 3 активирахме `dnssec-policy`, Bind автоматично е генерирал ключове в директорията `/etc/bind/keys`. Сега трябва да извлечем данните, които се подават към регистратора на домейна, за да се затвори веригата на доверие.

**11.1. Намиране на генерирания ключ**

Влезте в папката с ключовете и проверете имената на генерираните файлове:

```bash
ls /etc/bind/keys
```

**Очакван резултат:** Трябва да видите файлове, започващи с `Knetgalaxy.network...`. Търсим файла с разширение **.key**.

**11.2. Генериране на DS запис**

Използвайте инструмента `dnssec-dsfromkey`, за да извлечете записа от публичния ключ (заменете името на файла с вашето реално име от предната стъпка):

```bash
cd /etc/bind/keys
dnssec-dsfromkey Knetgalaxy.network.+013+XXXXX.key
```

**Очакван резултат PASS:**
Командата ще върне два реда, изглеждащи по този начин:
`netgalaxy.network. IN DS 61423 13 2 86400... (дълъг хеш)`

## Етап 2, Стъпка 12: Регистрация на ключа в BookMyName

1. Влезте в контролния панел на **BookMyName**.
2. Отворете управлението на DNSSEC за `netgalaxy.network`.
3. Въведете данните от получения резултат:
   * **Key ID / Tag:** (в примера: `61423`)
   * **Algorithm:** `13` (ECDSA Curve P-256 with SHA-256)
   * **Digest Type:** `2` (SHA-256)
   * **Digest:** (дългият хеш от края на реда)

**ВАЖНО:** Изчакайте около **1-2 часа** за опресняване на кеша на Root сървърите.

---

## Етап 2, Стъпка 13: ФИНАЛНА ПРОВЕРКА

**1. Проверка на DNSSEC верига на доверие**

*Код за терминала (локален компютър)*

```
delv @8.8.8.8 netgalaxy.network +rtrace
```

*Очакван резултат*

```
; fully validated
netgalaxy.network.      IN      A       38.242.249.205
netgalaxy.network.      IN      RRSIG   A ...
```

**PASS:** Налице е ред "fully validated"

**2. Проверка на DNSSEC отговор от ns1**

*Код за терминала (локален компютър)*

```
dig @38.242.249.205 netgalaxy.network +dnssec
```

*Очакван резултат*

```text
netgalaxy.network.      IN      A       38.242.249.205
netgalaxy.network.      IN      RRSIG   A ...
```

**PASS:** Налице е запис RRSIG

**3. Проверка на DNSSEC отговор от ns2**

*Код за терминала (локален компютър)*

```
dig @65.108.12.147 netgalaxy.network +dnssec
```

*Очакван резултат**

```
netgalaxy.network.      IN      A       38.242.249.205
netgalaxy.network.      IN      RRSIG   A ...
```

**PASS:** Налице е запис RRSIG

**4. Проверка на авторитетност на ns2**

*Код за терминала (локален компютър)*

```bash
dig @65.108.12.147 netgalaxy.network SOA
```

*Очакван резултат*

```
flags: qr aa
```

**PASS:** 

```
В реда **flags** присъства **aa**
```

**5. Проверка на синхронизация между ns1 и ns2**

*Код за терминала (локален компютър)*

```
dig @38.242.249.205 netgalaxy.network SOA +short
dig @65.108.12.147 netgalaxy.network SOA +short
```

*Очакван резултат PASS*

```
Двата резултата са идентични (особено Serial номера)
```

**6. Визуална проверка (DNSViz)**

*Отворете:*

👉 [https://dnsviz.net](https://dnsviz.net)

👉 Въведете: `netgalaxy.network`

*PASS*

```
Няма червени стрелки или предупреждения.
```
**7. Проверка с DNSSEC Debugger**

*Отворете:*

👉 [https://dnssec-debugger.verisignlabs.com/netgalaxy.network](https://dnssec-debugger.verisignlabs.com/netgalaxy.network)

*PASS*

```text
Всички проверки са със зелена отметка (✓)
```

---

### PASS (общ)

```text
PASS: DNS инфраструктурата е напълно валидна и синхронизирана
```

---

## Етап 2, Стъпка 14: ОТЧЕТ ЗА ИЗПЪЛНЕНИЕ НА ЗАДАЧИТЕ

**Към Инсталационен протокол № 2 (NG-D2-v.0.1)**

**Дата на завършване:** 02.04.2026
**Изпълнител:** Илко Йорданов
**Обект:** DNS инфраструктура (cp205 + D2)
**Статус:** <span style="color:green">✅ УСПЕШНО ЗАВЪРШЕН</span>

---

### 1. РЕЗЮМЕ НА ИЗПЪЛНЕНИЕТО / EXECUTIVE SUMMARY

Всички заложени задачи по Инсталационен протокол № 2 са изпълнени успешно съгласно стандартите на проекта NetGalaxy. Изградена е пълноценна DNS инфраструктура за домейна **netgalaxy.network**, базирана на архитектура **MASTER / SLAVE**, с активирана DNSSEC защита и валидирана глобална резолюция.

Изпълнените дейности включват:

* **DNS Servers:** BIND9 MASTER (`ns1` – cp205) и SLAVE (`ns2` – D2)
* **Domain delegation:** GLUE записи и активна делегация
* **Zone configuration:** SOA, NS, A, AAAA записи
* **Reverse DNS:** PTR записи за IPv4 и IPv6
* **Zone transfer:** автоматична синхронизация (AXFR)
* **Security:** DNSSEC с `inline-signing` и `dnssec-policy`
* **Validation:** успешно премината глобална DNSSEC валидация

---

### 2. ДЕТАЙЛЕН ПРЕГЛЕД НА ЗАДАЧИТЕ / TASK DETAILS

| Задача / Task              | Статус | Коментар / Technical Note                                    |
| :------------------------- | :----: | :----------------------------------------------------------- |
| **Bind9 Installation**     |  PASS  | `bind9`, `bind9-utils`, `dnsutils` инсталирани на cp205 и D2 |
| **Firewall (cp205)**       |  PASS  | Отворени портове `32240/tcp`, `53/tcp`, `53/udp`             |
| **Firewall (D2)**          |  PASS  | Отворени портове `59623/tcp`, `53/tcp`, `53/udp`             |
| **GLUE Records**           |  PASS  | `ns1` и `ns2` регистрирани с IPv4 и IPv6                     |
| **Domain Delegation**      |  PASS  | Делегацията към собствените DNS сървъри е активна            |
| **DNS MASTER (cp205)**     |  PASS  | Конфигурирана master зона                                    |
| **Zone File Creation**     |  PASS  | Валиден SOA и ресурсни записи                                |
| **Reverse DNS (PTR)**      |  PASS  | PTR записи активни за двата сървъра                          |
| **DNS SLAVE (D2)**         |  PASS  | Зоната се репликира автоматично                              |
| **Zone Transfer (AXFR)**   |  PASS  | Серийните номера съвпадат                                    |
| **DNSSEC Preparation**     |  PASS  | Права и AppArmor конфигурирани                               |
| **DNSSEC Activation**      |  PASS  | Подписването работи (`RRSIG` наличен)                        |
| **DS Record Registration** |  PASS  | DS запис извлечен и регистриран                              |
| **DNSSEC Validation**      |  PASS  | `fully validated` резултат                                   |
| **Authoritative Response** |  PASS  | `aa` флаг наличен                                            |
| **External Validation**    |  PASS  | DNSViz и Verisign проверки успешни                           |

---

### 3. ПОДДРЪЖКА НА ЕЗИЦИ / LANGUAGE COMPLIANCE

В съответствие с изискванията на NetGalaxy, документацията и работната среда поддържат:

1. **Български:** основен език на протокола и техническите описания
2. **English:** системни логове, shell output, DNS отговори
3. **Русский:** поддръжка на локализационна съвместимост в рамките на проекта

---

### 4. КЛЮЧОВИ КОНФИГУРАЦИИ / KEY CONFIGURATIONS

За бъдещи справки и автоматизация са валидни следните параметри:

```bash
# Проверка на DNS MASTER
dig @38.242.249.205 netgalaxy.network

# Проверка на DNS SLAVE
dig @65.108.12.147 netgalaxy.network

# Проверка на DNSSEC
dig @38.242.249.205 netgalaxy.network +dnssec

# Проверка на DNSSEC валидност
delv @8.8.8.8 netgalaxy.network +rtrace

# Проверка на синхронизация
dig @38.242.249.205 netgalaxy.network SOA +short
dig @65.108.12.147 netgalaxy.network SOA +short

# Проверка на reverse DNS
host 38.242.249.205
host 65.108.12.147

# Проверка на firewall
sudo ufw status
```

---

### 5. ЗАКЛЮЧЕНИЕ / CONCLUSION

DNS инфраструктурата на NetGalaxy е успешно изградена и функционира стабилно в продукционен режим. Всички PASS проверки по протокола са преминати успешно.

Системата е защитена и надеждна, благодарение на:

* независими MASTER и SLAVE DNS сървъри
* автоматична синхронизация на зоните
* активна DNSSEC защита
* валидирана верига на доверие
* коректно конфигуриран reverse DNS

DNS слоят е в пълна оперативна готовност и може да обслужва всички бъдещи услуги в рамките на NetGalaxy инфраструктурата.

---

**Подпис:** ............................
*(Илко Йорданов)*

**Copyright:** © 2026 NetGalaxy™ | **Confidential**

---

### 6. ДЕТАЙЛНА СПЕЦИФИКАЦИЯ НА ТРУДА (BY STEPS)

| Стъпка от Протокола | Описание на дейността | Категория | Норматив (мин) | Коментар |
| :--- | :--- | :---: | :---: | :--- |
| **Стъпка 1** | Инсталиране на BIND9 | **Level C** | 5 | Стандартна инсталация |
| **Стъпка 2** | Конфигуриране на firewall (cp205) | **Level B** | 10 | Сигурност на порта |
| **Стъпка 3** | Конфигуриране на firewall (D2) | **Level B** | 10 | Сигурност на порта |
| **Стъпка 4** | Регистрация на GLUE записи | **Level A** | 15 | Външна регистрация |
| **Стъпка 5** | Конфигуриране на DNS MASTER | **Level A** | 15 | Архитектурна настройка |
| **Стъпка 6** | Създаване на зонов файл | **Level A** | 15 | DNS записи |
| **Стъпка 7** | Настройка на Reverse DNS | **Level A** | 15 | PTR записи (Hetzner/Contabo) |
| **Стъпка 8** | Конфигуриране на DNS SLAVE | **Level A** | 15 | Master-Slave репликация |
| **Стъпка 9** | Подготовка за DNSSEC | **Level B** | 10 | Права и AppArmor |
| **Стъпка 10** | Активиране на DNSSEC | **Level A** | 15 | Подписване на зоната |
| **Стъпка 11** | Извличане на DS запис | **Level A** | 10 | Генериране на хеш |
| **Стъпка 12** | Регистрация на DS в BookMyName | **Level A** | 20 | Критична външна верификация |
| **Стъпка 13** | Финална пълна проверка | **Level A** | 25 | DNSViz, Debugger, репликация |
| **Стъпка 14** | Документиране и калкулиране на изпълнението  | **Level B** | 20 | Пълно документиране |

---

### 7. СУМАРНА КАРТА НА ТРУДОВИЯ ПРИНОС (LABOR VALUE MAP)

| Група дейности | Категория труд | Общо мин. | Ставка (€/час) | Стойност (€) |
| :--- | :---: | :---: | :---: | :---: |
| **I. Базова DNS подготовка** | **Level C** | **5** | **100.00** | **8.33** |
| **II. Конфигурация и интеграция** | **Level B** | **45** | **150.00** | **112.50** |
| **III. DNS архитектура и сигурност** | **Level A** | **150** | **250.00** | **625.00** |
| **ОБЩО ЗА ПРОТОКОЛА:** | | **200 мин.** | **Средна: 223.75** | **745.83 €** |

---

### 8. ДАННИ ЗА СМАРТ КОНТРАКТ (SMART CONTRACT PAYOUT)

* **ID на задачата:** NG-D2-INSTALL-P2
* **Валута на изчисление:** EUR / NetGalaxy Token (NGT)
* **Обща стойност:** **745.83 €**
* **Разпределение (съотношение 40/60):**
    * 💵 **Cash (40%):** **298.33 €**
    * 💎 **Tokens (60%):** **447.50 €**

---
