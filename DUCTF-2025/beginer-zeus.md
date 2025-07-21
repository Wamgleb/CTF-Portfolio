# Zeus Invocation - DUCTF 2025

**Category:** Reversing / Binary Exploitation  
**CTF Platform:** DUCTF  
**Challenge Name:** Zeus Invocation

---

## 📜 Challenge Description

> To Zeus Maimaktes, Zeus who comes when the north wind blows, we offer our praise, we make you welcome!

---

## 🛠 Solution

### 1. File Identification

Received a file named `zeus`.

```bash
file zeus
````

**Result:**
ELF 64-bit LSB pie executable, x86-64, dynamically linked, not stripped.

---

### 2. Initial Analysis

Listed printable strings inside the binary:

```bash
strings zeus
```

Noticed relevant strings:

* `Maimaktes1337`
* `Zeus responds to your invocation!`
* `-invocation`

This suggested that the binary expects arguments via command-line.

---

### 3. Dynamic Analysis using `ltrace`

Executed:

```bash
ltrace ./zeus -invocation test
```

Detected direct string comparison via `strcmp()` between the input argument and the following long string:

```
To Zeus Maimaktes, Zeus who comes when the north wind blows, we offer our praise, we make you welcome!
```

---

### 4. Exploitation

Launched the binary with the discovered string:

```bash
./zeus -invocation "To Zeus Maimaktes, Zeus who comes when the north wind blows, we offer our praise, we make you welcome!"
```

Received the response:

```
Zeus responds to your invocation!
His reply: DUCTF{example_flag}
```

*(Note: Real flag redacted to respect CTF policies.)*

---

## 🛠 Tools Used

* `file`
* `strings`
* `ltrace`
* `chmod`

---

## 💡 Skills Demonstrated

* Basic reverse engineering
* Binary argument injection
* String comparison analysis
* Dynamic binary analysis using `ltrace`

---

## 🏆 Summary

This challenge demonstrated a simple but effective use of string comparison inside a dynamically linked ELF binary. Using basic reverse engineering and dynamic analysis techniques, it was possible to identify the expected input and extract the flag without the need for deep binary exploitation.

---

*Author: \[WAm0x0x0]*
*Challenge completed in July 2025.*
