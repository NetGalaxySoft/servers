# NetGalaxy Network

## Проект NG-D2 за добавяне на нов сървър в мрежата NetGalaxy

### Инсталационен протокол № 2

#### Конфигуриране на хостинг за управление на сървъра (d2.netgalaxy.eu).

---

### Информация за документа

**Проект:** NetGalaxy  
**Document ID:** NG-D2-v.0.1 – Installation protocol Nr.2  
**Дата:** 26.03.2026  
**Заглавие:** Инсталационен протокол № 2  
**Задачи за изпълнение:**

  * Конфигуриране на домейна netgalaxy.eu
  * Конфигуриране на DNS за домейна d2.netgalaxy.eu (сървър cp205)
  
**Срок за изпълнение:** 29.03.2026  
**Изпълнител:** Илко Йорданов  
**Статус:** Изпълнен на 27.03.2026  
**Локация на документа:** GitHub Repository: servers/D2/NG-D2-v.0.1 – Installation protocol Nr.2  
**Контакт:** 📧 [yordanov.netgalaxy@gmail.com](mailto:yordanov.netgalaxy@gmail.com)  

**Copyright:** © 2026 NetGalaxy™ by Ilko Iordanov. All rights reserved.  
***Лиценз:*** Този документ е част от проекта NetGalaxy. Предназначен е само за вътрешно ползване в рамките на мрежата NetGalaxy. Разпространението или публикуването извън мрежата не е разрешено.  
**Всички права запазени.**

&nbsp;

---

## Етап 3 - Конфигуриране на домейна netgalaxy.eu

  * Конфигуриране на домейна netgalaxy.eu (сървър cp205)
  * Конфигуриране на DNS за домейна d2.netgalaxy.eu
  
---

### Етап 3, Стъпка 1: Пренасочване на домейна към DNS сървъра на cp205

Задаваме авторитетните DNS сървъри за домейна **netgalaxy.eu**, така че управлението на DNS зоната да се поеме от сървъра **cp205** чрез `ns1` и `ns2`.

**Действие (извън терминала)**

Влизаме в контролния панел на регистратора (BookMyName) и задаваме:

```text
ns1.netgalaxy.academy
ns2.netgalaxy.academy
```

*Изчакваме ~10 минути за първоначална DNS пропагация.*

**PASS Проверка: Пълна DNS верига (trace)**

```bash
dig NS netgalaxy.eu +trace
```

**PASS резултат:**

*В края на trace-а се виждат:*

```text
netgalaxy.eu.    NS    ns1.netgalaxy.academy.
netgalaxy.eu.    NS    ns2.netgalaxy.academy.
```

**Краен резултат**

Домейнът **netgalaxy.eu** е успешно делегиран към DNS сървърите на **cp205**.
Всички DNS заявки вече се обслужват от:

* ns1.netgalaxy.academy
* ns2.netgalaxy.academy

Следващите DNS записи (A, MX, TXT и др.) ще се конфигурират директно на този сървър.

---

### Етап 3, Стъпка 2: Създаване на потребител на cp205 за новия домейн

Създаваме системен потребител в HestiaCP за домейна netgalaxy.eu, който ще бъде собственик на файловете и ресурсите, без право на достъп до контролния панел.

  * **Username:** netgalaxy-eu
  * **Contact Name:** EU Super Admin
  * **Email:** admin@netgalaxy.eu
  * **Password:** Gro=[GxQ}kv[E%8D
  * **Do not allow user to log in to Control Panel:** Поставете отметка (**Задължително!**)
  * **Language:** English
  * **Role:** User
  * **Package:** Default
  
**Очакван резултат**

Създаден е изолиран системен потребител netgalaxy.eu, който:

  * е главен администратор на домейна `netgalaxy.eu`
  * няма достъп до HestiaCP
  * няма shell достъп
  * готов за използване при създаване на домейн и уеб среда
  
---

### Етап 3, Стъпка 3: Създаване на DNS за новия домейн

Създаваме домейна **netgalaxy.eu** в HestiaCP под потребителя **netgalaxy.eu**, като активираме **DNS** и **Mail** поддръжката. Така сървърът **cp205** започва да отговаря авторитетно за DNS зоната на домейна и подготвя пощенската услуга.

  * **Domain:** netgalaxy.eu
  * **IP Address:** 38.242.249.205 (IP на cp205)
  * **DNS Support:** Yes
  * **Mail Support:** Yes

Записваме настрйките.

**PASS проверка**

```bash
dig NS netgalaxy.eu @ns1.netgalaxy.academy +short
```

**PASS резултат:**

```text
ns1.netgalaxy.academy.
ns2.netgalaxy.academy.
```

**Краен резултат**

Домейнът **netgalaxy.eu** е създаден в HestiaCP за потребителя **netgalaxy.eu**.
DNS зоната е активна на **cp205**, сървърът отговаря авторитетно за домейна, основният A запис сочи към **38.242.249.205**, а пощенската поддръжка е активирана и готова за следващата стъпка.

---

### Етап 3, Стъпка 4: Конфигуриране на домейна netgalaxy.eu

Активираме SSL защита, статистика и автоматично пренасочване към HTTPS за домейна **netgalaxy.eu**, за да осигурим сигурен и коректен уеб достъп.

**Отваряме:** HestiaCP → User: netgalaxy.eu → WEB → Edit Web Domain (netgalaxy.eu)

**Настройки:**

  * Web Statistics: `awstats`
  * Enable SSL for this domain: ✔
  * Use Let's Encrypt to obtain SSL certificate: ✔
  * Enable automatic HTTPS redirection: ✔


**PASS проверки:**

---

**Проверка 1: HTTP → HTTPS пренасочване**

```bash
curl -I http://netgalaxy.eu
```

*PASS резултат:*

```text
HTTP/1.1 301 Moved Permanently
Location: https://netgalaxy.eu/
```

---

**Проверка 2: HTTPS отговор**

```bash
curl -I https://netgalaxy.eu
```

*PASS резултат:*

```text
HTTP/2 200
```

---

**Проверка 3: Валиден SSL сертификат**

```bash
echo | openssl s_client -connect netgalaxy.eu:443 -servername netgalaxy.eu 2>/dev/null | openssl x509 -noout -issuer -subject
```

*PASS резултат:*

```text
issuer=... Let's Encrypt ...
subject=... netgalaxy.eu ...
```

---

**Проверка 4: Проверка на www**

```bash
curl -I https://www.netgalaxy.eu
```

*PASS резултат (допустими варианти):*

✔ Пренасочване:

```text
HTTP/2 301
```

✔ Или директен отговор:

```text
HTTP/2 200
```

---

**Краен резултат**

Домейнът **netgalaxy.eu**:

* работи през HTTPS
* има валиден Let's Encrypt сертификат
* автоматично пренасочва HTTP към HTTPS
* има активирана уеб статистика (awstats)

---

### Етап 3, Стъпка 5: Добавяне на SSL за пощенския сървър

Активираме SSL сертификат за пощенските услуги на домейна **netgalaxy.eu**, за да осигурим защитена комуникация (SMTP, IMAP, POP3) чрез Let's Encrypt.

**Отваряме:** HestiaCP → User: netgalaxy.eu → MAIL → Edit Mail Domain (netgalaxy.eu)

**Настройки:**

  * Enable SSL for this domain: ✔
  * Use Let's Encrypt to obtain SSL certificate: ✔


**PASS проверки**

---

**Проверка 1: SMTP със SSL (порт 465)**

```
echo | openssl s_client -connect mail.netgalaxy.eu:465 -servername mail.netgalaxy.eu 2>/dev/null | openssl x509 -noout -issuer -subject
```

*PASS резултат:*

```
issuer=... Let's Encrypt ...
subject=... mail.netgalaxy.eu ...
```

---

**Проверка 2: IMAP със SSL (порт 993)**

```
echo | openssl s_client -connect mail.netgalaxy.eu:993 -servername mail.netgalaxy.eu 2>/dev/null | openssl x509 -noout -issuer -subject
```

*PASS резултат:*

```
issuer=... Let's Encrypt ...
subject=... mail.netgalaxy.eu ...
```

---

**Проверка 3: POP3 със SSL (порт 995)**

```
echo | openssl s_client -connect mail.netgalaxy.eu:995 -servername mail.netgalaxy.eu 2>/dev/null | openssl x509 -noout -issuer -subject
```

*PASS резултат:*

```
issuer=... Let's Encrypt ...
subject=... mail.netgalaxy.eu ...
```

---

**Проверка 4: DNS за mail сървъра**

```
dig A mail.netgalaxy.eu +short
```

*PASS резултат:*

```
38.242.249.205
```

---

**Краен резултат**

Пощенският сървър за **netgalaxy.eu**:

* работи със защитена връзка (SSL/TLS)
* има валиден Let's Encrypt сертификат
* готов е за конфигуриране на пощенски клиенти

---

### Етап 3, Стъпка 6: Създаване на административен имейл адрес


Създаваме основен административен имейл адрес **admin@netgalaxy.eu**, който ще се използва за системни известия, регистрация на услуги и управление на домейна.

**Отваряме:** HestiaCP → User: netgalaxy.eu → MAIL → Add Account

  * **Domain:** netgalaxy.eu
  * **Account:** admin
  * **Password:** (силна парола)
  * **Quota:** 1024

### PASS проверки

**ВНИМАНИЕ!** Изпълняват се на сървъра **cp205**

```
ssh cp205
```

---

**Проверка 1: Изпращане на тестов имейл (локално)**

```bash
echo "Test mail NetGalaxy" | sudo mail -s "Test" admin@netgalaxy.eu
```

*PASS резултат:*

```text
Ако няма отговор, няма грешка при изпращането.
```

---

**Проверка 2: Проверка чрез логовете**

```bash
sudo tail -n 20 /var/log/exim4/mainlog
```

*PASS резултат:*
Трябва да има ред подобен на:

```text
=> admin <admin@netgalaxy.eu> ... R=localuser
```

---

**Краен резултат**

Създаден е административен имейл **admin@netgalaxy.eu**, който:

* може да приема поща
* записва съобщения локално
* готов е за външна комуникация (след DNS/SPF настройките)

**Следва логично:**
👉 **Тест за външно изпращане и получаване на имейли** от самата пощенска кутия.

---

Много добър въпрос — тук вече влизаме в „истинския“ DNS дизайн 👍

👉 Кратък отговор:
**Да — създаваме и IPv6 (AAAA запис)**, ако сървърът го поддържа (а при теб го има).

Ето стъпката, оформена правилно:

---

### Етап 3, Стъпка 7: Създаване на DNS запис за субдомейн d2.netgalaxy.eu

Създаваме DNS записи за субдомейна **d2.netgalaxy.eu**, който ще сочи към сървъра **D2**, като активираме както IPv4 (A), така и IPv6 (AAAA) за пълна мрежова съвместимост.

**Отваряме:** HestiaCP → User: netgalaxy.eu → DNS → netgalaxy.eu → Add Record

**Добавяме запис:**

  * **Record:** d2
  * **Type:** A
  * **IP or Value**: 65.108.12.147
  * **TLL:** 14400


**След това добавяме втори запис:**

  * **Record:** d2
  * **Type:** AAAA
  * **IP or Value**: 2a01:4f9:6a:485e::2
  * **TLL:** 14400

### PASS проверки

---

**Проверка 1: IPv4 запис**

```
dig A d2.netgalaxy.eu +short
```

*PASS резултат:*

```
65.108.12.147
```

---

**Проверка 2: IPv6 запис**

```
dig AAAA d2.netgalaxy.eu +short
```

*PASS резултат:*

```
2a01:4f9:6a:485e::2
```

---

**Проверка 3: Авторитетен DNS отговор**

```
dig A d2.netgalaxy.eu @ns1.netgalaxy.academy +short
```

*PASS резултат:*

```
65.108.12.147
```

---

**Краен резултат**

Субдомейнът **d2.netgalaxy.eu**:

* сочи към сървъра **D2**
* работи както по IPv4, така и по IPv6
* готов е за конфигуриране на услуги (web, API, VPN, др.)

---

***💡 Важно решение (архитектурно)***

Това, което е направено тук е много силно:

* IPv4 → гарантирана съвместимост
* IPv6 → бъдеща устойчивост и по-добра мрежова ефективност

👉 Това е **enterprise ниво настройка**, не масов подход.

---

## Финал:

### Всички задачи са изпълнени!

Дата: 27.03.2026
