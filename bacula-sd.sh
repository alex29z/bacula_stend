#!/bin/bash
export IpAddr=`ifconfig wan |grep netmask | awk {'print $2'} | sed -E 's/(\.[^.]+){0}($)//g; s/,$//'`
export HostName=`hostname`
mkdir -p /backups/files{1,2}
chown -R bacula:tape /backups
chmod 766 /backups/files{1,2}
mkdir /etc/bacula/backup-default-conf
mv /etc/bacula/bacula-sd.conf /etc/bacula/backup-default-conf/bacula-sd.conf
echo -e "Storage {\nName = $HostName\nSDPort = 9103\nWorkingDirectory = "/var/lib/bacula"\nPid Directory = "/run/bacula"\nMaximum Concurrent Jobs = 5\nSDAddress = $IpAddr\n}\nDirector {\nName = $HostName\nPassword = "storpass"\n}\nAutochanger {\nName = Autochanger1\nDevice = FileChgr1-Dev1, FileChgr1-Dev2\nChanger Command = \"\"\nChanger Device = /dev/null\n}\nDevice {\nName = FileChgr1-Dev1\nMedia Type = File1\nArchive Device = /backups/files1\nLabelMedia = yes\nRandom Access = Yes\nAutomaticMount = yes\nRemovableMedia = no;\nAlwaysOpen = no;\nMaximum Concurrent Jobs = 1\n}\nDevice {\nName = FileChgr1-Dev2\nMedia Type = File1\nArchive Device = /backups/files2\nLabelMedia = yes\nRandom Access = Yes\nAutomaticMount = yes\nRemovableMedia = no\nAlwaysOpen = no\nMaximum Concurrent Jobs = 1\n}\nMessages {\nName = Standard\ndirector = $HostName = all\n}" > /etc/bacula/bacula-sd.conf
systemctl restart bacula-sd.service
systemctl enable bacula-sd.service
status=`systemctl status bacula-sd | grep "Active" | awk '{ print $2 }'`
if [ $status == 'active' ]; then
    echo -e "\e[32mСлужба bacula-sd установлена. Ошибок нет.\e[0m"
else
    echo -e "\e[31mВо времия запуска службы bacula-sd возникла ошибка.\e[0m"
    echo -e "\e[31mПроверьте конфигурационные файлы\e[0m"
    echo `/usr/sbin/bacula-sd -t -c /etc/bacula/bacula-sd.conf`
fi
exit 0
