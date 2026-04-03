# NetGalaxy Network

## Инсталационен протокол № 2

### Етап 2 - Конфигуриране на хостинг за управление на сървъра (d2.netgalaxy.network)

---

### Информация за документа

**Проект:** NetGalaxy  
**Document ID:** NG-D2-v.0.1 – Installation protocol Nr.2.md  
**Дата:** 02.04.2026  
**Заглавие:** Инсталационен протокол № 2  
**Задачи за изпълнение:**

  * Инсталиране на DNS сървър (Bind9)
  * Пренасочване на домейна към DNS сървърите на netgalaxy.network
  * Конфигуриране на ns1.netgalaxy.network (сървър cp205)
  * Конфигуриране на ns2.netgalaxy.network (сървър D2)
  * Създаване на директории за административния хостинг
  * Създаване на index.html („Under Construction“) за административния хостинг
  * Конфигуриране на домейн d2.netgalaxy.network
  * Конфигуриране на Nginx за работа с домейна d2.netgalaxy.network
  * Инсталиране на SSL сертификат за d2.netgalaxy.network
  * Създаване на системен потребител и група за административния сайт
  * Ограничаване на достъпа до административни ресурси
  * Ограничаване на достъпа до уеб директорията (permissions и ownership)
  * Конфигуриране и проверка на firewall (UFW)
  * Активиране на firewall
  * Активиране на логове (access/error logs)
  * Настройка на логовата ротация
  * Проверка на хостинга (PASS)

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

Инсталиране на DNS сървър BIND9 и необходимите инструменти за управление и диагностика.

**Код за терминала**

```bash
sudo apt update && sudo apt install -y bind9 bind9-utils bind9-dnsutils
```

**Очакван резултат**

* Пакетите `bind9`, `bind9-utils` и `bind9-dnsutils` са инсталирани
* DNS услугата е налична в системата

**PASS проверка**

```bash
systemctl is-active bind9
```

Очакван резултат:

```text
active
```

---

## Етап 2, Стъпка 2: Пренасочване на домейна към DNS сървърите на netgalaxy.network

Свързване на домейна **netgalaxy.network** със DNS сървърите на мрежата NetGalaxy чрез GLUE записи и задаване на nameserver-и при регистратора.

**Действие (извън терминала)**

В контролния панел на регистратора BookMyName:

1. Създайте DNS сървъри (GLUE записи)**

```text
ns1.netgalaxy.network → 38.242.249.205
ns2.netgalaxy.network → 65.108.12.147
```

2. Добавете и съответните IPv6 адреси:

```text
ns1.netgalaxy.network → 2a02:c206:2240:6856::1
ns2.netgalaxy.network → 2a01:4f9:6a:485e::2
```

3. Проверете зададените DNS сървъри за домейна `netgalaxy.network`

```text
ns1.netgalaxy.network
ns2.netgalaxy.network
```

**PASS Проверка: Пълна DNS верига (trace)**

```bash
dig NS netgalaxy.network +trace
```

**PASS резултат:**

В края на trace-а трябва да се виждат:

```text
netgalaxy.network.    NS    ns1.netgalaxy.network.
netgalaxy.network.    NS    ns2.netgalaxy.network.
```

**Краен резултат**

Домейнът **netgalaxy.network** е успешно делегиран към собствените DNS сървъри.

GLUE записите сочат към:

```text
ns1.netgalaxy.network → 38.242.249.205
ns2.netgalaxy.network → 65.108.12.147
```

Делегацията е активна и DNS заявките се насочват към тези сървъри.

---

## Етап 2, Стъпка 3: Конфигуриране на ns1.netgalaxy.network (сървър cp205)

Настройване на DNS сървъра **ns1.netgalaxy.network** (cp205) като master за зоната `netgalaxy.network`.

**1. Отваряне на конфигурационния файл:**

```bash
sudo nano /etc/bind/named.conf.local
```

Добавяне/промяна на зоната:

```text
zone "netgalaxy.network" {
    type master;
    file "/etc/bind/zones/netgalaxy.network.db";
    allow-transfer { 65.108.12.147; };
};
```

**2. Създаване на директория за зоните:**

```bash
sudo mkdir -p /etc/bind/zones
```

**3. Създаване на zone файла:**

```bash
sudo nano /etc/bind/zones/netgalaxy.network.db
```

Добавяне на  съдържание на zone файла:

```dns
$TTL 3600
@   IN  SOA ns1.netgalaxy.network. admin.netgalaxy.network. (
        2026040202 ; Serial
        3600       ; Refresh
        1800       ; Retry
        1209600    ; Expire
        86400 )    ; Minimum TTL

@       IN  NS  ns1.netgalaxy.network.
@       IN  NS  ns2.netgalaxy.network.

ns1     IN  A   38.242.249.205
ns2     IN  A   65.108.12.147
```

*Проверка на конфигурацията:*

```bash
sudo named-checkconf
```

*Проверка на зоната:*

```bash
sudo named-checkzone netgalaxy.network /etc/bind/zones/netgalaxy.network.db
```

**4. Рестартиране на DNS сървъра:**

```bash
sudo systemctl restart bind9
```

**PASS Проверка**

```bash
dig @38.242.249.205 netgalaxy.network
```

**PASS резултат:**

```text
status: NOERROR
```

и наличен SOA запис:

```text
netgalaxy.network.    IN    SOA    ns1.netgalaxy.network. admin.netgalaxy.network.
```

**Краен резултат**

DNS сървърът **ns1.netgalaxy.network (cp205)** е конфигуриран като master за зоната `netgalaxy.network` и отговаря коректно на DNS заявки.

---

## Етап 2, Стъпка 4: Конфигуриране на ns2.netgalaxy.network (сървър D2)

Настройване на DNS сървъра **ns2.netgalaxy.network (D2)** като slave за зоната `netgalaxy.network`, който получава данните от master сървъра **ns1 (cp205)**.

**1. Отваряне на конфигурационния файл:**

```bash
sudo nano /etc/bind/named.conf.local
```

Добавяне на зоната:

```text
zone "netgalaxy.network" {
    type slave;
    masters { 38.242.249.205; };
    file "/var/cache/bind/netgalaxy.network.db";
};
```

**2. Създаване на директория (ако не съществува):**

```bash
sudo mkdir -p /var/cache/bind
sudo chown bind:bind /var/cache/bind
```

**3. Проверка на конфигурацията:**

```bash
sudo named-checkconf
```

Очакван резултат

```
(няма изход)
```

**4. Рестартиране на DNS сървъра:**

```bash
sudo systemctl restart bind9
```

**PASS Проверка**

```bash
dig @65.108.12.147 netgalaxy.network
```

**PASS резултат:**

```text
status: NOERROR
```

и наличен SOA запис:

```text
netgalaxy.network.    IN    SOA    ns1.netgalaxy.network. admin.netgalaxy.network.
```

**Краен резултат**

DNS сървърът **ns2.netgalaxy.network (D2)** е конфигуриран като slave и успешно получава зоната `netgalaxy.network` от master сървъра **cp205**, като отговаря коректно на DNS заявки.

---

## Етап 2, Стъпка 5: Създаване на директории за административния хостинг

**Кратка цел**
Създаваме основната директория за служебния уеб хостинг и поддиректорията с непредсказуемо име, която ще се използва за административния достъп.

**Код за терминала**

```bash
sudo mkdir -p /srv/www-admin/cpanel_f7D1k6/public
```

**Код за проверка**

```bash
sudo ls -ld /srv/www-admin /srv/www-admin/cpanel_f7D1k6 /srv/www-admin/cpanel_f7D1k6/public
```

**Очакван резултат**

```bash
drwxr-xr-x 3 root root ... /srv/www-admin
drwxr-xr-x 3 root root ... /srv/www-admin/cpanel_f7D1k6
drwxr-xr-x 2 root root ... /srv/www-admin/cpanel_f7D1k6/public
```

**PASS проверка**

И трите директории съществуват и се виждат в изхода на командата за проверка.


✔ И трите директории съществуват
✔ Пътят е точно `/srv/www-admin/control.netgalaxy.network/public`
✔ Няма грешки при създаването

---

## Етап 2, Стъпка 6: Създаване на index.html („Under Construction“) за административния хостинг

Създаваме начална страница `index.html` в директорията `public`, която ще се показва при достъп до административния адрес. Тя указва, че услугата е в процес на разработка.

**Код за терминала**

```bash
sudo tee /srv/www-admin/cpanel_f7D1k6/public/index.html > /dev/null << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>NetGalaxy Control</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      margin: 0;
      background-color: #0f172a;
      color: #e5e7eb;
      font-family: Arial, sans-serif;
      display: flex;
      align-items: center;
      justify-content: center;
      height: 100vh;
    }
    .container {
      text-align: center;
    }
    h1 {
      color: #FCD170;
      font-size: 2.5em;
      margin-bottom: 0.5em;
    }
    p {
      font-size: 1.2em;
      color: #9ca3af;
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>NetGalaxy Control Panel</h1>
    <p>Server is under construction</p>
  </div>
</body>
</html>
EOF
```

**Код за проверка**

```bash
sudo ls -lh /srv/www-admin/cpanel_f7D1k6/public/index.html
```

**Очакван резултат**

```bash
-rw-r--r-- 1 root root ... /srv/www-admin/cpanel_f7D1k6/public/index.html
```

**PASS проверка**

Файлът `index.html` съществува в директорията `public` и има размер (не е празен).

---

## Етап 2, Стъпка 7: Конфигуриране на домейн d2.netgalaxy.network

В тази стъпка отваряме DNS сървъра на cp205 (MASTER) и вписваме домейна за управление на сървъра `d2.netgalaxy.network`, като го насочваме към сървъра D2.

**Код за терминала (cp205)**
Добавяне на DNS запис за домейна `d2.netgalaxy.network`, който сочи към IP адреса на D2.

```bash id="7xk2qp"
sudo nano /etc/bind/zones/netgalaxy.network.db
```

**Действие в отворения файл**

1. Увеличаваме Serial с 1 (например от 2026040202 на 2026040203).

2. Добавяме в края на файла следния запис:

```dns id="s3k9lw"
d2    IN    A    65.108.12.147
```

**Код за проверка (локално на cp205)**

```bash id="j1m8fd"
sudo named-checkzone netgalaxy.network /etc/bind/zones/netgalaxy.network.db
```

**Очакван резултат**

```bash id="k8w2vz"
zone netgalaxy.network/IN: loaded serial ...
OK
```

**Код за прилагане на промените**

```bash id="p4n2ys"
sudo systemctl reload bind9
```

**Код за външна проверка**

```bash id="x9q3rt"
dig d2.netgalaxy.network +short
```

**Очакван резултат**

```bash id="c7m1lu"
65.108.12.147
```

**PASS проверка**

Домейнът `d2.netgalaxy.network` се резолвира към IP адреса на D2.

---

## Етап 2, Стъпка 8: Конфигуриране на Nginx за работа с домейна d2.netgalaxy.network

Създаваме Nginx конфигурация за домейна `d2.netgalaxy.network`, насочваме я към уеб директорията `public`, активираме сайта и презареждаме Nginx.

**Кратка цел**
Настройване на Nginx да обслужва домейна `d2.netgalaxy.network` от директорията `/srv/www-admin/cpanel_f7D1k6/public`.

**Код за терминала**

```bash id="g7n2xk"
sudo tee /etc/nginx/sites-available/d2.netgalaxy.network > /dev/null << 'EOF'
server {
    listen 80;
    listen [::]:80;

    server_name d2.netgalaxy.network;

    root /srv/www-admin/cpanel_f7D1k6/public;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
EOF

sudo ln -sfn /etc/nginx/sites-available/d2.netgalaxy.network /etc/nginx/sites-enabled/d2.netgalaxy.network
sudo nginx -t
sudo systemctl reload nginx
```

**Код за проверка**

```bash id="k3p9vs"
sudo nginx -T | grep -A 12 "server_name d2.netgalaxy.network"
curl -I -H "Host: d2.netgalaxy.network" http://127.0.0.1/
```

**Очакван резултат**

```bash id="q8x1md"
server_name d2.netgalaxy.network;
root /srv/www-admin/cpanel_f7D1k6/public;
index index.html;
```

и от `curl`:

```bash id="w2z7lc"
HTTP/1.1 200 OK
```

**PASS проверка**

* `sudo nginx -t` завършва с `syntax is ok` и `test is successful`
* `curl -I -H "Host: d2.netgalaxy.network" http://127.0.0.1/` връща `HTTP/1.1 200 OK`

---

## Етап 2, Стъпка 9: Инсталиране на SSL сертификат за d2.netgalaxy.network

Инсталираме SSL сертификат от Let’s Encrypt чрез Certbot и автоматично конфигурираме Nginx да работи през HTTPS.

**Кратка цел**
Активиране на HTTPS за домейна `d2.netgalaxy.network` с валиден SSL сертификат.

**Код за терминала**

```bash
sudo apt update && sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d d2.netgalaxy.network --non-interactive --agree-tos -m yordanov.netgalaxy@gmail.com --redirect
```

**Код за проверка**

```bash
sudo nginx -T | grep -A 8 "server_name d2.netgalaxy.network"
curl -I https://d2.netgalaxy.network
```

**Очакван резултат**

В конфигурацията трябва да се появят SSL настройки, например:

```bash
listen 443 ssl;
ssl_certificate /etc/letsencrypt/live/d2.netgalaxy.network/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/d2.netgalaxy.network/privkey.pem;
```

И от `curl`:

```bash
HTTP/2 200
```

**PASS проверка**

* HTTPS е активен и достъпен
* `curl -I https://d2.netgalaxy.network` връща `HTTP/2 200`
* Отворете в браузър:

```text
https://d2.netgalaxy.network
```

* Страницата се зарежда без предупреждения за сигурност (валиден SSL сертификат)

---

## Етап 2, Стъпка 10: Създаване на системен потребител и група за административния сайт

Създаваме изолиран системен потребител и група за административния хостинг, след което задаваме собственост на уеб директорията. Това гарантира разделение и контрол на достъпа.

**Кратка цел**
Създаване на изолиран потребител и група и задаване на ownership върху `/srv/www-admin/cpanel_f7D1k6`.

**Код за терминала**

```bash
sudo groupadd --system grp_cpanel_f7D1k6
sudo useradd --system --no-create-home --shell /usr/sbin/nologin -g grp_cpanel_f7D1k6 usr_cpanel_f7D1k6
sudo chown -R usr_cpanel_f7D1k6:grp_cpanel_f7D1k6 /srv/www-admin/cpanel_f7D1k6
```

**Код за проверка**

```bash
id usr_cpanel_f7D1k6
sudo ls -ld /srv/www-admin/cpanel_f7D1k6
sudo ls -ld /srv/www-admin/cpanel_f7D1k6/public
```

**Очакван резултат**

```bash
uid=... (usr_cpanel_f7D1k6) gid=... (grp_cpanel_f7D1k6)
drwxr-xr-x ... usr_cpanel_f7D1k6 grp_cpanel_f7D1k6 /srv/www-admin/cpanel_f7D1k6
drwxr-xr-x ... usr_cpanel_f7D1k6 grp_cpanel_f7D1k6 /srv/www-admin/cpanel_f7D1k6/public
```

**PASS проверка**

* Потребителят `usr_cpanel_f7D1k6` съществува
* Групата `grp_cpanel_f7D1k6` съществува
* Директорията е собственост на:

```bash
usr_cpanel_f7D1k6:grp_cpanel_f7D1k6
```

---

## Етап 2, Стъпка 11: Ограничаване на достъпа до административни ресурси

Забраняваме директен уеб достъп до чувствителни директории и файлове (напр. `config`, `logs`, скрити файлове), за да предотвратим изтичане на информация и неоторизиран достъп.

**Кратка цел**
Ограничаване на достъпа до чувствителни ресурси за административния хостинг.

**Код за терминала**

```bash id="0xk9sj"
sudo tee /etc/nginx/snippets/d2.netgalaxy.network_restrictions.conf > /dev/null << 'EOF'
# Забрана за достъп до скрити файлове (.env, .git, .htaccess и др.)
location ~ /\. {
    deny all;
}

# Забрана за директории извън public (ако бъдат достъпени по грешка)
location ^~ /config/ {
    deny all;
}

location ^~ /logs/ {
    deny all;
}

# Забрана за потенциално чувствителни файлове
location ~* \.(env|ini|log|conf|bak|sql)$ {
    deny all;
}
EOF

sudo sed -i '/server_name d2.netgalaxy.network;/a \    include /etc/nginx/snippets/d2.netgalaxy.network_restrictions.conf;' /etc/nginx/sites-available/d2.netgalaxy.network

sudo nginx -t
sudo systemctl reload nginx
```

**Код за проверка**

```bash id="m2x7vp"
curl -I https://d2.netgalaxy.network/.env
curl -I https://d2.netgalaxy.network/config/
curl -I https://d2.netgalaxy.network/test.log
```

**Очакван резултат**

```bash id="l1z8qe"
HTTP/2 403
```

или:

```bash id="q7r3kn"
HTTP/1.1 403 Forbidden
```

**PASS проверка**

* Забранените ресурси през HTTPS връщат `403`
* Отвори в браузър:

```text
https://d2.netgalaxy.network/.env
https://d2.netgalaxy.network/config/
https://d2.netgalaxy.network/test.log
```

* Браузърът показва отказан достъп

---

## Етап 2, Стъпка 12: Ограничаване на достъпа до уеб директорията (permissions и ownership)

Задаваме строги права върху уеб директорията, така че:

* собственикът (`usr_cpanel_f7D1k6`) има пълен контрол
* групата има ограничен достъп
* всички останали имат само четене (без запис)

Това предотвратява неоторизирани промени и повишава сигурността.

**Кратка цел**
Задаване на сигурни права върху `/srv/www-admin/cpanel_f7D1k6` и съдържанието на `public`.

**Код за терминала**

```bash
sudo chmod 755 /srv/www-admin/cpanel_f7D1k6
sudo find /srv/www-admin/cpanel_f7D1k6/public -type d -exec chmod 755 {} \;
sudo find /srv/www-admin/cpanel_f7D1k6/public -type f -exec chmod 644 {} \;
```

**Код за проверка**

```bash
sudo ls -ld /srv/www-admin/cpanel_f7D1k6 /srv/www-admin/cpanel_f7D1k6/public
sudo find /srv/www-admin/cpanel_f7D1k6/public -printf "%M %u %g %p\n" | head -n 10
curl -I https://d2.netgalaxy.network
```

**Очакван резултат**

```bash
drwxr-xr-x usr_cpanel_f7D1k6 grp_cpanel_f7D1k6 /srv/www-admin/cpanel_f7D1k6
drwxr-xr-x usr_cpanel_f7D1k6 grp_cpanel_f7D1k6 /srv/www-admin/cpanel_f7D1k6/public
-rw-r--r-- usr_cpanel_f7D1k6 grp_cpanel_f7D1k6 /srv/www-admin/cpanel_f7D1k6/public/index.html
HTTP/1.1 200 OK
```

**PASS проверка**

* Директорията `/srv/www-admin/cpanel_f7D1k6` е с права `755`
* Директориите в `public` са с права `755`
* Файловете в `public` са с права `644`
* Няма права за запис за `others`
* Отвори в браузър:

```text
https://d2.netgalaxy.network
```

* Страницата се зарежда успешно

---

## Етап 2, Стъпка 13: Конфигуриране и проверка на firewall (UFW)

Конфигурираме firewall (UFW), като разрешаваме необходимите портове, но **не го активираме**, преди да извършим задължителна проверка.

**Кратка цел**
Подготовка на firewall с правилни правила и проверка преди активиране.

**Код за терминала**

```bash
sudo ufw allow 59623/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

**Код за проверка (ПРЕДИ АКТИВАЦИЯ)**

```bash
sudo ufw show added
sudo ufw status verbose
```

**Очакван резултат**

```text
ufw allow 59623/tcp
ufw allow 80/tcp
ufw allow 443/tcp
```

И статус:

```text
Status: inactive
```

**PASS проверка (ПРЕДИ АКТИВАЦИЯ)**

* Firewall е **inactive**
* Присъстват правилата:

  * 59623/tcp
  * 80/tcp
  * 443/tcp
* Няма други неочаквани правила

---

## Етап 2, Стъпка 14: Активиране на firewall

Активираме firewall само след успешна проверка.

**Кратка цел**
Безопасно активиране на UFW след потвърдени правила.

**Код за терминала**

```bash
sudo ufw enable
```

**Код за проверка**

```bash
sudo systemctl is-active ufw
sudo ufw status
curl -I https://d2.netgalaxy.network
```

**Очакван резултат**

```text
active
```

и:

```bash
HTTP/2 200
```

**PASS проверка**

* Firewall е активен
* SSH достъпът работи на порт `59623`
* Уеб достъпът (80/443) работи
* Сайтът се зарежда успешно:

```text
https://d2.netgalaxy.network
```

Това вече е напълно по NetGalaxy логиката:

* без риск
* без „магия“
* с контрол преди действие

---

## Етап 2, Стъпка 15: Активиране на логове (access/error logs)

Активираме access и error логове за домейна `d2.netgalaxy.network`, като ги записваме в отделна директория. Това позволява проследяване на трафика, грешките и евентуални проблеми със сигурността.

**Кратка цел**
Активиране на логове за административния хостинг в `/srv/www-admin/cpanel_f7D1k6/logs`.

**Код за терминала**

```bash
sudo mkdir -p /srv/www-admin/cpanel_f7D1k6/logs
sudo chown usr_cpanel_f7D1k6:grp_cpanel_f7D1k6 /srv/www-admin/cpanel_f7D1k6/logs
sudo chmod 750 /srv/www-admin/cpanel_f7D1k6/logs

sudo sed -i '/server_name d2.netgalaxy.network;/a \
    access_log /srv/www-admin/cpanel_f7D1k6/logs/access.log;\
    error_log /srv/www-admin/cpanel_f7D1k6/logs/error.log;' \
/etc/nginx/sites-available/d2.netgalaxy.network

sudo nginx -t
sudo systemctl reload nginx
```

**Код за проверка**

```bash
sudo ls -ld /srv/www-admin/cpanel_f7D1k6/logs
curl -I https://d2.netgalaxy.network
sudo tail -n 5 /srv/www-admin/cpanel_f7D1k6/logs/access.log
```

**Очакван резултат**

```bash
drwxr-x--- usr_cpanel_f7D1k6 grp_cpanel_f7D1k6 /srv/www-admin/cpanel_f7D1k6/logs
HTTP/1.1 200 OK
```

и в `access.log` трябва да има запис от заявката.

**PASS проверка**

* Директорията `logs` съществува
* Сайтът остава достъпен на:

```text
https://d2.netgalaxy.network
```

* В `access.log` се записват заявки
* `nginx -t` завършва успешно

---

## Етап 2, Стъпка 16: Настройка на логовата ротация

Настройваме автоматична логова ротация чрез `logrotate`, за да предотвратим неконтролирано нарастване на лог файловете и да осигурим стабилна работа на сървъра.

Използваме следните параметри:

#### `daily`

👉 върти логовете всеки ден
✔ достатъчно детайлно
✔ стандарт за уеб сървър

#### `rotate 14`

👉 пази 14 дни
✔ достатъчно за анализ
✔ не пълни диска

(може да стане 30 по-късно)

#### `compress`

👉 компресира старите логове
✔ пести място (много важно)

#### `delaycompress`

👉 не компресира последния лог веднага
✔ избягва проблеми с nginx

#### `missingok`

👉 ако файл липсва → няма грешка
✔ важно за стабилност

#### `notifempty`

👉 не върти празни логове
✔ избягва излишни файлове

#### `create 640 www-data www-data`

👉 създава нов лог файл с правилни права
✔ nginx може да пише
✔ други не могат

**Кратка цел**
Конфигуриране на `logrotate` за логовете в `/srv/www-admin/cpanel_f7D1k6/logs`.

**Код за терминала**

```bash
sudo tee /etc/logrotate.d/d2.netgalaxy.network > /dev/null << 'EOF'
/srv/www-admin/cpanel_f7D1k6/logs/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 640 www-data www-data
    sharedscripts
    postrotate
        systemctl reload nginx > /dev/null 2>&1 || true
    endscript
}
EOF
```

**Код за проверка**

```bash
sudo logrotate -d /etc/logrotate.d/d2.netgalaxy.network
```

**Очакван резултат**

* Няма грешки в изхода
* Показва се симулация на ротация

**PASS проверка**

* Конфигурационният файл съществува:

```bash
/etc/logrotate.d/d2.netgalaxy.network
```

* Командата:

```bash
sudo logrotate -d /etc/logrotate.d/d2.netgalaxy.network
```

завършва без грешки

* Сайтът остава достъпен:

```text
https://d2.netgalaxy.network
```

---

## Етап 2, Стъпка 17: Проверка на хостинга (PASS)

Извършваме финална проверка на хостинга, за да потвърдим, че всички компоненти работят коректно и сайтът е достъпен и защитен.

**Кратка цел**
Финална PASS проверка на хостинга за `d2.netgalaxy.network`.

**Код за терминала**

```bash
curl -I https://d2.netgalaxy.network
curl -I http://d2.netgalaxy.network
```

**Очакван резултат**

```bash
HTTP/2 200
```

и:

```bash
HTTP/1.1 301 Moved Permanently
```

(HTTP → HTTPS redirect)

**Допълнителна проверка (логове)**

```bash
sudo tail -n 5 /srv/www-admin/cpanel_f7D1k6/logs/access.log
```

Трябва да има запис от заявката.

**PASS проверка**

* Сайтът се отваря:

```text
https://d2.netgalaxy.network
```

* HTTPS работи без предупреждения
* HTTP се пренасочва към HTTPS
* Nginx отговаря с `200`
* Логовете записват заявки
* Няма грешки в достъпа

---

## ФИНАЛЕН ОТЧЕТ ЗА ИЗПЪЛНЕНИЕ

**Към Инсталационен протокол № 2 (NG-D2-v.0.1)**

**Дата на завършване:** 02.04.2026
**Изпълнител:** Илко Йорданов
**Обект:** Сървър D2 (IP: 65.108.12.147)
**Статус:** <span style="color:green">✅ УСПЕШНО ЗАВЪРШЕН</span>

### 1. РЕЗЮМЕ НА ИЗПЪЛНЕНИЕТО / EXECUTIVE SUMMARY

Всички заложени задачи по Инсталационен протокол № 2 са изпълнени успешно съгласно стандартите на проекта NetGalaxy. Изградена е работеща DNS инфраструктура за домейна `netgalaxy.network` в архитектура **MASTER / SLAVE**, а на сървъра **D2** е конфигуриран и защитен административен хостинг за домейна `d2.netgalaxy.network`.

Изпълнените дейности включват:

* **DNS:** BIND9 MASTER на `cp205` и BIND9 SLAVE на `D2`
* **Domain delegation:** `ns1.netgalaxy.network` и `ns2.netgalaxy.network`
* **Admin hosting:** `d2.netgalaxy.network`
* **Web stack:** Nginx + HTTPS (Let’s Encrypt)
* **Security:** изолиран системен потребител, ограничения за чувствителни ресурси, UFW
* **Observability:** access/error logs + logrotate

### 2. ДЕТАЙЛЕН ПРЕГЛЕД НА ЗАДАЧИТЕ / TASK DETAILS

| Задача / Task                    | Статус | Коментар / Technical Note                                                                       |
| :------------------------------- | :----: | :---------------------------------------------------------------------------------------------- |
| **Bind9 Installation**           |  PASS  | `bind9`, `bind9-utils`, `bind9-dnsutils` са инсталирани и активни.                              |
| **Domain Delegation**            |  PASS  | `netgalaxy.network` е делегиран към `ns1.netgalaxy.network` и `ns2.netgalaxy.network`.          |
| **DNS MASTER (cp205)**           |  PASS  | Конфигурирана е master зона `netgalaxy.network` с разрешен zone transfer към D2.                |
| **DNS SLAVE (D2)**               |  PASS  | D2 е конфигуриран като slave/secondary и обслужва зоната коректно.                              |
| **Admin Hosting Directory**      |  PASS  | Създадена е структура `/srv/www-admin/cpanel_f7D1k6/public`.                                    |
| **Initial Index Page**           |  PASS  | Създадена е начална страница “Under Construction”.                                              |
| **DNS Record for d2**            |  PASS  | `d2.netgalaxy.network` сочи към `65.108.12.147`.                                                |
| **Nginx Virtual Host**           |  PASS  | Активиран е отделен vhost за `d2.netgalaxy.network`.                                            |
| **SSL Certificate**              |  PASS  | HTTPS е активен чрез Let’s Encrypt, с валиден сертификат.                                       |
| **System Isolation User**        |  PASS  | Създадени са `usr_cpanel_f7D1k6` и `grp_cpanel_f7D1k6`.                                         |
| **Resource Access Restrictions** |  PASS  | Забранен е директният достъп до чувствителни ресурси (`.env`, `config`, `logs`, `*.log` и др.). |
| **Permissions & Ownership**      |  PASS  | Зададени са сигурни права върху `public` и ownership върху административния хостинг.            |
| **Firewall Preparation**         |  PASS  | UFW е конфигуриран с правила за `59623/tcp`, `80/tcp`, `443/tcp` преди активация.               |
| **Firewall Activation**          |  PASS  | UFW е активиран успешно след предварителна проверка.                                            |
| **Access/Error Logging**         |  PASS  | Логовете се записват в `/srv/www-admin/cpanel_f7D1k6/logs`.                                     |
| **Log Rotation**                 |  PASS  | Конфигурирана е ежедневна ротация с 14 копия и компресия.                                       |
| **Final Hosting PASS Check**     |  PASS  | `HTTPS = 200`, `HTTP = 301 → HTTPS`, логовете записват заявки.                                  |

### 3. ПОДДРЪЖКА НА ЕЗИЦИ / LANGUAGE COMPLIANCE

В съответствие с изискванията на NetGalaxy, документацията и работната среда поддържат:

1. **Български:** основен език на протокола и техническите описания
2. **English:** системни логове, команди, server responses
3. **Русский:** поддръжка на локализационна съвместимост в рамките на проекта

### 4. КЛЮЧОВИ КОНФИГУРАЦИИ / KEY CONFIGURATIONS

За бъдещи справки и автоматизация са валидни следните параметри:

```bash
# DNS MASTER
ns1.netgalaxy.network -> 38.242.249.205

# DNS SLAVE
ns2.netgalaxy.network -> 65.108.12.147

# Административен хостинг
https://d2.netgalaxy.network

# Проверка на DNS MASTER
dig @38.242.249.205 netgalaxy.network

# Проверка на DNS SLAVE
dig @65.108.12.147 netgalaxy.network

# Проверка на HTTPS хостинга
curl -I https://d2.netgalaxy.network

# Проверка на HTTP -> HTTPS redirect
curl -I http://d2.netgalaxy.network

# Проверка на firewall
sudo ufw status

# Проверка на логовете
sudo tail -n 5 /srv/www-admin/cpanel_f7D1k6/logs/access.log
```

### 5. ЗАКЛЮЧЕНИЕ / CONCLUSION

Сървър **D2** е успешно включен в DNS инфраструктурата на NetGalaxy като **SLAVE DNS сървър** и едновременно с това е подготвен като защитен хост за административен достъп чрез `d2.netgalaxy.network`.

Всички PASS проверки по протокола са преминати успешно. DNS архитектурата **MASTER / SLAVE** работи, HTTPS е активно, уеб достъпът е ограничен и логван, а firewall конфигурацията е приложена по контролиран и проверяем начин.

**Следваща стъпка:** Преминаване към следващия етап от изграждането на NetGalaxy инфраструктурата съгласно проектния план.

**Подпис:** ............................
*(Илко Йорданов)*

**Copyright:** © 2026 NetGalaxy™ | **Confidential**

### ДЕТАЙЛНА СПЕЦИФИКАЦИЯ НА ТРУДА (BY STEPS)

*Тази таблица служи за проверка на реално извършената дейност спрямо технологичния норматив.*

| Стъпка от Протокола | Описание на дейността                               |  Категория  | Норматив (мин) |
| :------------------ | :-------------------------------------------------- | :---------: | :------------: |
| **Стъпка 1**        | Инсталиране на BIND9 и DNS инструменти              | **Level C** |        5       |
| **Стъпка 2**        | Делегация на домейна и GLUE записи                  | **Level A** |       15       |
| **Стъпка 3**        | Конфигуриране на DNS MASTER (cp205)                 | **Level A** |       20       |
| **Стъпка 4**        | Конфигуриране на DNS SLAVE (D2)                     | **Level A** |       15       |
| **Стъпка 5**        | Създаване на директории за административния хостинг | **Level C** |        5       |
| **Стъпка 6**        | Създаване на начална index.html страница            | **Level C** |        5       |
| **Стъпка 7**        | Добавяне на DNS запис за `d2.netgalaxy.network`     | **Level A** |       10       |
| **Стъпка 8**        | Конфигуриране на Nginx virtual host                 | **Level B** |       10       |
| **Стъпка 9**        | Инсталиране и конфигуриране на SSL сертификат       | **Level B** |       15       |
| **Стъпка 10**       | Създаване на системен потребител и група            | **Level B** |        5       |
| **Стъпка 11**       | Ограничаване на достъпа до чувствителни ресурси     | **Level A** |       10       |
| **Стъпка 12**       | Настройка на permissions и ownership                | **Level B** |       10       |
| **Стъпка 13**       | Подготовка на firewall (UFW)                        | **Level A** |       10       |
| **Стъпка 14**       | Активиране и проверка на firewall                   | **Level A** |        5       |
| **Стъпка 15**       | Активиране на access/error логове                   | **Level B** |       10       |
| **Стъпка 16**       | Настройка на logrotate                              | **Level B** |       10       |
| **Стъпка 17**       | Финална PASS проверка на хостинга                   | **Level C** |        5       |
| **Отчет**           | Документиране и структуриране на резултата          | **Level B** |        5       |

### СУМАРНА КАРТА НА ТРУДОВИЯ ПРИНОС (LABOR VALUE MAP)

*Автоматично генерирано резюме за Смарт Контракта.*

| Група дейности                                  | Категория труд |   Общо мин.  |   Ставка (€/час)   | Стойност (€) |
| :---------------------------------------------- | :------------: | :----------: | :----------------: | :----------: |
| **I. Базова DNS и файлова подготовка**          |   **Level C**  |    **20**    |     **100.00**     |   **33.33**  |
| **II. Уеб конфигурация, SSL, логове и отчет**   |   **Level B**  |    **65**    |     **150.00**     |  **162.50**  |
| **III. DNS архитектура, сигурност и hardening** |   **Level A**  |    **85**    |     **250.00**     |  **354.17**  |
| **ОБЩО ЗА ПРОТОКОЛА:**                          |                | **170 мин.** | **Средна: 189.71** | **550.00 €** |

### ДАННИ ЗА СМАРТ КОНТРАКТ (SMART CONTRACT PAYOUT)

* **ID на задачата:** NG-D2-INSTALL-P2
* **Валута на изчисление:** EUR / NetGalaxy Token (NGT)
* **Обща стойност:** **550.00 €**
* **Разпределение:**

  * 💵 **Cash (40%):** **220.00 €**
  * 💎 **Tokens (60%):** **330.00 €**
