#!/bin/bash
# Принудительно помечает старые архивы как удаленные
export DBUser=bacula
export DBName=bacula
clients=`psql -U $DBUser -d $DBName -t -c 'select Name from Client ORDER BY Name;'`
for client in `echo $clients`
do
  echo "prune files client=${client} yes" | bconsole
done

# Удаляет помеченные архивы из БД и с диска

WorkDir=/backups
for f in `echo "list volume" | bconsole | grep Purged | cut -d '|' -f3`; do
  echo "delete volume=$f yes" | bconsole;
  rm -rf $WorkDir/files{1,2}/$f;
done

# Скрипт удаляет файлы, записи для которых отсутствует в БД

WorkDir=/backups
for DIR in $WorkDir/files{1,2}; do
cd $DIR
for i in `find . -maxdepth 1 -type f -printf "%f\n"`; do
  echo "list volume=$i" | bconsole | if grep --quiet "No results to list"; then
        echo "$i is ready to be deleted"
        rm -f $DIR/$i
  fi
done
done