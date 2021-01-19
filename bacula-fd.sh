#!/bin/bash
# Определяем переменные
HostName=`hostname`
DirName=`fly-dialog --inputbox 'Введите имя сервера Bacula'`
Job=""
FileSet=""
IpAddr=`sudo -H /bin/bash -c "ifconfig lan" |grep netmask | awk {'print $2'} | sed -E 's/(\.[^.]+){0}($)//g; s/,$//'`
JobsOnKSA=('basudb' 'ordl_battle' 'upi_admin' 'upi_battle' 'oper_full' 'KSA')
# Создаем необходимые каталоги, назначаем права и мандатные атрибуты
sudo -H /bin/bash -c 'mkdir  /restore'
sudo -H /bin/bash -c 'chown -R root:bacula /restore'
sudo -H /bin/bash -c 'chmod 765 /restore'
sudo -H /bin/bash -c 'pdpl-file 3:0:-1:ccnr /restore'
sudo -H /bin/bash -c 'mkdir /etc/bacula/backup-default-conf'
sudo -H /bin/bash -c 'mv   /etc/bacula/bacula-fd.conf /etc/bacula/backup-default-conf/bacula-fd.conf'

if [[ $HostName == ss-* ]] 
then
  export IpAddr=`sudo -H /bin/bash -c "ifconfig wan" |grep netmask | awk {'print $2'} | sed -E 's/(\.[^.]+){0}($)//g; s/,$//'`
    Job="Job {\n  Name = $HostName\n  JobDefs = \"DefaultJob\"\n  Level = Full\n  FileSet=SS\n  Schedule = \"DL\"\n  Pool = \"DL\"\n Client = $HostName\n Priority = 10\n}"
elif [[ $HostName == ksa-* ]]
  then
# Создаем каталог для создания дампов баз и копируем скрипты     
    sudo -H /bin/bash -c 'mkdir -p /var/lib/pgsql/data/{main,zud}/dump/'
    sudo -H /bin/bash -c 'pdpl-file -R 3:0:0:ccnr /var/lib/pgsql/'
    sudo -H /bin/bash -c 'pdpl-file -R 3:0:0:ccnr /var/lib/pgsql/data/'
    sudo -H /bin/bash -c 'pdpl-file -R 3:0:0:ccnr /var/lib/pgsql/data/main/'
    sudo -H /bin/bash -c 'pdpl-file -R 3:0:0:ccnr /var/lib/pgsql/data/main/dump/'
    sudo -H /bin/bash -c 'cp scripts/*database_backup* /etc/bacula/scripts/'

    for i in ${JobsOnKSA[@]}
    do
    if [ $i == KSA ]
    then
      Files="File = /var/lib/pgsql/data/main/globalobjects_main.sql\nFile = /var/lib/pgsql/data/zud/globalobjects_zud.sql\nFile = \"|/etc/bacula/scripts/listdbdump $IpAddr 5432 5433\""
      Job=${Job}"\n""Job {\n  Name = \"$i\"\n  Enabled = yes\n  JobDefs = \"DefaultJob\"\n  Level = Full\n  FileSet=\"$i\"\n  Schedule = $i\n  Client = $HostName\n  Client Run Before Job = \"/etc/bacula/scripts/make_database_backup_all\"\n  Client Run After Job  = \"/etc/bacula/scripts/delete_database_backup\"\n  Priority = 8\n}\n"
    elif [ $i == oper_full ]
      then
        Files="File = /var/lib/pgsql/data/main/dump\n  File = /home/user/circus/.circus/"
        Job=${Job}"\n""Job {\n  Name = \"$i\"\n  Enabled = no\n  JobDefs = \"DefaultJob\"\n  Level = Full\n  FileSet=\"$i\"\n  Client = $HostName\n  Client Run Before Job = \"/etc/bacula/scripts/make_database_backup sodo upi_battle\"\n  Client Run After Job  = \"/etc/bacula/scripts/delete_database_backup\"\n  Priority = 10\n}\n"
    else
      Files="File = /var/lib/pgsql/data/main/globalobjects_main.sql\nFile = /var/lib/pgsql/data/main/damp/$i.sql"
      Job=${Job}"\n""Job {\n  Name = \"$i\"\n  Enabled = no\n  JobDefs = \"DefaultJob\"\n  Level = Full\n  FileSet=\"$i\"\n  $Schedule\n  Client = $HostName\n  Client Run Before Job = \"/etc/bacula/scripts/make_database_backup $i\"\n  Client Run After Job  = \"/etc/bacula/scripts/delete_database_backup\"\n  Priority = 9\n}\n"
    fi
    FileSet=${FileSet}"\n\n""FileSet {\nName = \"$i\"\nInclude {\nOptions {\n  signature = MD5\n  aclsupport = yes\n  xattrsupport = yes\n}\n$Files\n}\n}"
    done
    echo -e "Client {\nName = $HostName\nAddress = $IpAddr\nFDPort = 9102\nCatalog = BaculaCatalog\nPassword = \"clientpass\"\nFile Retention = 1 days\nJob Retention = 1 days\nAutoPrune = yes\n}" | ssh user@$DirName "sudo -H /bin/bash -c 'cat > /etc/bacula/client.d/$HostName.conf'"
    echo -e $FileSet  | ssh user@$DirName "sudo -H /bin/bash -c 'cat > /etc/bacula/fileset.d/$HostName.conf'"
else
  Job="Job {\n  Name = $HostName\n  Type = Backup\n  JobDefs = \"DefaultJob\"\n  Client = $HostName\n  FileSet=\"DL\"\n  Schedule = \"DL\"\n  Messages = Standard\n}"
  echo -e "Client {\nName = $HostName\nAddress = $IpAddr\nFDPort = 9102\nCatalog = BaculaCatalog\nPassword = \"clientpass\"\nFile Retention = 1 days\nJob Retention = 1 days\nAutoPrune = yes\n}" | ssh user@$DirName "sudo -H /bin/bash -c 'cat > /etc/bacula/client.d/$HostName.conf'"
fi

sudo -H /bin/bash -c "echo -e \"FileDaemon {\nName = $HostName\nFDport = 9102\nWorkingDirectory = /var/lib/bacula\nPid Directory = /run/bacula\nMaximum Concurrent Jobs = 1\nPlugin Directory = /usr/lib/bacula\nFDAddress = $IpAddr\n}\nDirector {\nName = $DirName\nPassword = \"clientpass\"\n}\nMessages {\nName = Standard\ndirector = $DirName = all, !skipped, !restored\n}\" > /etc/bacula/bacula-fd.conf"	
echo -e $Job  | ssh user@$DirName "sudo -H /bin/bash -c 'cat > /etc/bacula/job.d/$HostName.conf'"

sudo -H /bin/bash -c 'systemctl restart bacula-fd.service'
sudo -H /bin/bash -c 'systemctl enable bacula-fd.service'
status=`systemctl status bacula-fd | grep "Active" | awk '{ print $2 }'`
if [ $status == 'active' ]; then
    echo -e "\e[32mСлужба bacula-fd установлена. Ошибок нет.\e[0m"
else
    echo -e "\e[31mВо времия запуска службы bacula-fd возникла ошибка.\e[0m"
    echo -e "\e[31mПроверьте конфигурационные файлы\e[0m"
    echo `/usr/sbin/bacula-fd -t -c /etc/bacula/bacula-fd.conf`
fi

exit 0
