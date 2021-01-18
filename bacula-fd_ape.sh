#!/bin/bash
export HostName=`hostname`
export IpAddr=`sudo -H /bin/bash -c "ifconfig wan" |grep netmask | awk {'print $2'} | sed -E 's/(\.[^.]+){0}($)//g; s/,$//'`
fly-dialog --yesno 'АПЕ отдельностоящее ?'
if [[ $? = 0 ]]
  then 
    sed -i.bak '18,$d' /etc/bacula/bacula-fd.conf
  else
    export DirName=`fly-dialog --inputbox 'Введите имя сервера Bacula\nна котором будут хранится резервные копии'`
    if [[ `grep "$DirName" -c /etc/bacula/bacula-fd.conf` != 0 ]]
      then
        fly-dialog --error  "Запись о $DirName уже есть в конфигурационном файле.\nПроверьте схему резервного копирования.\nДля восстановления настроек по умолчанию ответьте ДА на предыдущий вопрос\n" --geometry 400x80+400+400
        exit 1
      else
        sudo -H /bin/bash -c "echo -e \"Director {\nName = $DirName\nPassword = \"clientpass\"\n}\nMessages {\nName = Standard_$DirName\ndirector = $DirName = all, !skipped, !restored\n}\" >> /etc/bacula/bacula-fd.conf"
        echo -e "Client {\nName = $HostName\nAddress = $IpAddr\nFDPort = 9102\nCatalog = BaculaCatalog\nPassword = \"clientpass\"\nFile Retention = 1 days\nJob Retention = 1 days\nAutoPrune = yes\n}" | ssh user@$DirName "sudo -H /bin/bash -c 'cat > /etc/bacula/client.d/$HostName.conf'"
#        echo -e "Job {\nName = \"$HostName\"\nJobDefs = \"DefaultJob\"\nLevel = Full\nClient = $HostName\nFileSet=\"Remote\"\nSchedule = \"Remote\"\nRunBeforeJob = \"/etc/bacula/scripts/2.sh\"\nRunBeforeJob = \"/etc/bacula/scripts/3.sh\"\nRunBeforeJob = \"/etc/bacula/scripts/make_catalog_backup.pl BaculaCatalog\"\nRunAfterJob = \"/etc/bacula/scripts/delete_catalog_backup\"\nWrite Bootstrap = \"/var/lib/bacula/%n.bsr\"\nPriority = 11\n}" | ssh user@$DirName "sudo -H /bin/bash -c 'cat > /etc/bacula/job.d/$HostName.conf'"
        echo -e "Job {\nName = \"Remote\"\nJobDefs = \"DefaultJob\"\nLevel = Full\nClient = $HostName\nFileSet = \"Remote\"\nSchedule = \"Remote\"\nEnabled = Yes\nPool = Remote\nClient Run Before Job = /etc/bacula/scripts/clean.sh\nClient Run Before Job = \"/etc/bacula/scripts/make_catalog_backup.pl BaculaCatalog\"\nClient Run After Job = \"/etc/bacula/scripts/delete_catalog_backup\"\nWrite Bootstrap = \"/var/lib/bacula/%n.bsr\"\nPriority = 10\n}" | ssh user@$DirName "sudo -H /bin/bash -c 'cat > /etc/bacula/job.d/$HostName.conf'"
    fi
fi
sudo -H /bin/bash -c 'systemctl restart bacula-fd.service'
exit 0
