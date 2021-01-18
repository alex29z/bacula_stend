#!/bin/bash
export HOST_SS="25"
export NET=`ifconfig lan |grep netmask | awk {'print $2'} | sed -E 's/(\.[^.]+){1}($)/./g; s/,$//'`
export LAN_SS=$NET"$HOST_SS"
export BACULA="bacula"
export BACULA_PSWD="bacula"
Dirs=('schedule.d' 'client.d' 'fileset.d' 'job.d' 'pool.d')

# Вносим изменения в файлы конфигурации postgresql:
cp /etc/postgresql/9.6/main/postgresql.conf /etc/postgresql/9.6/main/postgresql.conf_bak
cp /etc/postgresql/9.6/main/pg_hba.conf /etc/postgresql/9.6/main/pg_hba.conf_bak
sed -i -e "/listen_addresses/s/^/#/" -i  -e "/listen_addresses/a\ \t\listen_addresses='*'" /etc/postgresql/9.6/main/postgresql.conf
sed -i -e "s/local *all *postgres/#&/" /etc/postgresql/9.6/main/pg_hba.conf
sed -i -e "/local *all *postgres/a\local\tall\tpostgres\ttrust" /etc/postgresql/9.6/main/pg_hba.conf
sed -i -e "s/local *all *all/#&/" /etc/postgresql/9.6/main/pg_hba.conf
sed -i -e "/local *all *all/a\local\tall\tall\ttrust\nhost\tall\tall\t\127.0.0.1/32\ttrust\nhost\tall\tall\t$LAN_SS/24\ttrust" /etc/postgresql/9.6/main/pg_hba.conf
sed -i -e "s/host *all *all/#&/" /etc/postgresql/9.6/main/pg_hba.conf

#Перезапускаем БД:
pg_ctlcluster 9.6 main restart

# Меняем пароли пользователей postgres и bacula
echo "postgres:1" | chpasswd &> /dev/null
echo "$BACULA:1" | chpasswd &> /dev/null

# Создаем пользователя bacula
>/tmp/adduser.sql
chmod 644 /tmp/adduser.sql
echo "CREATE ROLE $BACULA;
		ALTER USER $BACULA WITH PASSWORD '$BACULA_PSWD';
		ALTER USER $BACULA LOGIN SUPERUSER CREATEDB CREATEROLE;" > /tmp/adduser.sql
cd /tmp
su -c "psql template1 -U postgres -h $LAN_SS -p 5432 -f /tmp/adduser.sql" postgres
rm /tmp/adduser.sql

# Создаем базу данных bacula
>/tmp/adddb.sql
chmod 644 /tmp/adddb.sql
echo "CREATE DATABASE bacula;
      ALTER DATABASE bacula OWNER TO $BACULA;" > /tmp/adddb.sql
cd /tmp
su -c "psql postgres -p 5432 -U postgres -f /tmp/adddb.sql" postgres
rm /tmp/adddb.sql

# Вносим изменения в скрипты,
# выдаем права на чтение информации из БД пользователей и сведений о метках безопасности, а так же присваиваем для этого необходимые атрибуты пользователю postgres
sed -i -e /db_name/s/^/#/ /usr/share/bacula-director/make_postgresql_tables
sed -i -e "/psql/a\db_name=\${db_name:-bacula}\npsql\ -U\ $BACULA\ -h\ $LAN_SS\ -p\ 5432\ -f\ -\ -d\ \${db_name}\ \$*\ \<<END-OF-DATA" /usr/share/bacula-director/make_postgresql_tables
sed -i -e "/XXX_DBUSER_XXX/s/^/#/" -i -e "/XXX_DBUSER_XXX/a\db_user=\${db_user:-$BACULA}" /usr/share/bacula-director/grant_postgresql_privileges
sed -i -e "/XXX_DBNAME_XXX/s/^/#/" -i -e "/XXX_DBNAME_XXX/a\db_name=\${db_name:-$BACULA}" /usr/share/bacula-director/grant_postgresql_privileges
sed -i -e "/XXX_DBPASSWORD_XXX/s/^/#/" -i -e "/XXX_DBPASSWORD_XXX/a\db_password=$BACULA_PSWD" /usr/share/bacula-director/grant_postgresql_privileges
sed -i -e "/bindir\/psql/s/^/#/" -i -e "/bindir\/psql/a\$bindir\/psql\ -U\ $BACULA\ -h\ $LAN_SS\ -p\ 5432\ -f\ -\ -d\ \${db_name} $* <<END-OF-DATA" /usr/share/bacula-director/grant_postgresql_privileges

sed -i -e /zero_if_notfound/s/^/#/ /etc/parsec/mswitch.conf
sed -i -e /zero_if_notfound/a\zero_if_notfound:yes /etc/parsec/mswitch.conf

usermod -a -G shadow postgres

setfacl -d -m u:postgres:r /etc/parsec/macdb
setfacl -R -m u:postgres:r /etc/parsec/macdb
setfacl -m u:postgres:rx /etc/parsec/macdb

setfacl -d -m u:postgres:r /etc/parsec/capdb
setfacl -R -m u:postgres:r /etc/parsec/capdb
setfacl -m u:postgres:rx /etc/parsec/capdb

pdpl-user bacula -l 0:0

for j in ${Dirs[@]}
do
  if ! [ -d /etc/bacula/$j/ ]; then
    mkdir /etc/bacula/$j/
  fi
  cp $j/*.conf /etc/bacula/$j/
done

# запускаем скрипты
/usr/share/bacula-director/make_postgresql_tables
/usr/share/bacula-director/grant_postgresql_privileges
