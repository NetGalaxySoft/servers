# NetGalaxy Network

## Инсталационен протокол № 3

### Етап 3 - Конфигуриране на хостинг за управление на сървър D2 (d2.netgalaxy.network)

🎯 ЦЕЛ: Изграждане на защитена среда за административно управление на сървъра D2 чрез:

  * Конфигуриране на поддомейн d2.netgalaxy.network
  * Настройка на Nginx с активиран HTTPS (SSL)
  * Изолация на уеб процесите чрез системен потребител
  * Ограничаване на достъпа до системни ресурси и Hardening на файловата система
  * Конфигуриране на защитна стена (UFW) за уеб трафик

---

### Информация за документа

**Проект:** NetGalaxy  
**Document ID:** NG-D2-v.0.1 – Installation protocol Nr.3.md  
**Дата:** 02.04.2026  
**Заглавие:** Инсталационен протокол № 3  
**Задачи за изпълнение:**

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
  
**Срок за изпълнение:** 03.04.2026  
**Изпълнител:** Илко Йорданов  
**Статус:** Изпълнен на 03.04.2026  
**Локация на документа:** GitHub Repository: servers/D2/NG-D2-v.0.1 – Installation protocol Nr.3.md  
**Контакт:** 📧 [yordanov.netgalaxy@gmail.com](mailto:yordanov.netgalaxy@gmail.com)  

**Copyright:** © 2026 NetGalaxy™ by Ilko Iordanov. All rights reserved.  
***Лиценз:*** Този документ е част от проекта NetGalaxy. Предназначен е само за вътрешно ползване в рамките на мрежата NetGalaxy. Разпространението или публикуването извън мрежата не е разрешено.  
**Всички права запазени.**

&nbsp;

---

## Етап 3, Стъпка 1: Създаване на директории за административния хостинг

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

## Етап 3, Стъпка 2: Създаване на index.html („Under Construction“) за административния хостинг

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

## Етап 3, Стъпка 3: Конфигуриране на домейн d2.netgalaxy.network

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
d2    IN  A       65.108.12.147
d2    IN  AAAA    2A01:4F9:6A:485E::2
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

## Етап 3, Стъпка 4: Конфигуриране на Nginx за работа с домейна d2.netgalaxy.network

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

## Етап 3, Стъпка 5: Инсталиране на SSL сертификат за d2.netgalaxy.network

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

## Етап 3, Стъпка 6: Създаване на системен потребител и група за административния сайт

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

## Етап 3, Стъпка 7: Ограничаване на достъпа до административни ресурси

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

## Етап 3, Стъпка 8: Ограничаване на достъпа до уеб директорията (permissions и ownership)

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

## Етап 3, Стъпка 9: Конфигуриране и проверка на firewall (UFW)

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

## Етап 3, Стъпка 10: Активиране на firewall

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

## Етап 3, Стъпка 11: Активиране на логове (access/error logs)

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

## Етап 3, Стъпка 12: Настройка на логовата ротация

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

## Етап 3, Стъпка 13: Проверка на хостинга (PASS)

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

## Етап 1, Стъпка 14: ФИНАЛНА ПРОВЕРКА (AUDIT & HARDENING VALIDATION)

**🎯 Цел**
Валидиране на уеб сигурността и интегритета на хостинг средата преди предаване в експлоатация.

**14.1. Проверка на SSL сертификата**
```bash
curl -Iv https://d2.netgalaxy.network 2>&1 | grep -E "SSL certificate|expire date"
```
* **PASS:** Трябва да показва валиден сертификат от Let's Encrypt.

**14.2. Тест на изолацията (Permissions)**
```bash
sudo -u www-data stat /srv/www-admin/cpanel_f7D1k6/logs/access.log
```
* **PASS:** Трябва да върне `Permission denied`. Само системният потребител `usr_cpanel_f7D1k6` и `root` имат достъп.

**14.3. Одит на Firewall (Active status)**
```bash
sudo ufw status numbered
```
* **PASS:** Трябва да виждате активни правила за `80/tcp`, `443/tcp` и `59623/tcp`.

**14.4. Проверка на автоматичната ротация**
```bash
ls -la /srv/www-admin/cpanel_f7D1k6/logs/
```
* **PASS:** Директорията трябва да е чиста, а файловете да са със собственик `usr_cpanel_f7D1k6`.

---

## ОТЧЕТ ЗА ИЗПЪЛНЕНИТЕ НА ЗАДАЧИТЕ

**Към Инсталационен протокол № 3 (NG-D2-v.0.1)**

**Дата на завършване:** 02.04.2026
**Изпълнител:** Илко Йорданов
**Обект:** Сървър D2 (IP: 65.108.12.147)
**Статус:** <span style="color:green">✅ УСПЕШНО ЗАВЪРШЕН</span>

### 1. РЕЗЮМЕ НА ИЗПЪЛНЕНИЕТО / EXECUTIVE SUMMARY

Всички заложени задачи по Инсталационен протокол № 3 са изпълнени успешно съгласно стандартите на проекта NetGalaxy. Изградена е работеща DNS инфраструктура за домейна `netgalaxy.network` в архитектура **MASTER / SLAVE**, а на сървъра **D2** е конфигуриран и защитен административен хостинг за домейна `d2.netgalaxy.network`.

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

**Подпис:** ............................
*(Илко Йорданов)*

**Copyright:** © 2026 NetGalaxy™ | **Confidential**

### 6. ДЕТАЙЛНА СПЕЦИФИКАЦИЯ НА ТРУДА (BY STEPS)

*Тази таблица служи за проверка на реално извършената дейност спрямо технологичния норматив.*

| Стъпка | Описание | Категория | Време (мин) | Коментар |
| :--- | :--- | :---: | :---: | :--- |
| **Стъпка 1-2** | Директории и HTML структура | **Level C** | 10 | Базова подготовка |
| **Стъпка 3** | DNS конфигурация (cp205) | **Level A** | 15 | Работа с зонови файлове |
| **Стъпка 4-5** | Nginx vHost + SSL Certbot | **Level B** | 25 | Уеб конфигурация |
| **Стъпка 6-8** | Потребители и Hardening на права | **Level A** | 25 | Сигурност и изолация |
| **Стъпка 9-10**| UFW Конфигурация и Активация | **Level A** | 20 | Мрежова защита |
| **Стъпка 11-12**| Логове и Logrotate | **Level B** | 15 | Поддръжка |
| **Стъпка 13-14**| Пълна финална проверка (Audit) | **Level A** | **20** | Валидация |
| **Отчет** | Документиране и калкулиране на изпълнението  | **Level B** | **15** | Прецизно оформяне |

---

### 7. СУМАРНА КАРТА НА ТРУДОВИЯ ПРИНОС

| Група дейности | Категория труд | Общо мин. | Ставка (€/час) | Стойност (€) |
| :--- | :---: | :---: | :---: | :---: |
| **I. Базова подготовка** | **Level C** | **10** | **100.00** | **16.67** |
| **II. Уеб и администрация** | **Level B** | **55** | **150.00** | **137.50** |
| **III. Сигурност и Архитектура** | **Level A** | **80** | **250.00** | **333.33** |
| **ОБЩО ЗА ПРОТОКОЛА:** | | **145 мин.** | **Средна: 201.72** | **487.50 €** |

---

### 8. ДАННИ ЗА СМАРТ КОНТРАКТ (PAYOUT)

* **ID на задачата:** NG-D2-INSTALL-P3
* **Обща стойност:** **487.50 €**
* **Разпределение (40/60):**
    * 💵 **Cash (40%):** **195.00 €**
    * 💎 **Tokens (60%):** **292.50 €**

---
