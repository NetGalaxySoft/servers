# NetGalaxy Network

## Проект NG-D2 за добавяне на нов сървър в мрежата NetGalaxy

### Инсталационен протокол № 3

#### Конфигуриране на хостинг за управление на сървъра (d2.netgalaxy.eu).

---

### Информация за документа

**Проект:** NetGalaxy  
**Документ ID:** NG-D2-v.0.1 – Installation protocol Nr.3.md  
**Дата:** 30.03.2026  
**Заглавие:** Инсталационен протокол № 3  
**Задачи за изпълнение:**

  * Конфигуриране на Nginx за работа с домейна
  * Създаване на начална страница "Under Construction"
  * Инсталиране на SSL сертификат
  * Създаване на системен потребител и група за сайта
  * Ограничаване на достъпа до административни ресурси
  * Ограничаване на достъпа до уеб директорията (permissions и ownership)
  * Конфигуриране и активиране на firewall
  * Активиране на логове (access/error logs)
  * Настройка на логовата ротация
  * Проверка на хостинга (PASS)
  
**Срок за изпълнение:** 30.03.2026  
**Изпълнител:** Илко Йорданов  
**Статус:** Изпълнен на 30.03.2026  
**Локация на документа:** GitHub Repository: servers/D2/NG-D2-v.0.1 – Installation protocol Nr.3.md  
**Контакт:** 📧 [yordanov.netgalaxy@gmail.com](mailto:yordanov.netgalaxy@gmail.com)  

**Copyright:** © 2026 NetGalaxy™ by Ilko Iordanov. All rights reserved.  
***Лиценз:*** Този документ е част от проекта NetGalaxy. Предназначен е само за вътрешно ползване в рамките на мрежата NetGalaxy. Разпространението или публикуването извън мрежата не е разрешено.  
**Всички права запазени.**

&nbsp;

---

## Етап 3, Стъпка 8: Създаване на директории за служебен хостинг на d2.netgalaxy.eu

Създаваме основната директория за служебния уеб хостинг и поддиректорията за домейна `d2.netgalaxy.eu`, в която по-късно ще поставим началната страница и конфигурацията на сайта.

**Код за терминала**

```bash
sudo mkdir -p /srv/www-admin/d2.netgalaxy.eu/public
```

**Код за проверка**

```bash
sudo ls -ld /srv/www-admin /srv/www-admin/d2.netgalaxy.eu /srv/www-admin/d2.netgalaxy.eu/public
```

**Очакван резултат**

Трябва да се покажат и трите директории, например така:

```bash
drwxr-xr-x 3 root root ... Mar 30 10:40 /srv/www-admin
drwxr-xr-x 3 root root ... Mar 30 10:40 /srv/www-admin/d2.netgalaxy.eu
drwxr-xr-x 2 root root ... Mar 30 10:40 /srv/www-admin/d2.netgalaxy.eu/public

```

**PASS проверка**

И трите директории съществуват и се виждат в изхода на командата за проверка.

---

## Етап 3, Стъпка 9: Създаване на index.html („Under Construction“) за домейна d2.netgalaxy.eu

Създаваме начална страница `index.html` в директорията `public`, която ще се показва при достъп до домейна. Тя указва, че услугата е в процес на разработка.

**Код за терминала**

```bash
sudo tee /srv/www-admin/d2.netgalaxy.eu/public/index.html > /dev/null << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>NetGalaxy D2</title>
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
    <h1>NetGalaxy D2</h1>
    <p>Server is under construction</p>
  </div>
</body>
</html>
EOF
```

**Код за проверка**

```bash
sudo ls -lh /srv/www-admin/d2.netgalaxy.eu/public/index.html
```

**Очакван резултат**

```bash
-rw-r--r-- 1 root root ... /srv/www-admin/d2.netgalaxy.eu/public/index.html
```

***PASS проверка**

Файлът `index.html` съществува в директорията `public` и има размер (не е празен).

---

## Етап 3, Стъпка 10: Конфигуриране на Nginx за работа с домейна d2.netgalaxy.eu

Създаваме Nginx конфигурация за домейна `d2.netgalaxy.eu`, насочваме я към уеб директорията `public`, активираме сайта и презареждаме Nginx.

**Код за терминала**

```bash
sudo tee /etc/nginx/sites-available/d2.netgalaxy.eu > /dev/null << 'EOF'
server {
    listen 80;
    listen [::]:80;

    server_name d2.netgalaxy.eu;

    root /srv/www-admin/d2.netgalaxy.eu/public;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
EOF

sudo ln -sfn /etc/nginx/sites-available/d2.netgalaxy.eu /etc/nginx/sites-enabled/d2.netgalaxy.eu
sudo nginx -t
sudo systemctl reload nginx
```

**Код за проверка**

```bash
sudo nginx -T | grep -A 12 "server_name d2.netgalaxy.eu"
curl -I -H "Host: d2.netgalaxy.eu" http://127.0.0.1/
```

**Очакван резултат**

При проверката трябва да се види:

```bash
server_name d2.netgalaxy.eu;
root /srv/www-admin/d2.netgalaxy.eu/public;
index index.html;
```

и от `curl`:

```bash
HTTP/1.1 200 OK
```

**PASS проверка**

  * `sudo nginx -t` завършва с `syntax is ok` и `test is successful`
  * `curl -I -H "Host: d2.netgalaxy.eu" http://127.0.0.1/` връща `HTTP/1.1 200 OK`

---

## Етап 3, Стъпка 11: Инсталиране на SSL сертификат за d2.netgalaxy.eu

Инсталираме SSL сертификат от Let’s Encrypt чрез Certbot и автоматично конфигурираме Nginx да работи през HTTPS.

**Код за терминала**

```bash
sudo apt update && sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d d2.netgalaxy.eu --non-interactive --agree-tos -m yordanov.netgalaxy@gmail.com --redirect
```

**Код за проверка**

```bash
sudo nginx -T | grep -A 5 "server_name d2.netgalaxy.eu"
curl -I https://d2.netgalaxy.eu
```

**Очакван резултат**

В конфигурацията трябва да се появят SSL настройки, например:

```bash
listen 443 ssl;
ssl_certificate /etc/letsencrypt/live/d2.netgalaxy.eu/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/d2.netgalaxy.eu/privkey.pem;
```

И от `curl`:

```bash
HTTP/2 200
```

**PASS проверка**

  * HTTPS е активен и достъпен
  * `curl -I https://d2.netgalaxy.eu` връща `HTTP/2 200`
  * Отворете в браузър:

  ```
  https://d2.netgalaxy.eu
  ```
  * Страницата се зарежда без предупреждения за сигурност (валиден SSL сертификат)

---
  
## Етап 3, Стъпка 12: Създаване на системен потребител и група за сайта

Създаваме изолиран системен потребител и група за домейна `d2.netgalaxy.eu`, след което задаваме собственост на уеб директорията. Това гарантира разделение между сайтовете и контрол върху достъпа.

---

**Код за терминала**

```bash
sudo groupadd --system grp_d2_netgalaxy_eu
sudo useradd --system --no-create-home --shell /usr/sbin/nologin -g grp_d2_netgalaxy_eu usr_d2_netgalaxy_eu
sudo chown -R usr_d2_netgalaxy_eu:grp_d2_netgalaxy_eu /srv/www-admin/d2.netgalaxy.eu
```

***Код за проверка

```bash
id usr_d2_netgalaxy_eu
sudo ls -ld /srv/www-admin/d2.netgalaxy.eu
sudo ls -ld /srv/www-admin/d2.netgalaxy.eu/public
```

**Очакван резултат**

```bash
uid=... (usr_d2_netgalaxy_eu) gid=... (grp_d2_netgalaxy_eu)
drwxr-xr-x ... usr_d2_netgalaxy_eu grp_d2_netgalaxy_eu /srv/www-admin/d2.netgalaxy.eu
drwxr-xr-x ... usr_d2_netgalaxy_eu grp_d2_netgalaxy_eu /srv/www-admin/d2.netgalaxy.eu/public
```

**PASS проверка**

* Потребителят `usr_d2_netgalaxy_eu` съществува
* Групата `grp_d2_netgalaxy_eu` съществува
* Директорията е собственост на:

  ```bash
  usr_d2_netgalaxy_eu:grp_d2_netgalaxy_eu
  ```

---

## Етап 3, Стъпка 13: Ограничаване на достъпа до административни ресурси

Забраняваме директен уеб достъп до чувствителни директории и файлове (напр. `config`, `logs`, скрити файлове), за да предотвратим изтичане на информация и неоторизиран достъп.

---

**Код за терминала**

```bash
sudo tee /etc/nginx/snippets/d2.netgalaxy.eu_restrictions.conf > /dev/null << 'EOF'
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

sudo sed -i '/server_name d2.netgalaxy.eu;/a \    include /etc/nginx/snippets/d2.netgalaxy.eu_restrictions.conf;' /etc/nginx/sites-available/d2.netgalaxy.eu

sudo nginx -t
sudo systemctl reload nginx
```

**Код за проверка**

```bash
curl -I https://d2.netgalaxy.eu/.env
curl -I https://d2.netgalaxy.eu/config/
curl -I https://d2.netgalaxy.eu/test.log
```

**Очакван резултат**

```bash
HTTP/2 403
```

или:

```bash
HTTP/1.1 403 Forbidden
```

И двата варианта са приемливи, важното е кодът да е **403**.

## Обновена PASS проверка

* Забранените ресурси през HTTPS връщат `403`
* Отвори в браузър:

```text
https://d2.netgalaxy.eu/.env
https://d2.netgalaxy.eu/config/
https://d2.netgalaxy.eu/test.log
```

* Браузърът показва отказан достъп

---

## Етап 3, Стъпка 14: Ограничаване на достъпа до уеб директорията (permissions и ownership)

Задаваме строги права върху уеб директорията, така че:

* собственикът (`usr_d2_netgalaxy_eu`) има пълен контрол
* групата има ограничен достъп
* всички останали имат само четене (без запис)

Това предотвратява неоторизирани промени и повишава сигурността.

**Код за терминала**

```bash
sudo chmod 755 /srv/www-admin/d2.netgalaxy.eu
sudo find /srv/www-admin/d2.netgalaxy.eu/public -type d -exec chmod 755 {} \;
sudo find /srv/www-admin/d2.netgalaxy.eu/public -type f -exec chmod 644 {} \;
```

**Код за проверка**

```bash
sudo ls -ld /srv/www-admin/d2.netgalaxy.eu /srv/www-admin/d2.netgalaxy.eu/public
sudo find /srv/www-admin/d2.netgalaxy.eu/public -printf "%M %u %g %p\n" | head -n 10
curl -I https://d2.netgalaxy.eu
```

---

**Очакван резултат**

Примерен изход:

```bash
drwxr-xr-x usr_d2_netgalaxy_eu grp_d2_netgalaxy_eu /srv/www-admin/d2.netgalaxy.eu
drwxr-xr-x usr_d2_netgalaxy_eu grp_d2_netgalaxy_eu /srv/www-admin/d2.netgalaxy.eu/public
-rw-r--r-- usr_d2_netgalaxy_eu grp_d2_netgalaxy_eu /srv/www-admin/d2.netgalaxy.eu/public/index.html
HTTP/1.1 200 OK
```

---

**PASS проверка**

* Директорията `/srv/www-admin/d2.netgalaxy.eu` е с права `755`
* Директориите в `public` са с права `755`
* Файловете в `public` са с права `644`
* Няма права за запис за „others“
* Отвори в браузър:

```text
https://d2.netgalaxy.eu
```

* Страницата се зарежда успешно

---

## Етап 3, Стъпка 15: Конфигуриране и активиране на firewall

Конфигурираме firewall (UFW), като разрешаваме само необходимите портове и ограничаваме всички останали входящи връзки.

⚠️ В мрежата NetGalaxy **не се допуска използване на порт 22 за SSH**.
SSH достъпът се конфигурира на алтернативен порт, който трябва да бъде разрешен преди активиране на firewall.

---

### 15.1. Въвеждане на необходимите правила

**Код за терминала**

```bash
sudo ufw allow <SSH_PORT>/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

**Код за проверка**

```bash
sudo ufw show added
```

**Очакван резултат**

```
ufw allow <SSH_PORT>/tcp
ufw allow 80/tcp
ufw allow 443/tcp
```

---

### 15.2. Активиране на firewall

**Код за терминала**

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
```

**Код за проверка**

```bash
sudo systemctl is-active ufw
```

**Очакван резултат**

```
active
```

---

### 15.3. Проверка на достъпа след активиране

**Код за терминала**

```bash
curl -I https://d2.netgalaxy.eu
```

---

### Очакван резултат

```bash
HTTP/1.1 200 OK
```

---

## PASS проверка

* Firewall е активен
* Разрешен е SSH достъп на избрания порт (различен от 22)
* Разрешени са портове:

  * 80 (HTTP)
  * 443 (HTTPS)
* Всички други входящи връзки са блокирани
* Сайтът се зарежда:

```
https://d2.netgalaxy.eu
```

---

Това вече е:

* ✔ безопасно
* ✔ ясно за ученици
* ✔ без скрита логика
* ✔ съвместимо с твоя модел

---

Да — объркването е в пътя.
На две места е написано:

```bash
/srv/www-admin/d2.netgalaxy_eu/logs
```

а правилният път е:

```bash
/srv/www-admin/d2.netgalaxy.eu/logs
```

Тоест:

* грешно: `d2.netgalaxy_eu`
* правилно: `d2.netgalaxy.eu`

И точно затова:

* `chmod` е дал грешка
* `ls` е дал грешка
* но `tail` върху правилния път е проработил и е показал, че логът вече се пише

Значи добрата новина е:

## PASS по същество

* Nginx конфигурацията е валидна
* сайтът връща `200 OK`
* `access.log` вече се записва

Тоест стъпката реално е почти успешна, просто текстът трябва да се поправи.

---

## Етап 3, Стъпка 16: Активиране на логове (access/error logs)

Активираме access и error логове за домейна `d2.netgalaxy.eu`, като ги записваме в отделна директория. Това позволява проследяване на трафика, грешките и евентуални проблеми със сигурността.

**Код за терминала**

```bash
sudo mkdir -p /srv/www-admin/d2.netgalaxy.eu/logs
sudo chown usr_d2_netgalaxy_eu:grp_d2_netgalaxy_eu /srv/www-admin/d2.netgalaxy.eu/logs
sudo chmod 750 /srv/www-admin/d2.netgalaxy.eu/logs

sudo sed -i '/server_name d2.netgalaxy.eu;/a \
    access_log /srv/www-admin/d2.netgalaxy.eu/logs/access.log;\
    error_log /srv/www-admin/d2.netgalaxy.eu/logs/error.log;' \
/etc/nginx/sites-available/d2.netgalaxy.eu

sudo nginx -t
sudo systemctl reload nginx
```

**Код за проверка**

```bash
sudo ls -ld /srv/www-admin/d2.netgalaxy.eu/logs
curl -I https://d2.netgalaxy.eu
sudo tail -n 5 /srv/www-admin/d2.netgalaxy.eu/logs/access.log
```

---

**Очакван резултат**

```bash
drwxr-x--- usr_d2_netgalaxy_eu grp_d2_netgalaxy_eu /srv/www-admin/d2.netgalaxy.eu/logs
HTTP/1.1 200 OK
```

и в `access.log` трябва да има запис от заявката.

---

**PASS проверка**

* Директорията `logs` съществува
* Сайтът остава достъпен на:

```text
https://d2.netgalaxy.eu
```

* В `access.log` се записват заявки
* `nginx -t` завършва успешно

---

## Етап 3, Стъпка 17: Настройка на логовата ротация

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

---

**Код за терминала**

```bash
sudo tee /etc/logrotate.d/d2.netgalaxy.eu > /dev/null << 'EOF'
/srv/www-admin/d2.netgalaxy.eu/logs/*.log {
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
sudo logrotate -d /etc/logrotate.d/d2.netgalaxy.eu
```

**Очакван резултат**

* Няма грешки в изхода
* Показва се симулация на ротация

**PASS проверка**

* Конфигурационният файл съществува:

```bash
/etc/logrotate.d/d2.netgalaxy.eu
```

* Командата:

```bash
sudo logrotate -d /etc/logrotate.d/d2.netgalaxy.eu
```

завършва без грешки

* Сайтът остава достъпен:

```text
https://d2.netgalaxy.eu
```

---

## Етап 3, Стъпка 18: Проверка на хостинга (PASS)

Извършваме финална проверка на хостинга, за да потвърдим, че всички компоненти работят коректно и сайтът е достъпен и защитен.

**Код за терминала**

```bash
curl -I https://d2.netgalaxy.eu
curl -I http://d2.netgalaxy.eu
```

**Очакван резултат**

```bash
HTTP/1.1 200 OK
```

и:

```bash
HTTP/1.1 301 Moved Permanently
```

(HTTP → HTTPS redirect)

**Допълнителна проверка (логове)**

```bash
sudo tail -n 5 /srv/www-admin/d2.netgalaxy.eu/logs/access.log
```

👉 трябва да има запис от заявката

**PASS проверка**

* Сайтът се отваря:

```text
https://d2.netgalaxy.eu
```

* HTTPS работи (няма предупреждения)
* HTTP се пренасочва към HTTPS
* Nginx отговаря с `200 OK`
* Логовете записват заявки
* Няма грешки в достъпа

---

## Финал:

### Всички задачи са изпълнени!

Дата: 30.03.2026
