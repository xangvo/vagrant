#
# setting service
#
/sbin/service iptables stop
/sbin/chkconfig iptables off

#
# yum repository
#
ius=http://dl.iuscommunity.org/pub/ius/stable/CentOS/$(uname -r | sed 's/.*el//;s/\..*$//;s/[^0-9]//g')/$(uname -i)
curl -sL $ius | sed 's/.*\(\(epel\|ius\)-release.*rpm\).*/\1/p;d' | xargs -i rpm -Uvh $ius/{}

yum -y update
yum -y install yum-plugin-replace

#
# MySQL
#
if [ "`rpm -V mysql55-libs`" ];then
	yum -y install mysql
	yum -y replace mysql --replace-with mysql55
	yum -y install mysql55-server
fi
cp /vagrant/conf/mysql/my.cnf /etc/my.cnf
/sbin/service mysqld start
/sbin/chkconfig mysqld on
mysqladmin -u root create myDB --default-character-set=utf8
mysql -uroot myDB < /data/db/myDB.dump

#
# php
#
#yum -y install php54 php54-cli php54-pdo php54-mbstring php54-mcrypt php54-pecl-memcache php54-mysqlnd php54-devel php54-common php54-pear php54-gd php54-xml php54-pecl-xdebug php54-pecl-apc

yum -y install php56u.i686  php56u-cli.i686  php56u-pdo.i686 php56u-mbstring.i686 php56u-mcrypt.i686   php56u-pecl-memcache.i686 php56u-mysqlnd.i686  php56u-pecl-apcu-devel.i686 php56u-common.i686 php56u-pear.noarch php56u-gd.i686 php56u-xml.i686 php56u-pecl-xdebug.i686  php56u-pecl-apcu.i686

#yum -y install php.i686  php-mcrypt  php-cli.i686 php-common.i686     php-dba.i686        php-devel.i686      php-embedded.i686   php-enchant.i686    php-fpm.i686        php-gd.i686         php-imap.i686       php-intl.i686       php-ldap.i686       php-mbstring.i686   php-mysql.i686      php-odbc.i686       php-pdo.i686        php-pear.noarch     php-pecl-apc.i686   php-pecl-apc-devel.iphp-pecl-memcache.i6php-pgsql.i686      php-process.i686    php-pspell.i686     php-recode.i686     php-snmp.i686       php-soap.i686       php-tidy.i686       php-xml.i686        php-xmlrpc.i686     php-zts.i686        rrdtool-php.i686    uuid-php.i686
touch /var/log/php.log && chmod 666 /var/log/php.log
cp /vagrant/conf/php/php.ini /etc/php.ini

#
# Apache - HTTPS - SSL
#
yum -y install httpd httpd-tools cronolog
yum -y install mod_ssl openssl

cd /data/
openssl genrsa -out ca.key 2048
openssl req -new -key ca.key -out ca.csr -subj "/C=GB/ST=London/L=London/O=Global Security/OU=IT Department/CN=localhost"
openssl x509 -req -days 365 -in ca.csr -signkey ca.key -out ca.crt

cp ca.crt /etc/pki/tls/certs
cp ca.key /etc/pki/tls/private/ca.key
cp ca.csr /etc/pki/tls/private/ca.csr
cp /vagrant/conf/apache/ssl.conf /etc/httpd/conf.d/ssl.conf

cp /vagrant/conf/apache/httpd.conf /etc/httpd/conf/
/sbin/service httpd start
/sbin/chkconfig httpd on

service httpd restart

#
# Postfix
#
yum -y install postfix
cp /vagrant/conf/postfix/main.cf /etc/postfix/
cp /vagrant/conf/postfix/transport /etc/postfix/
postmap /etc/postfix/transport
/sbin/service postfix restart
/sbin/chkconfig postfix on

#
# Dovecot
#
yum -y install dovecot
cp /vagrant/conf/dovecot/10-mail.conf /etc/dovecot/conf.d/
/sbin/service dovecot start
/sbin/chkconfig dovecot on

#
# Composer
#
cd /var/tmp/
curl -s http://getcomposer.org/installer | php
mv ./composer.phar /usr/local/bin/composer

#
# etc
#
yum -y install vim
yum -y install screen
yum -y install man
yum -y install man-pages-ja
yum -y install bind-utils
yum -y install git
