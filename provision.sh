#!/bin/bash
# -*- mode: bash -*-
# vi: set ft=bash :

# Provision script to setup a new osTicket Vagrant boxes
# Last updated August 2017
# Author: Aaron clonemeagain@gmail.com
# Repo: https://github.com/clonemeagain/osticket-vagrant

# Variables to configure:
DBNAME=osticket     # This database is created and populated with $DBFILE
DBUSER=root         # This account is created but not used by this script
DBPASSWD=toor       # What to set the root and tdj MySQL passwords to
SYNCDIR=/var/www/html # Where the files are that we are syncing, relative to the vm
DOCROOT=$SYNCDIR/osticket # Where to start serving pages from, on eg: webserv:/home/www/intranet == /vagrant/intranet 
LOGS=$SYNCDIR/logs  # Where to store logs (folder inside sync dir)
LOG=$LOGS/build.log # Where to put the bulk of the output of this script
ENABLE_PHPDOC=NO    # Do we run a phpdoc script? Likely not needed
PHP_MEM_LIMIT=512   # How many megs of RAM before PHP dies? I like it high on my dev boxes, because of xdebug
ENABLE_XDEBUG=YES   # Developers like to debug things.. 

# Provisioning script:                                                                                                                                        
#                                                                                                                                         
#  __/\\\________/\\\__________________________________________________________________________________________/\\\____                   
#   _\/\\\_______\/\\\________________________________________________________________________________________/\\\\\\\__                  
#    _\//\\\______/\\\___________________/\\\\\\\\_________________________________________________/\\\_______/\\\\\\\\\_                 
#     __\//\\\____/\\\____/\\\\\\\\\_____/\\\////\\\__/\\/\\\\\\\___/\\\\\\\\\_____/\\/\\\\\\____/\\\\\\\\\\\_\//\\\\\\\__                
#      ___\//\\\__/\\\____\////////\\\___\//\\\\\\\\\_\/\\\/////\\\_\////////\\\___\/\\\////\\\__\////\\\////___\//\\\\\___               
#       ____\//\\\/\\\_______/\\\\\\\\\\___\///////\\\_\/\\\___\///____/\\\\\\\\\\__\/\\\__\//\\\____\/\\\________\//\\\____              
#        _____\//\\\\\_______/\\\/////\\\___/\\_____\\\_\/\\\__________/\\\/////\\\__\/\\\___\/\\\____\/\\\_/\\_____\///_____             
#         ______\//\\\_______\//\\\\\\\\/\\_\//\\\\\\\\__\/\\\_________\//\\\\\\\\/\\_\/\\\___\/\\\____\//\\\\\_______/\\\____            
#          _______\///_________\////////\//___\////////___\///___________\////////\//__\///____\///______\/////_______\///_____           

echo -e "\n--- Setting up a VM for osTicket Development \n"
echo -e "\n--- Contact clonemeagain@gmail.com for support. \n"
echo -e "\n--- Lastest version should be in the repo! \n"
echo -e "\n--- Uses PHP7 & Ubuntu\n"
echo -e "\n--- New Version August 2017: All SQL files in repo/vagrant directory will be loaded in order!"
echo -e "\n--- Use databasename.sql to create a database with that name, and it will fill it from that file\n"
echo -e "\n\n--- To view the installation log in detail: use 'tail ./logs/build.log'";

# Ensure that we're not interuppted/bothered by packages wanting attention.. we preconfigured them all right?
#export DEBIAN_FRONTEND=noninteractive Apparently this is bad.. so, use apt -qq -y install instead.
APT="apt-get -yq --no-install-suggests --no-install-recommends "


# Start by creating/clearing the logfile
if ! [ -f "$LOG" ];	then touch $LOG; else >$LOG; fi
if ! [ -d "$DOCROOT" ];then	mkdir -p $DOCROOT;fi
date >> $LOG

# Ignore things that aren't critical:
dpkg-reconfigure debconf -f noninteractive -p critical

echo -e "Beginning provision run on $(hostname) running $(cat /etc/issue.net)." >> $LOG

# Get started installing stuff, if you used a proxy, rebuilds are much faster!
echo -e "\n--- Updating package data (Please wait)\n"
apt-get -yq update >> $LOG


############################################################################################################ Apache Setup
# Software: Apache2 for serving web pages, need to be installed before php, so php can configure apache :-)
# Vim: For editing files via "vagrant ssh"
# curl.. fur curlin!
# build-essential, for building code
# python-software-properties.. lets us change things with bash, without complex regex
echo -e "\n--- Installing base software packages, apache2,python,curl etc \n"
$APT install apache2 vim curl build-essential python-software-properties >> $LOG

echo -e "\n--- Enabling Required Apache Modules \n"
a2enmod alias auth_basic authn_file dir env expires headers mime negotiation reqtimeout rewrite setenvif ssl unique_id >> $LOG

echo -e "\n--- Configuring VirtualHost \n" 
VHOST=$(cat <<EOF
<VirtualHost *:80>
    DocumentRoot "${DOCROOT}"
    ServerName "osTicket"
    <Directory "${DOCROOT}">
        AllowOverride All
        Require all granted
    </Directory>
    CustomLog ${LOGS}/access.log combined
    ErrorLog ${LOGS}/error.log
    
    ProxyRequests Off
	ProxyPass /mailcatcher http://localhost:1080
	ProxyPass /assets http://localhost:1080/assets
	ProxyPass /messages ws://localhost:1080/messages
</VirtualHost>
EOF
)
echo "${VHOST}" > /etc/apache2/sites-available/000-default.conf
# see caveat here: https://www.vagrantup.com/docs/synced-folders/virtualbox.html
echo -e "EnableSendfile Off" >> /etc/apache2/apache2.conf 
# Prevent log error about reliably determining server name
echo -e "ServerName osTicket" >> /etc/apache2/apache2.conf
echo -e "127.0.0.1      osticket" >> /etc/hosts
echo -e "\n--- Setting apache log directory to ./logs \n"
# We probably want to be able to view the errors.. because otherwise it's harsh..
if ! [ -d $LOGS ]; then mkdir $LOGS; fi
# Ensure everything can log to this folder:
chmod 0777 $LOGS
# Tell apache to log there by default:
sed -ie "s|/var/log/apache2/|${LOGS}|" /etc/apache2/envvars

############################################################################################################ PHP Setup
echo -e "\n--- Installing PHP as Apache Module & Install PHP Modules \n"
$APT install php php-apcu php-bz2 php-cli php-common php-curl php-gd php-gettext php-igbinary php-imap php-intl php-mbstring php-mcrypt php-mysql php-pear php-gettext php-phpseclib php-redis php-soap php-sqlite3 php-tcpdf php-tidy php-xdebug php-xml php-zip php7.0 php7.0-bz2 libapache2-mod-php >> $LOG

PHP_DIR="/etc/php/7.0/apache2"

if [[ "${ENABLE_XDEBUG}" = "YES" ]]
then
    echo -e "\n--- Enable remote XDebug -- \n"
    # Fetches the host IP (likely 10.0.2.2.. like it is on mine)
    host_ip=$(netstat -rn | awk '/^0\.0\.0\.0/ { print $2}')
    echo "zend_extension=xdebug.so
xdebug.default_enable=1
xdebug.remote_enable=1
xdebug.remote_handler=dbgp
xdebug.remote_host=$host_ip
xdebug.remote_port=9000
xdebug.remote_autostart=0
xdebug.remote_mode=req
xdebug.remote_log=${LOGS}/xdebug.log
xdebug.profiler_enable=0
xdebug.profiler_enable_trigger=1
xdebug.profiler_append=1
xdebug.profiler_output_dir=${LOGS}/profiler
xdebug.extended_info=1" >  $PHP_DIR/conf.d/20-xdebug.ini
fi

PHP_INI="${PHP_DIR}/php.ini"
echo -e "\n--- We definitely need to see the PHP errors, turning them on \n"
sed -ie "s/error_reporting = .*/error_reporting = E_ALL/" $PHP_INI
sed -ie "s/display_errors = .*/display_errors = On/"  $PHP_INI
sed -ie "s/memory_limit = .*/memory_limit = ${PHP_MEM_LIMIT}M/"  $PHP_INI
# Make profiler folder if required
if ! [[ -d "${LOGS}/profiler" ]]
then 
    mkdir -p "${LOGS}/profiler"
    chmod 777 "${LOGS}/profiler"
fi
# Ensure xdebug can write to the xdebug.log file
if ! [[ -f "${LOGS}/xdebug.log" ]]
then
    touch $LOGS/xdebug.log
fi
chmod 666 $LOGS/xdebug.log

echo -e "\n--- Installing mailcatcher from http://mailcatcher.me => http://localhost:8080/mailcatcher \n"
# http://mailcatcher.me/
$APT install -y ruby-dev libsqlite3-dev >> $LOG
gem install mailcatcher >> $LOG
# enable apache proxy modules to configure a reverse proxy to mailcatchers webfrontend
a2enmod proxy proxy_http proxy_wstunnel >> $LOG
 
# replace sendmail path in php.ini with catchmail path
CATCHMAIL="$(which catchmail)"
sed -i "s|;sendmail_path\s=.*|sendmail_path = ${CATCHMAIL} -f www-data@localhost|" $PHP_DIR/php.ini

# Make it start on boot (without having to reprovision)
echo "@reboot root ${CATCHMAIL} --ip=0.0.0.0" >> /etc/crontab
update-rc.d cron defaults
# Start
$CATCHMAIL --ip=0.0.0.0

echo -e "\n--- Restarting Apache to activate PHP configuration. \n"
service apache2 restart >> $LOG

############################################################################################################  MySQL Setup

# MySQL setup for development purposes ONLY
echo -e "\n--- Install MySQL packages \n"

# Preconfigure a few packages..
debconf-set-selections <<< "mysql-server mysql-server/root_password password ${DBPASSWD}"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password ${DBPASSWD}"
debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean true"
debconf-set-selections <<< "phpmyadmin phpmyadmin/app-password-confirm password ${DBPASSWD}"
debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password ${DBPASSWD}"
debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password ${DBPASSWD}"
debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2"

$APT install mysql-server mysql-client phpmyadmin >> $LOG

MYSQL=`which mysql`
if ! [[ -x "${MYSQL}" ]]
	then echo "----> ERR: Unable to run mysql, did it install? ";
else
    # Save the password so root can use it
    echo "
[client]
user=${DBUSER}
password=${DBPASSWD}
" > ~/.my.cnf
    echo -e "\n--- Allowing remote MySQL access (Remove this in Prod!)\n";
    sed -i -e 's/127.0.0.1/0.0.0.0/' /etc/mysql/my.cnf

    cd $DOCROOT
    for sql_file in `ls *.sql | sort`
    do
        db_file_base=$(basename "${sql_file}")
        # Get the database name from before the .sql part of the filename:
        db_name="${db_file_base%.*}"
        SECONDS=0
        echo -e "\n--- Loading database ${db_name} into vm..  (Please wait, this will take a few minutes)"
        mysql -u${DBUSER} -e "CREATE DATABASE ${db_name}" # May not be in the start of the sql file..
        mysql -u${DBUSER} $db_name < $sql_file;
        duration=SECONDS
        echo -e "--- Database ${db_name} has been loaded: Took $(($duration / 60)) minutes and $(($duration % 60)) seconds.\n"
    done
    echo -e "\n--- Setting up our MySQL user with every privilege \n"
    mysql -u${DBUSER} -e "grant all privileges on *.* to '$DBUSER'@'localhost' identified by '$DBPASSWD'" >> $LOG
    mysql -u${DBUSER} -e "FLUSH PRIVILEGES;" >>  $LOG
        
    #Restart mysql to apply change to remote access settings.
    service mysql restart
fi

echo -e "Purging unnecessary packages \n"
$APT autoremove -y >> $LOG

echo -e "Configuring webserver write access to ost-config.php for install\n"
    OSTC="${DOCROOT}/include/ost-config.php"
if ! [[ -f "${OSTC}" ]]
then
    cp $DOCROOT/include/ost-sampleconfig.php $OSTC
    chmod 0666 $OSTC
    echo -e "Configuring osticket settings based on provision script settings\n"
    sed -ie "s/%CONFIG-DBHOST/localhost/" $OSTC
    sed -ie "s/%CONFIG-DBNAME/${DBNAME}/" $OSTC
    sed -ie "s/%CONFIG-DBUSER/${DBUSER}/" $OSTC
    sed -ie "s/%CONFIG-DBPASS/${DBPASSWD}/" $OSTC
    sed -ie "s/%CONFIG-PREFIX/ost/" $OSTC
fi

echo "Ready to rock! - osTicket Development Server is now available on http://localhost:8080\n"


# Some optional extras, they can be useful in other projects, most shouldn't trigger here:
cd $DOCROOT

if [[ -s composer.json ]] ;then
	CURL=`which curl`
	if ! [[ -x "$CURL" ]]
		then echo -e "Unable to install Composer, no curl"
	else
		echo -e "\n--- Installing Composer for PHP package management \n"
		$CURL --silent https://getcomposer.org/installer | php >> $LOG 2>&1
		mv composer.phar /usr/local/bin/composer
	fi
  sudo -u vagrant -H sh -c "composer install" >> $LOG 2>&1
fi

if [[ -s package.json ]] ;then
  sudo -u vagrant -H sh -c "npm install" >> $LOG 2>&1
fi

if [[ -s bower.json ]] ;then
  sudo -u vagrant -H sh -c "bower install -s" >> $LOG 2>&1
fi

if [[ -s gulpfile.js ]] ;then
  sudo -u vagrant -H sh -c "gulp" >> $LOG 2>&1
fi

if [[ -x $DOCROOT/vendor/bin/phpunit ]] ;then
  echo -e "\n--- Creating a symlink for future phpunit use \n"
  ln -fs $DOCROOT/vendor/bin/phpunit /usr/local/bin/phpunit
fi

if [[ "$ENABLE_PHPDOC" = "YES" ]]
then
	echo -e "\n--- Installing PHPDocumentor \n"
	curl --silent http://www.phpdoc.org/phpDocumentor.phar > /usr/local/bin/phpdoc
	chmod a+x /usr/local/bin/phpdoc
fi
