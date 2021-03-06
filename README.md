# LibrePhotos installation script for Linux

## requirement 
  - Debian 11 (python 3.9)
  - postgresql
  - redis

## Installation

### Debian like distribution

Execute following commande as root
~~~
cd /tmp/
git clone git@github.com:LibrePhotos/librephotos-linux.git
cd librephotos-linux
./install-librephotos.sh 
~~~

Other way can be use download archive
~~~
wget https://github.com/librephotos/librephotos-linux/archive/main.zip -O /tmp/main.zip
unzip -d /tmp/ /tmp/main.zip
cd /tmp/librephotos-linux-main/
./install-librephotos.sh
~~~

Edit /etc/librephotos/librephotos-backend
 - SECRET_KEY
 - Postgresql information
 - redis information
~~~
nano /etc/librephotos/librephotos-backend
~~~

Create admin user as root with the following commande
~~~
/usr/lib/librephotos/bin/librephotos-createadmin <user> <email> [<paswword>]
~~~

reboot or start services
~~~
systemctl start librephotos-image-similarity.service
systemctl start librephotos-worker.service
systemctl start librephotos-backend
systemctl start librephotos-frontend
~~~
### Other distribution

not working yet

## additional information

### librephotos-cli

As root you can use 

~~~
librephotos-cli build_similarity_index
librephotos-cli clear_cache
~~~

### Postgresql creation database script

~~~
CREATE USER librephotos WITH PASSWORD 'password';
CREATE DATABASE "librephotos" WITH OWNER "librephotos" ENCODING 'UTF8' LC_COLLATE = 'fr_FR.UTF-8' LC_CTYPE = 'fr_FR.UTF-8' TEMPLATE template0;
GRANT ALL privileges ON DATABASE librephotos TO librephotos;
~~~

### Samba mount point sample

Install cifs-utils :

~~~
apt install cifs-utils
~~~

On /etc/fstab add the following line :

~~~
//data.lan.lgy.fr/ftcl/photos/ /var/lib/librephotos/data/photos cifs uid=librephotos,gid=librephotos,credentials=/etc/samba/smbcredentials,iocharset=utf8,file_mode=0777,dir_mode=0777,sec=ntlmssp,noacl 0 0
~~~

create file /etc/samba/smbcredentials with bellow connexion informations

~~~
username=thomas
password=mypassword
domain=my.domain.com
~~~
