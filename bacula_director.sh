#!/bin/bash
export WanAddr=`ifconfig wan |grep netmask | awk {'print $2'} | sed -E 's/(\.[^.]+){0}($)//g; s/,$//'`
export LanAddr=`ifconfig lan |grep netmask | awk {'print $2'} | sed -E 's/(\.[^.]+){0}($)//g; s/,$//'`
export HostName=`hostname`
DirIp="25"
KSAIp="1"
DirIpAddr=$WanAddr
mkdir /etc/bacula/backup-default-conf
mv /etc/bacula/bacula-dir.conf /etc/bacula/backup-default-conf/bacula-dir.conf
echo -e "Director {\nName = $HostName\nDIRport = 9101\nQueryFile = \"/etc/bacula/scripts/query.sql\"\nWorkingDirectory = \"/var/lib/bacula\"\nPidDirectory = \"/run/bacula\"\nMaximum Concurrent Jobs = 1\nPassword = \"dirpass\"\nMessages = Daemon\nDirAddress = $DirIpAddr\n}\nCatalog {\nName = BaculaCatalog\nDB Address = $LanAddr\nDB PORT = 5432\ndbname = bacula\ndbuser = bacula\ndbpassword = bacula\n}\nJobDefs {\nName = \"DefaultJob\"\nType = Backup\nLevel = Full\nClient = $HostName\nFileSet = \"Catalog\"\nSchedule = \"Catalog\"\nStorage = $HostName\nMessages = Standard\nPool = Catalog\nSpoolAttributes = yes\nPriority = 10\nWrite Bootstrap = \"/var/lib/bacula/%c.bsr\"\n}\nStorage {\nName = $HostName\nAddress = $WanAddr\nSDPort = 9103\nPassword = \"storpass\"\nDevice = Autochanger1\nMedia Type = File1\nMaximum Concurrent Jobs = 1\n}\nPool {\nName = Catalog\nPool Type = Backup\nRecycle = no\nVolume Retention = 1 hours\nActionOnPurge = Truncate\nAutoPrune = yes\nMaximum Volume Jobs = 1\nLabel Format = \"\${Pool}-\${Level}-\${Client}-\${Year}-\${Month:p/2/0/r}-\${Day:p/2/0/r}-\${Hour:p/2/0/r}-\${Minute:p/2/0/r}\"\n}\nMessages {\nName = Standard\nmailcommand = \"/usr/sbin/bsmtp -h localhost -f \"\(Bacula\) \<%r\>\" -s \"Bacula: %t %e of %c %l\" %r\"\noperatorcommand = \"/usr/sbin/bsmtp -h localhost -f \"\(Bacula\) \<%r\>\" -s \"Bacula: Intervention needed for %j\" %r\"\nmail = root = all, !skipped\noperator = root = mount\nconsole = all, !skipped, !saved\nappend = \"/var/log/bacula/bacula.log\" = all, !skipped\ncatalog = all\n}\nMessages {\nName = Daemon\nmailcommand = \"/usr/sbin/bsmtp -h localhost -f \"\(Bacula\) \<%r\>\" -s \"Bacula daemon message\" %r\"\nmail = root = all, !skipped\nconsole = all, !skipped, !saved\nappend = \"/var/log/bacula/bacula.log\" = all, !skipped\n}" > /etc/bacula/bacula-dir.conf
echo -e "@|\"sh -c 'for f in /etc/bacula/job.d/*.conf ; do echo @\${f} ; done'\"" >> /etc/bacula/bacula-dir.conf
echo -e "@|\"sh -c 'for f in /etc/bacula/client.d/*.conf ; do echo @\${f} ; done'\"" >> /etc/bacula/bacula-dir.conf
echo -e "@|\"sh -c 'for f in /etc/bacula/fileset.d/*.conf ; do echo @\${f} ; done'\"" >> /etc/bacula/bacula-dir.conf
echo -e "@|\"sh -c 'for f in /etc/bacula/schedule.d/*.conf ; do echo @\${f} ; done'\"" >> /etc/bacula/bacula-dir.conf
echo -e "@|\"sh -c 'for f in /etc/bacula/pool.d/*.conf ; do echo @\${f} ; done'\"" >> /etc/bacula/bacula-dir.conf

# Добавить проверку на существование
mkdir /etc/bacula/schedule.d/
mkdir /etc/bacula/client.d/
mkdir /etc/bacula/fileset.d/
mkdir /etc/bacula/job.d/
mkdir /etc/bacula/pool.d/

cp schedule.d/*.conf /etc/bacula/schedule.d/
#cp client.d/*.conf /etc/bacula/client.d/
cp fileset.d/*.conf /etc/bacula/fileset.d/
cp job.d/*.conf /etc/bacula/job.d/
cp pool.d/*.conf /etc/bacula/pool.d/
echo -e "Job {\nName = \"RestoreFiles\"\nType = Restore\nClient = $HostName\nFileSet=\"DL\"\nStorage = $HostName\nPool = DL\nMessages = Standard\nWhere = /restore\n}" > /etc/bacula/job.d/restore.conf
echo -e "Client {\nName = $HostName\nAddress = $WanAddr\nFDPort = 9102\nCatalog = BaculaCatalog\nPassword = \"clientpass\"\nFile Retention = 1 days\nJob Retention = 1 days\nAutoPrune = yes\n}" > /etc/bacula/client.d/$HostName.conf
cp scripts/listdbdump /etc/bacula/scripts/listdbdump
cp scripts/delete_catalog_backup /etc/bacula/scripts/delete_catalog_backup
cp scripts/clean.sh /etc/bacula/scripts/clean.sh

chmod 644 /etc/bacula/bacula-dir.conf
chown root:bacula /etc/bacula/bacula-dir.conf
chmod 755 /etc/bacula/job.d/
chown root:bacula /etc/bacula/job.d/
chmod 644 /etc/bacula/job.d/*
chown root:bacula /etc/bacula/job.d/*
chmod 755 /etc/bacula/client.d/
chown root:bacula /etc/bacula/client.d/
chmod 644 /etc/bacula/client.d/*
chown root:bacula /etc/bacula/client.d/*
chmod 755 /etc/bacula/fileset.d/
chown root:bacula /etc/bacula/fileset.d/
chmod 644 /etc/bacula/fileset.d/*
chown root:bacula /etc/bacula/fileset.d/*
chmod 755 /etc/bacula/schedule.d/
chown root:bacula /etc/bacula/schedule.d/
chmod 644 /etc/bacula/schedule.d/*
chown root:bacula /etc/bacula/schedule.d/*
chmod 755 /etc/bacula/pool.d/
chown root:bacula /etc/bacula/pool.d/
chmod 644 /etc/bacula/pool.d/*
chown root:bacula /etc/bacula/pool.d/*
mv   /etc/bacula/bat.conf /etc/bacula/backup-default-conf/bat.conf
mv   /etc/bacula/bconsole.conf /etc/bacula/backup-default-conf/bconsole.conf
echo -e "Director {\nName = $HostName\nDIRport = 9101\naddress = $DirIpAddr\nPassword = \"dirpass\"\n}" > /etc/bacula/bat.conf
echo -e "Director {\nName = $HostName\nDIRport = 9101\naddress = $DirIpAddr\nPassword = \"dirpass\"\n}" > /etc/bacula/bconsole.conf
systemctl restart bacula-director.service
systemctl enable bacula-director.service
