#!/usr/bin/env bash
[ -f /etc/init.d/iptables ] && /sbin/service iptables status | grep -v 'stopped'
if [ $? -eq 0 ]; then
  /sbin/service iptables stop
  /sbin/chkconfig iptables off
fi

if [ ! -f /home/vagrant/.vbox-version ]; then
  echo 'Resolve DNS'
  echo "nameserver 8.8.8.8" > /etc/resolv.conf
fi

# Initialize
if [ ! -f /etc/profile.d/path.sh ]; then
  /bin/cp /vagrant/config/bash/path.sh /etc/profile.d/path.sh
  . /etc/profile.d/path.sh
fi

if [ ! -f /usr/bin/which ]; then
  yum install -y which

  if [ ! -f /usr/bin/which ]; then
    echo 'Can not install which'
  fi
fi

which nkf > /dev/null
if [ $? -ne 0 ]; then
  yum install -y nkf
  which nkf > /dev/null
  if [ $? -ne 0 ]; then
    echo 'Can not install nkf'
  fi
fi

# Initialize
yum install -y gcc kernel-devel wget
yum -y install zlib zlib-devel
yum -y install openssl openssl-devel
CURRENT_PWD=`pwd`
PRI_IFS=$IFS

VBOX_VERSION=
if [ "x${1}" != "x" ]; then
  VBOX_VERSION="${1}"
fi

if [ ! -f /home/vagrant/.vbox-version ]; then
  if [ x${VBOX_VERSION} != x ]; then
    echo "Start install vboxguess version: ${VBOX_VERSION}"
    cd /opt
    wget -c http://download.virtualbox.org/virtualbox/${VBOX_VERSION}/VBoxGuestAdditions_${VBOX_VERSION}.iso \-O VBoxGuestAdditions_${VBOX_VERSION}.iso > /dev/null
    if [ $? -ne 0 ]; then
      echo "Vboxguest version ${VBOX_VERSION} is not supported"
      exit
    fi

    mount VBoxGuestAdditions_${VBOX_VERSION}.iso -o loop /mnt
    cd /mnt
    sudo sh VBoxLinuxAdditions.run --nox11
    cd /opt
    rm -f *.iso
    /etc/init.d/vboxadd setup
    /sbin/chkconfig --add vboxadd
    /sbin/chkconfig vboxadd on
    echo "Finished installing vboxguess version: ${VBOX_VERSION}, system shutdown, please 'vagrant up --provision' again"
    echo ${VBOX_VERSION} > /home/vagrant/.vbox-version
    shutdown -h now
    exit
  else
    echo 'Please run "vagrant --vbox-version=$VBOX_VERSION provision"'
    exit
  fi
fi

# Bash profile
if [ -f /home/vagrant/.bash_profile ]; then
  /bin/cp /vagrant/config/bash/bash_profile /home/vagrant/.bash_profile
  nkf -Lu --overwrite /home/vagrant/.bash_profile
  chown vagrant:vagrant /home/vagrant/.bash_profile
fi

# User util commands
mkdir -p /home/vagrant/bin
if [ -d /vagrant/config/bash/bin ]; then
  /bin/cp -rf /vagrant/config/bash/bin/* /home/vagrant/bin/
  find /home/vagrant/bin -type f -exec nkf -Lu --overwrite {} \;
  chmod -R +x /home/vagrant/bin/
fi

# IUS repository for installing php
if [ ! -f /etc/yum.repos.d/ius.repo ]; then
  cd ~

  pbk=https://download.fedoraproject.org/pub/epel/$(uname -r | sed 's/.*el//;s/\..*$//;s/[^0-9]//g')/$(uname -i)
  curl -ksL $pbk | sed 's/.*\(\(epel\|ius\)-release.*rpm\).*/\1/p;d' | xargs -i wget --no-check-certificate $pbk/{} ;
  for lc_file in `ls -rt | grep '.rpm$'`; do
    rpm -ivh $lc_file
  done
  /bin/rm -rf *.rpm

  ius=https://dl.iuscommunity.org/pub/ius/stable/CentOS/$(uname -r | sed 's/.*el//;s/\..*$//;s/[^0-9]//g')/$(uname -i)
  curl -ksL $ius | sed 's/.*\(\(epel\|ius\)-release.*rpm\).*/\1/p;d' | xargs -i wget --no-check-certificate $ius/{} ;
  #wget --no-check-certificate http://rpms.famillecollet.com/enterprise/remi-release-$(uname -r | sed 's/.*el//;s/\..*$//;s/[^0-9]//g').rpm

  for lc_file in `ls -rt | grep '.rpm$'`; do
    rpm -Uvh $lc_file
  done
  /bin/rm -rf *.rpm

  cd ${CURRENT_PWD} 
fi

# Install memcache
if [ ! -f /etc/init.d/memcached ]; then
  yum -y install memcached
  chkconfig memcached on
  service memcached start
fi

# Install apache
which httpd > /dev/null
if [ $? -ne 0 ]; then
  yum -y install httpd cronolog

  /bin/cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.default.conf
  mkdir -p /etc/httpd/sites-enabled
  mkdir -p /etc/httpd/sites-available

  if [ -d /vagrant/config/httpd ]; then
    /bin/cp -rf /vagrant/config/httpd/* /etc/httpd/
    cd /etc/httpd/sites-enabled
    ln -s ../sites-available/*.conf
    cd "${CURRENT_PWD}"
  fi
  chkconfig httpd on
  service httpd start
else
  unlink /etc/httpd/sites-enabled/*.conf
  unlink /etc/httpd/sites-available/*.conf

  if [ -d /vagrant/config/httpd/sites-available ]; then
    /bin/cp -rf /vagrant/config/httpd/sites-available/* /etc/httpd/sites-available/
    `cd /etc/httpd/sites-enabled; ln -s ../sites-available/*.conf`
  fi
fi

which php > /dev/null
if [ $? -ne 0 ]; then
  yum -y install php53
  /bin/cp /etc/php.ini /etc/php.default.ini
fi

# Check pear
which pear > /dev/null
if [ $? -ne 0 ]; then
  yum -y install php-pear
  which pear > /dev/null
  if [ $? -ne 0 ]; then
    echo 'Install php-pear failed'
    exit
  fi
fi

# Extension including
mkdir -p /usr/lib/php/lib
if [ -f /vagrant/config/php/browscap.ini ]; then
  /bin/cp -f /vagrant/config/php/browscap.ini /usr/lib/php/lib/browscap.ini
fi

# Zend library
if [ ! -d /usr/lib/php/lib/Zend ]; then
  wget --no-check-certificate https://packages.zendframework.com/releases/ZendFramework-1.11.12/ZendFramework-1.11.12.tar.gz
  tar -xzf ZendFramework-1.11.12.tar.gz
  /bin/cp -r ZendFramework-1.11.12/library/Zend /usr/lib/php/lib/
  /bin/rm -rf ZendFramework-1.11.12*
fi

function php_install_module () {
  while [ ! x$1 = x ]; do
    php -m | grep $1 > /dev/null
    if [ $? -ne 0 ]; then
      yum -y install "php53-${1}"
    fi
    shift
  done
}

php_install_module mbstring gd imap pdo odbc interbase soap xmlrpc
if [ -f /vagrant/config/php/php.ini ]; then
  /bin/cp -f /vagrant/config/php/php.ini /etc/php.ini
fi

# PHP memcache
pear channel-update pear.php.net
pecl channel-update pecl.php.net
if [ ! -f /etc/php.d/memache.ini ]; then
  yum -y install libmemcached
  printf "\n" | pecl install memcache
  pecl list | grep memcache > /dev/null
  if [ $? -eq 0 ]; then
    echo '; Enable memcache extension module' > /etc/php.d/memache.ini
    echo 'extension=memcache.so' >> /etc/php.d/memache.ini
  fi
fi


## Add hosts file
function add_hosts_file () {
  export IFS=$PRI_IFS

  local line=`echo ${1}`

  if [ "x${line}" = "x" ]; then
    return
  fi

  if [ "x${line:0:1}" = 'x#' ]; then
    return
  fi

  local lc_dm=`echo "${line}" | cut -d ' ' -f 2`

  cat /etc/hosts | grep " ${lc_dm}"'$' > /dev/null
  if [ $? -ne 0 ]; then
    echo "${1}" >> /etc/hosts
  else
    echo ${lc_dm}
    echo ${lline}
    sed -i "/${lc_dm}/c"'\'"${line}" /etc/hosts
  fi
  export IFS=$'\n'
}

export IFS=$'\n'

while read line; do
  add_hosts_file "${line}"
done < /vagrant/config/bash/hosts

export IFS=$PRI_IFS

# Xdebug
php -m | grep xdebug > /dev/null
if [ $? -ne 0 ]; then
  pecl install xdebug-2.2.1
fi

if [ -f /vagrant/config/php/xdebug.ini ]; then
  cp -f /vagrant/config/php/xdebug.ini /etc/php.d/xdebug.ini
fi

# Oci8
if [ ! -f /etc/php.d/oci8.ini ]; then
  yum -y install libaio*
  rpm -ivh http://nc.phpdev.ttv/index.php/s/3JfXtsIDp7gsidw/download
  rpm -ivh http://nc.phpdev.ttv/index.php/s/woY7qkjxkhT4NVL/download
  printf "\n" | pecl install oci8-2.0.12
  pecl list | grep oci8 > /dev/null
  if [ $? -eq 0 ]; then
    echo '; Enable oci8 extension module' > /etc/php.d/oci8.ini
    echo 'extension=oci8.so' >> /etc/php.d/oci8.ini
  fi
fi

# Make necessary folders
mkdir -p /data/token/applications/log-error
mkdir -p /data/tmp
mkdir -p /data/cache
mkdir -p /data/logs
chmod 777 /data/tmp /data/cache /data/logs
chown -R apache:apache /data/tmp
chown -R apache:apache /data/cache
chown -R apache:apache /data/logs

# End
service httpd restart
