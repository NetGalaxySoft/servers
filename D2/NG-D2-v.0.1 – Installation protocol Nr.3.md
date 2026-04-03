# NetGalaxy Network

## Инсталационен протокол № 3

### Етап 3 - Конфигуриране на продукционен хостинг (prestigeblack.be)

---

### Информация за документа

**Проект:** NetGalaxy  
**Document ID:** NG-D2-v.0.1 – Installation protocol Nr.3.md  
**Дата:** 30.03.2026  
**Заглавие:** Инсталационен протокол № 2  
**Задачи за изпълнение:**

  * Конфигуриране на DNS за уеб-сайта prestigeblack.be (сървър cp205)
  * Създаване на директории за служебен хостинг на prestigeblack.be
  * Създаване на index.html („Under Construction“) за домейна prestigeblack.be
  * Конфигуриране на Nginx за работа с домейна prestigeblack.be
  * Инсталиране на SSL сертификат за `prestigeblack.be`
  * Създаване на системен потребител и група за сайта
  * Ограничаване на достъпа до административни ресурси
  * Ограничаване на достъпа до уеб директорията (permissions и ownership)
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

## Етап 3, Стъпка 1: Конфигуриране на DNS за уеб-сайта prestigeblack.be

Влизаме в контролния панел на Hestia на сървъра **cp205**, отваряме DNS настройките на домейна `prestigeblack.be` и променяме основния A запис, така че домейнът да сочи към новия сървър **D2**.

**Кратка цел**
Промяна на DNS записа `@ A` за `prestigeblack.be` от IP адреса на cp205 към IP адреса на D2.

**Действие (извън терминала)**

1. Влезте в **Hestia Control Panel** на сървъра **cp205**
2. Отворете **DNS** настройките на домейна **prestigeblack.be**
3. Намерете записа:

```text
@    A    38.242.249.205
```

4. Променете го на:

```text
@    A    65.108.12.147
```

5. Запазете промяната

**Код за проверка**

```bash
dig prestigeblack.be +short
```

**Очакван резултат**

```text
65.108.12.147
```

**PASS проверка**

* Основният A запис на `prestigeblack.be` сочи към `65.108.12.147`
* Командата `dig prestigeblack.be +short` връща `65.108.12.147`
* DNS промяната е записана успешно в HestiaCP

---

## Етап 3, Стъпка 2: Създаване на директории за служебен хостинг на prestigeblack.be

Създаваме основната директория за продукционен хостинг и поддиректорията за домейна `prestigeblack.be`, в която по-късно ще поставим началната страница и конфигурацията на сайта.

**Код за терминала**

```bash
sudo mkdir -p /var/www/trans_prod/prestigeblack.be/public
```

**Код за проверка**

```bash
sudo ls -ld /var/www/trans_prod /var/www/trans_prod/prestigeblack.be /var/www/trans_prod/prestigeblack.be/public
```

**Очакван резултат**

Трябва да се покажат и трите директории, например така:

```bash
drwxr-xr-x 3 root root ... Mar 30 10:40 /var/www/trans_prod
drwxr-xr-x 3 root root ... Mar 30 10:40 /var/www/trans_prod/prestigeblack.be
drwxr-xr-x 2 root root ... Mar 30 10:40 /var/www/trans_prod/prestigeblack.be/public
```

**PASS проверка**

И трите директории съществуват и се виждат в изхода на командата за проверка.

---

## Етап 3, Стъпка 3: Създаване на index.html („Under Construction“) за домейна prestigeblack.be

Създаваме начална страница `index.html` в директорията `public`, която ще се показва при достъп до домейна. Тя указва, че услугата е в процес на разработка.

**Код за терминала**

```bash
sudo tee /var/www/trans_prod/prestigeblack.be/public/index.html > /dev/null << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>PrestigeBlack</title>
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
    <h1>PrestigeBlack</h1>
    <p>Server is under construction</p>
  </div>
</body>
</html>
EOF
```

**Код за проверка**

```bash
sudo ls -lh /var/www/trans_prod/prestigeblack.be/public/index.html
```

**Очакван резултат**

```bash
-rw-r--r-- 1 root root ... /var/www/trans_prod/prestigeblack.be/public/index.html
```

**PASS проверка**

Файлът `index.html` съществува в директорията `public` и има размер (не е празен).

---

## Етап 3, Стъпка 4: Конфигуриране на Nginx за работа с домейна prestigeblack.be

Създаваме Nginx конфигурация за домейна `prestigeblack.be`, насочваме я към уеб директорията `public`, активираме сайта и презареждаме Nginx.

**Код за терминала**

```bash
sudo tee /etc/nginx/sites-available/prestigeblack.be > /dev/null << 'EOF'
server {
    listen 80;
    listen [::]:80;

    server_name prestigeblack.be www.prestigeblack.be;

    root /var/www/trans_prod/prestigeblack.be/public;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
EOF

sudo ln -sfn /etc/nginx/sites-available/prestigeblack.be /etc/nginx/sites-enabled/prestigeblack.be
sudo nginx -t
sudo systemctl reload nginx
```

**Код за проверка**

```bash
sudo nginx -T | grep -A 12 "server_name prestigeblack.be"
curl -I -H "Host: prestigeblack.be" http://127.0.0.1/
```

**Очакван резултат**

При проверката трябва да се види:

```bash
server_name prestigeblack.be www.prestigeblack.be;
root /var/www/trans_prod/prestigeblack.be/public;
index index.html;
```

и от `curl`:

```bash
HTTP/1.1 200 OK
```

**PASS проверка**

* `sudo nginx -t` завършва с `syntax is ok` и `test is successful`
* `curl -I -H "Host: prestigeblack.be" http://127.0.0.1/` връща `HTTP/1.1 200 OK`

---

## Етап 3, Стъпка 5: Инсталиране на SSL сертификат за `prestigeblack.be`

Инсталираме SSL сертификат от Let’s Encrypt чрез Certbot и автоматично конфигурираме Nginx да работи през HTTPS.

**Код за терминала**

```bash
sudo certbot --nginx -d prestigeblack.be -d www.prestigeblack.be --non-interactive --agree-tos -m yordanov.netgalaxy@gmail.com --redirect
```

**Код за проверка**

```bash
sudo nginx -T | grep -A 8 "server_name prestigeblack.be"
curl -I https://prestigeblack.be
```

**Очакван резултат**

```bash
listen 443 ssl;
ssl_certificate /etc/letsencrypt/live/prestigeblack.be/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/prestigeblack.be/privkey.pem;
```

и:

```bash
HTTP/2 200
```

**PASS проверка**

* HTTPS е активен и достъпен
* `curl -I https://prestigeblack.be` връща `HTTP/2 200`
* Отворете в браузър:

```
https://prestigeblack.be
```

* Страницата се зарежда без предупреждения за сигурност (валиден SSL сертификат)

---

## Етап 3, Стъпка 6: Създаване на системен потребител и група за сайта

Създаваме изолиран системен потребител и група за домейна `prestigeblack.be`, след което задаваме собственост на уеб директорията. Това гарантира разделение между сайтовете и контрол върху достъпа.

---

**Код за терминала**

```bash
sudo groupadd --system grp_prestigeblack_be
sudo useradd --system --no-create-home --shell /usr/sbin/nologin -g grp_prestigeblack_be usr_prestigeblack_be
sudo chown -R usr_prestigeblack_be:grp_prestigeblack_be /var/www/trans_prod/prestigeblack.be
```

---

**Код за проверка**

```bash
id usr_prestigeblack_be
sudo ls -ld /var/www/trans_prod/prestigeblack.be
sudo ls -ld /var/www/trans_prod/prestigeblack.be/public
```

---

**Очакван резултат**

```bash
uid=... (usr_prestigeblack_be) gid=... (grp_prestigeblack_be)
drwxr-xr-x ... usr_prestigeblack_be grp_prestigeblack_be /var/www/trans_prod/prestigeblack.be
drwxr-xr-x ... usr_prestigeblack_be grp_prestigeblack_be /var/www/trans_prod/prestigeblack.be/public
```

---

**PASS проверка**

* Потребителят `usr_prestigeblack_be` съществува
* Групата `grp_prestigeblack_be` съществува
* Директорията е собственост на:

```bash
usr_prestigeblack_be:grp_prestigeblack_be
```

---

## Етап 3, Стъпка 7: Ограничаване на достъпа до административни ресурси

Забраняваме директен уеб достъп до чувствителни директории и файлове (напр. `config`, `logs`, скрити файлове), за да предотвратим изтичане на информация и неоторизиран достъп.

---

**Код за терминала**

```bash
sudo tee /etc/nginx/snippets/prestigeblack.be_restrictions.conf > /dev/null << 'EOF'
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

sudo sed -i '/server_name prestigeblack.be www.prestigeblack.be;/a \    include /etc/nginx/snippets/prestigeblack.be_restrictions.conf;' /etc/nginx/sites-available/prestigeblack.be

sudo nginx -t
sudo systemctl reload nginx
```

**Код за проверка**

```bash
curl -I https://prestigeblack.be/.env
curl -I https://prestigeblack.be/config/
curl -I https://prestigeblack.be/test.log
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

**Обновена PASS проверка**

* Забранените ресурси през HTTPS връщат `403`
* Отвори в браузър:

```text
https://prestigeblack.be/.env
https://prestigeblack.be/config/
https://prestigeblack.be/test.log
```

* Браузърът показва отказан достъп

---

## Етап 3, Стъпка 8: Ограничаване на достъпа до уеб директорията (permissions и ownership)

Задаваме строги права върху уеб директорията, така че:

* собственикът (`usr_prestigeblack_be`) има пълен контрол
* групата има ограничен достъп
* всички останали имат само четене (без запис)

Това предотвратява неоторизирани промени и повишава сигурността.

**Код за терминала**

```bash
sudo chmod 755 /var/www/trans_prod/prestigeblack.be
sudo find /var/www/trans_prod/prestigeblack.be/public -type d -exec chmod 755 {} \;
sudo find /var/www/trans_prod/prestigeblack.be/public -type f -exec chmod 644 {} \;
```

**Код за проверка**

```bash
sudo ls -ld /var/www/trans_prod/prestigeblack.be /var/www/trans_prod/prestigeblack.be/public
sudo find /var/www/trans_prod/prestigeblack.be/public -printf "%M %u %g %p\n" | head -n 10
curl -I https://prestigeblack.be
```

---

**Очакван резултат**

Примерен изход:

```bash
drwxr-xr-x usr_prestigeblack_be grp_prestigeblack_be /var/www/trans_prod/prestigeblack.be
drwxr-xr-x usr_prestigeblack_be grp_prestigeblack_be /var/www/trans_prod/prestigeblack.be/public
-rw-r--r-- usr_prestigeblack_be grp_prestigeblack_be /var/www/trans_prod/prestigeblack.be/public/index.html
HTTP/2 200
```

---

**PASS проверка**

* Директорията `/var/www/trans_prod/prestigeblack.be` е с права `755`
* Директориите в `public` са с права `755`
* Файловете в `public` са с права `644`
* Няма права за запис за „others“
* Отвори в браузър:

```text
https://prestigeblack.be
```

* Страницата се зарежда успешно

---

## Етап 3, Стъпка 9: Активиране на логове (access/error logs)

Активираме access и error логове за домейна `prestigeblack.be`, като ги записваме в отделна директория. Това позволява проследяване на трафика, грешките и евентуални проблеми със сигурността.

**Код за терминала**

```bash
sudo mkdir -p /var/www/trans_prod/prestigeblack.be/logs
sudo chown usr_prestigeblack_be:grp_prestigeblack_be /var/www/trans_prod/prestigeblack.be/logs
sudo chmod 750 /var/www/trans_prod/prestigeblack.be/logs

sudo sed -i '/server_name prestigeblack.be www.prestigeblack.be;/a \
    access_log /var/www/trans_prod/prestigeblack.be/logs/access.log;\
    error_log /var/www/trans_prod/prestigeblack.be/logs/error.log;' \
/etc/nginx/sites-available/prestigeblack.be

sudo nginx -t
sudo systemctl reload nginx
```

**Код за проверка**

```bash
sudo ls -ld /var/www/trans_prod/prestigeblack.be/logs
curl -I https://prestigeblack.be
sudo tail -n 5 /var/www/trans_prod/prestigeblack.be/logs/access.log
```

---

**Очакван резултат**

```bash
drwxr-x--- usr_prestigeblack_be grp_prestigeblack_be /var/www/trans_prod/prestigeblack.be/logs
HTTP/2 200
```

и в `access.log` трябва да има запис от заявката.

---

**PASS проверка**

* Директорията `logs` съществува
* Сайтът остава достъпен на:

```text
https://prestigeblack.be
```

* В `access.log` се записват заявки
* `nginx -t` завършва успешно

---

## Етап 3, Стъпка 10: Настройка на логовата ротация

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
sudo tee /etc/logrotate.d/prestigeblack.be > /dev/null << 'EOF'
/var/www/trans_prod/prestigeblack.be/logs/*.log {
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
sudo logrotate -d /etc/logrotate.d/prestigeblack.be
```

**Очакван резултат**

* Няма грешки в изхода
* Показва се симулация на ротация

---

**PASS проверка**

* Конфигурационният файл съществува:

```bash
/etc/logrotate.d/prestigeblack.be
```

* Командата:

```bash
sudo logrotate -d /etc/logrotate.d/prestigeblack.be
```

завършва без грешки

* Сайтът остава достъпен:

```text
https://prestigeblack.be
```

---

## Етап 3, Стъпка 11: Проверка на хостинга (PASS)

Извършваме финална проверка на хостинга, за да потвърдим, че всички компоненти работят коректно и сайтът е достъпен и защитен.

**Код за терминала**

```bash
curl -I https://prestigeblack.be
curl -I http://prestigeblack.be
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
sudo tail -n 5 /var/www/trans_prod/prestigeblack.be/logs/access.log
```

👉 трябва да има запис от заявката

**PASS проверка**

* Сайтът се отваря:

```text
https://prestigeblack.be
```

* HTTPS работи (няма предупреждения)
* HTTP се пренасочва към HTTPS
* Nginx отговаря с `HTTP/2 200`
* Логовете записват заявки
* Няма грешки в достъпа

---

## ФИНАЛЕН ОТЧЕТ ЗА ИЗПЪЛНЕНИЕ

**Към Инсталационен протокол № 3 (NG-D2-v.0.1)**

**Дата на завършване:** 30.03.2026
**Изпълнител:** Илко Йорданов
**Обект:** Сървър D2 (IP: 65.108.12.147)
**Статус:** <span style="color:green">✅ УСПЕШНО ЗАВЪРШЕН</span>

### 1. РЕЗЮМЕ НА ИЗПЪЛНЕНИЕТО / EXECUTIVE SUMMARY

Всички заложени задачи по Инсталационен протокол № 3 са изпълнени успешно съгласно стандартите на проекта NetGalaxy. Домейнът `prestigeblack.be` е пренасочен към продукционния сървър **D2**, конфигуриран е отделен защитен хостинг, активиран е HTTPS достъп с валиден SSL сертификат, приложени са ограничения за чувствителни ресурси, активирани са логове и е настроена автоматична логова ротация.

Изпълнените дейности включват:

* **DNS:** основният A запис на `prestigeblack.be` е насочен към `65.108.12.147`
* **Production hosting:** отделна структура в `/var/www/trans_prod/prestigeblack.be`
* **Web stack:** Nginx + HTTPS (Let’s Encrypt)
* **Security:** изолиран системен потребител, ресурсни ограничения, права и ownership
* **Observability:** access/error logs + logrotate
* **Final validation:** HTTPS = `200`, HTTP = `301 → HTTPS`

### 2. ДЕТАЙЛЕН ПРЕГЛЕД НА ЗАДАЧИТЕ / TASK DETAILS

| Задача / Task                    | Статус | Коментар / Technical Note                                                                       |
| :------------------------------- | :----: | :---------------------------------------------------------------------------------------------- |
| **DNS Reconfiguration**          |  PASS  | A записът на `prestigeblack.be` е променен от `38.242.249.205` към `65.108.12.147`.             |
| **Hosting Directory Structure**  |  PASS  | Създадена е продукционна структура `/var/www/trans_prod/prestigeblack.be/public`.               |
| **Initial Index Page**           |  PASS  | Създадена е начална страница “Under Construction” за домейна.                                   |
| **Nginx Virtual Host**           |  PASS  | Активиран е отделен vhost за `prestigeblack.be` и `www.prestigeblack.be`.                       |
| **SSL Certificate**              |  PASS  | Издаден и приложен е валиден Let’s Encrypt сертификат за двата host name-а.                     |
| **System Isolation User**        |  PASS  | Създадени са `usr_prestigeblack_be` и `grp_prestigeblack_be`.                                   |
| **Resource Access Restrictions** |  PASS  | Забранен е директният достъп до `.env`, `config`, `logs`, `*.log` и други чувствителни ресурси. |
| **Permissions & Ownership**      |  PASS  | Зададени са сигурни права върху `public` и ownership върху продукционната директория.           |
| **Access/Error Logging**         |  PASS  | Логовете се записват в `/var/www/trans_prod/prestigeblack.be/logs`.                             |
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
# Production domain
https://prestigeblack.be
https://www.prestigeblack.be

# DNS check
dig prestigeblack.be +short

# Nginx vhost
/etc/nginx/sites-available/prestigeblack.be

# Web root
/var/www/trans_prod/prestigeblack.be/public

# Ownership
usr_prestigeblack_be:grp_prestigeblack_be

# HTTPS check
curl -I https://prestigeblack.be

# HTTP -> HTTPS redirect check
curl -I http://prestigeblack.be

# Access log check
sudo tail -n 5 /var/www/trans_prod/prestigeblack.be/logs/access.log

# Logrotate config
/etc/logrotate.d/prestigeblack.be
```

### 5. ЗАКЛЮЧЕНИЕ / CONCLUSION

Сървър **D2** е успешно конфигуриран като продукционен хост за домейна **prestigeblack.be**. Всички PASS проверки по протокола са преминати успешно. Достъпът през HTTPS работи коректно, HTTP се пренасочва към HTTPS, логовете се записват и архивират по контролиран начин, а уеб структурата е изолирана и защитена според стандартите на NetGalaxy.

**Следваща стъпка:** Преминаване към следващия етап от продукционната конфигурация съгласно проектния план.

**Подпис:** ............................
*(Илко Йорданов)*

**Copyright:** © 2026 NetGalaxy™ | **Confidential**

### ДЕТАЙЛНА СПЕЦИФИКАЦИЯ НА ТРУДА (BY STEPS)

*Тази таблица служи за проверка на реално извършената дейност спрямо технологичния норматив.*

| Стъпка от Протокола | Описание на дейността                            |  Категория  | Норматив (мин) |
| :------------------ | :----------------------------------------------- | :---------: | :------------: |
| **Стъпка 1**        | Промяна на DNS записа за `prestigeblack.be`      | **Level A** |       10       |
| **Стъпка 2**        | Създаване на директории за продукционния хостинг | **Level C** |        5       |
| **Стъпка 3**        | Създаване на начална index.html страница         | **Level C** |        5       |
| **Стъпка 4**        | Конфигуриране на Nginx virtual host              | **Level B** |       10       |
| **Стъпка 5**        | Инсталиране и конфигуриране на SSL сертификат    | **Level B** |       15       |
| **Стъпка 6**        | Създаване на системен потребител и група         | **Level B** |        5       |
| **Стъпка 7**        | Ограничаване на достъпа до чувствителни ресурси  | **Level A** |       10       |
| **Стъпка 8**        | Настройка на permissions и ownership             | **Level B** |       10       |
| **Стъпка 9**        | Активиране на access/error логове                | **Level B** |       10       |
| **Стъпка 10**       | Настройка на logrotate                           | **Level B** |       10       |
| **Стъпка 11**       | Финална PASS проверка на хостинга                | **Level C** |        5       |
| **Отчет**           | Документиране и структуриране на резултата       | **Level B** |        5       |

### СУМАРНА КАРТА НА ТРУДОВИЯ ПРИНОС (LABOR VALUE MAP)

*Автоматично генерирано резюме за Смарт Контракта.*

| Група дейности                                | Категория труд |  Общо мин.  |   Ставка (€/час)   | Стойност (€) |
| :-------------------------------------------- | :------------: | :---------: | :----------------: | :----------: |
| **I. Файлова подготовка и финални проверки**  |   **Level C**  |    **15**   |     **100.00**     |   **25.00**  |
| **II. Уеб конфигурация, SSL, логове и отчет** |   **Level B**  |    **55**   |     **150.00**     |  **137.50**  |
| **III. DNS промяна и сигурност**              |   **Level A**  |    **20**   |     **250.00**     |   **83.33**  |
| **ОБЩО ЗА ПРОТОКОЛА:**                        |                | **90 мин.** | **Средна: 163.89** | **245.83 €** |

### ДАННИ ЗА СМАРТ КОНТРАКТ (SMART CONTRACT PAYOUT)

* **ID на задачата:** NG-D2-INSTALL-P3
* **Валута на изчисление:** EUR / NetGalaxy Token (NGT)
* **Обща стойност:** **245.83 €**
* **Разпределение:**

  * 💵 **Cash (40%):** **98.33 €**
  * 💎 **Tokens (60%):** **147.50 €**

---
