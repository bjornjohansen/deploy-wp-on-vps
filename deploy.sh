#!/bin/bash

echo

# Make sure correct Ubuntu version is installed
DEP_UBUNTU_VERSION="12.04"
UBUNTU_VERSION=`lsb_release -rs`
if [ "${DEP_UBUNTU_VERSION}" != "${UBUNTU_VERSION}" ]; then
        echo "Deployscript for Ubuntu ${DEP_UBUNTU_VERSION} only. This is ${UBUNTU_VERSION}."
        exit 1
fi

# Make sure we (you) are root
if [ `whoami` != "root" ]; then
        echo "You're not root. Go out and play!"
        exit 1
fi

# Make sure we have a public key in place
ROOT_HOMEDIR=`echo ~root`
AUTH_KEYS_FILE="${ROOT_HOMEDIR}/.ssh/authorized_keys"
if [ ! -s "${AUTH_KEYS_FILE}" ]; then
        echo
        echo "You do not seem to have your public key installed!"
        echo "Without it, you will be locked out of your server."
        echo "Please paste your public key or press CTRL+C to abort: "
        read PUBKEY
        if [ ! -n "$PUBKEY" ]; then
                echo "Now, that was disappointing. Go out and play!"
                exit 1
        fi
        if [ ! -e $(dirname ${AUTH_KEYS_FILE}) ]; then
                mkdir -p  $(dirname ${AUTH_KEYS_FILE})
                chmod 0700 $(dirname ${AUTH_KEYS_FILE})
        fi
        echo "${PUBKEY}" >> $AUTH_KEYS_FILE
        chmod 0600 ${AUTH_KEYS_FILE}
fi

# Fetch the root's auth keys so we can put them in the user's authkeys file
AUTH_KEYS=`cat ${AUTH_KEYS_FILE}`


# Collect info from user

SYSTEM_ADMIN_EMAIL="teknisk@arachno.no"
echo -n "System admin email (root) [$SYSTEM_ADMIN_EMAIL]: "
read SYSTEM_ADMIN_EMAIL_INPUT
if [ -n "$SYSTEM_ADMIN_EMAIL_INPUT" ]; then
        SYSTEM_ADMIN_EMAIL=$SYSTEM_ADMIN_EMAIL_INPUT
fi

USER_NAME=`hostname -s`
echo -n "System username [$USER_NAME]: "
read USER_NAME_INPUT
if [ -n "$USER_NAME_INPUT" ]; then
        USER_NAME=$USER_NAME_INPUT
fi

DB_COLLATION="utf8_danish_ci"
echo -n "Database collation [$DB_COLLATION]: "
read DB_COLLATION_INPUT
if [ -n "$DB_COLLATION_INPUT" ]; then
        DB_COLLATION=$DB_COLLATION_INPUT
fi

WP_LOCALE="nb_NO"
echo -n "WP locale [$WP_LOCALE]: "
read WP_LOCALE_INPUT
if [ -n "$WP_LOCALE_INPUT" ]; then
        WP_LOCALE=$WP_LOCALE_INPUT
fi

WP_USER="leidar"
echo -n "WP admin username [$WP_USER]: "
read WP_USER_INPUT
if [ -n "$WP_USER_INPUT" ]; then
        WP_USER=$WP_USER_INPUT
fi

WP_USER_EMAIL="teknisk@leidar.no"
echo -n "WP admin e-mail address [$WP_USER_EMAIL]: "
read WP_USER_EMAIL_INPUT
if [ -n "$WP_USER_EMAIL_INPUT" ]; then
        WP_USER_EMAIL=$WP_USER_EMAIL_INPUT
fi

WP_HOSTNAME=`hostname -f`
echo -n "WP hostname [$WP_HOSTNAME]: "
read WP_HOSTNAME_INPUT
if [ -n "$WP_HOSTNAME_INPUT" ]; then
        WP_HOSTNAME=$WP_HOSTNAME_INPUT
fi

WP_SITENAME="`hostname -s` web site"
WP_SITENAME=${WP_SITENAME^}
echo -n "WP site name [$WP_SITENAME]: "
read WP_SITENAME_INPUT
if [ -n "$WP_SITENAME_INPUT" ]; then
        WP_SITENAME=$WP_SITENAME_INPUT
fi

WP_SITEDESCRIPTION="Just another ..."
echo -n "WP site description/slogan [$WP_SITEDESCRIPTION]: "
read WP_SITEDESCRIPTION_INPUT
if [ -n "$WP_SITEDESCRIPTION_INPUT" ]; then
        WP_SITEDESCRIPTION=$WP_SITEDESCRIPTION_INPUT
fi


echo

STARTTIME=$(date +%s)

# Fix locale issue
echo "LC_ALL=\"en_US.UTF-8\"" >> /etc/default/locale
export LC_ALL="en_US.UTF-8"
locale-gen nb_NO nb_NO.utf8 nn_NO nn_NO.utf8
locale-gen


# Install the password generator, some apt tools and debconf utils
apt-get update
apt-get -qy install pwgen python-software-properties debconf-utils



# Set passwords, generated usernames and other constants

USER_PASS_LEN=`shuf -i 20-30 -n 1`
USER_PASS=`pwgen -scn $USER_PASS_LEN 1`

DB_ROOT_PASS_LEN=`shuf -i 20-30 -n 1`
DB_ROOT_PASS=`pwgen -scn $DB_ROOT_PASS_LEN 1`

DB_NAME=${USER_NAME}_db
DB_USER=${USER_NAME:0:12}_usr #MySQL user names can be up to 16 characters long.
DB_PASS_LEN=`shuf -i 20-30 -n 1`
DB_PASS=`pwgen -scn $DB_PASS_LEN 1`

WP_PASS_LEN=`shuf -i 20-30 -n 1`
WP_PASS=`pwgen -scn $WP_PASS_LEN 1`

WP_URL="http://${WP_HOSTNAME}"

WP_CRON_CONTROL_SECRET_LEN=`shuf -i 20-30 -n 1`
WP_CRON_CONTROL_SECRET=`pwgen -scn $WP_CRON_CONTROL_SECRET_LEN 1`

PHP_INI_DIR="/etc/php5/fpm/conf.d"

WEBROOT="/home/${USER_NAME}/www"


# Set the time zone
echo "tzdata tzdata/Areas select Europe" | debconf-set-selections
echo "tzdata tzdata/Zones/Europe select Oslo" | debconf-set-selections
TIMEZONE="Europe/Oslo"
echo $TIMEZONE > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

# Cron doesn't detect time zone changes automatically, so restart it
service cron restart



# Add user
useradd -m -s /bin/bash -p $USER_PASS $USER_NAME

# Postfix pre-config
echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
echo "postfix postfix/mailname string `hostname -f`" | debconf-set-selections


# MariaDB repo and pre-config
apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xcbcb082a1bb943db
add-apt-repository 'http://ftp.heanet.ie/mirrors/mariadb/repo/5.5/ubuntu'
echo "mariadb-server-5.5 mysql-server/root_password password $DB_ROOT_PASS" | debconf-set-selections
echo "mariadb-server-5.5 mysql-server/root_password_again password $DB_ROOT_PASS" | debconf-set-selections

# PHP repo
add-apt-repository -y ppa:ondrej/php5

# Nginx repo
curl http://nginx.org/keys/nginx_signing.key | apt-key add -
add-apt-repository 'http://nginx.org/packages/ubuntu/ nginx'

# Varnish repo
# Note: Varnish only maintains repo for TLS. If not running a LTS, it's better to use this PPA: https://launchpad.net/~ondrej/+archive/varnish
curl http://repo.varnish-cache.org/debian/GPG-key.txt | apt-key add -
add-apt-repository 'http://repo.varnish-cache.org/ubuntu/ varnish-3.0'


# install everything
apt-get -q update
apt-get -qy install mariadb-server htop screen vim curl ntp fail2ban ufw nginx php5-cli php5-common php5-fpm php5-cgi php5-curl php5-gd php5-imagick php5-mcrypt php5-mysql libjpeg-progs optipng pngcrush gifsicle imagemagick zip unzip memcached php5-memcache varnish postfix git openjdk-6-jre
apt-get -qy dist-upgrade


# Setup firewall
ufw allow ssh && ufw allow http && ufw allow https && echo "y" | ufw enable

# Disable password auth for SSH. Force key-based auth.
sed -i -e 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config && service ssh restart

# Postfix config
echo "postfix postfix/destinations string localhost" | debconf-set-selections # Not sure if needed. Doesn't work pre-config
sed -i -e "s/^mydestination\s.*$/mydestination = localhost/" /etc/postfix/main.cf

service postfix reload

echo "root: ${SYSTEM_ADMIN_EMAIL}" >> /etc/aliases
newaliases

# automatic security updates
echo "APT::Periodic::Update-Package-Lists \"1\";
APT::Periodic::Unattended-Upgrade \"1\";
" > /etc/apt/apt.conf.d/20auto-upgrades

echo "Unattended-Upgrade::Allowed-Origins {
        \"\${distro_id}:\${distro_codename}-security\";
};

Unattended-Upgrade::Mail \"${SYSTEM_ADMIN_EMAIL}\";
Unattended-Upgrade::MailOnlyOnError \"true\";
Unattended-Upgrade::Remove-Unused-Dependencies \"false\";
Unattended-Upgrade::Automatic-Reboot \"false\";
" > /etc/apt/apt.conf.d/50unattended-upgrades

# Secure MariaDB
TEMP_MARIADB_CONFIG_FILE=".my.cnf.$$"
touch $TEMP_MARIADB_CONFIG_FILE && chmod 0600 $TEMP_MARIADB_CONFIG_FILE
echo "[mysql]
user=root
password=${DB_ROOT_PASS}" >> $TEMP_MARIADB_CONFIG_FILE

mysql --defaults-file=$TEMP_MARIADB_CONFIG_FILE -e "DELETE FROM mysql.user WHERE User=''; DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1'); DROP DATABASE test; DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'; FLUSH PRIVILEGES;"

# MariaDB config
mysql --defaults-file=$TEMP_MARIADB_CONFIG_FILE -e "CREATE DATABASE ${DB_NAME} collate ${DB_COLLATION}; GRANT ALL ON ${DB_NAME}.* TO ${DB_USER}@localhost IDENTIFIED BY '${DB_PASS}';"

rm $TEMP_MARIADB_CONFIG_FILE

# PHP config
echo "post_max_size = 200M
upload_max_filesize = 200M
memory_limit = 256M
cgi.fix_pathinfo = 0
date.timezone = \"Europe/Oslo\"" >> $PHP_INI_DIR/my-php.ini

sed -i -e "s/user = .*/user = ${USER_NAME}/g" /etc/php5/fpm/pool.d/www.conf
sed -i -e "s/group = .*/group = ${USER_NAME}/g" /etc/php5/fpm/pool.d/www.conf

service php5-fpm restart

# Nginx config
rm /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/example_ssl.conf

sed -i -e "s/worker_processes.*/worker_processes `nproc`;/g" /etc/nginx/nginx.conf
sed -i -e "s/keepalive_timeout.*/keepalive_timeout 10;/g" /etc/nginx/nginx.conf

echo "gzip on;" >> /etc/nginx/conf.d/gzip.conf
echo "gzip_disable \"msie6\";" >> /etc/nginx/conf.d/gzip.conf
echo "gzip_vary on;" >> /etc/nginx/conf.d/gzip.conf
echo "gzip_proxied any;" >> /etc/nginx/conf.d/gzip.conf
echo "gzip_comp_level 6;" >> /etc/nginx/conf.d/gzip.conf
echo "gzip_buffers 16 8k;" >> /etc/nginx/conf.d/gzip.conf
echo "gzip_http_version 1.1;" >> /etc/nginx/conf.d/gzip.conf
echo "gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;" >> /etc/nginx/conf.d/gzip.conf

echo "server {
        listen 80;
        listen [::]:80;
        server_name _;

        root ${WEBROOT};

        client_max_body_size 200M;
        fastcgi_send_timeout 1800;
        fastcgi_read_timeout 1800;
        fastcgi_connect_timeout 1800;

        include conf.d/wordpress-conf/restrictions.conf;

        include conf.d/wordpress-conf/wordpress.conf;
}
" > /etc/nginx/conf.d/server.conf;

mkdir /etc/nginx/conf.d/wordpress-conf;

echo "location /favicon.ico {
        log_not_found off;
        access_log off;
}

location /readme.html {
        deny all;
        access_log off;
        log_not_found off;
}

# Deny all attempts to access hidden files such as .htaccess, .htpasswd, .DS_Store (Mac).
location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
}

# Deny access to any files with a .php extension in the uploads directory
location ~* ^/wp-content/uploads/.*.php\$ {
        deny all;
        access_log off;
        log_not_found off;
}

# Deny access to any files with a .php extension in the uploads directory for multisite
location ~* /files/(.*).php\$ {
        deny all;
        access_log off;
        log_not_found off;
}
" > /etc/nginx/conf.d/wordpress-conf/restrictions.conf

echo "index index.html index.php;

location / {
        try_files \$uri \$uri/ /index.php?\$args;
        add_header Vary \"Accept-Encoding\";
}

# Add trailing slash to */wp-admin requests.
rewrite /wp-admin\$ \$scheme://\$host\$uri/ permanent;


rewrite ^/sitemap_index\.xml\$ /index.php?sitemap=1 last;
rewrite ^/([^/]+?)-sitemap([0-9]+)?\.xml\$ /index.php?sitemap=\$1&sitemap_n=\$2 last;


# Directives to send expires headers and turn off 404 error logging.
location ~* \.(js|css|png|jpg|jpeg|gif|ico|woff|otf|ttf|eot|svg)\$ {
        expires max;
        log_not_found off;
        add_header Pragma public;
        add_header Cache-Control \"public\";
        add_header Vary \"Accept-Encoding\";
}

# Pass all .php files onto a php-fpm/php-fcgi server.
location ~ \.php\$ {
        # Zero-day exploit defense.
        # http://forum.nginx.org/read.php?2,88845,page=3
        # Won't work properly (404 error) if the file is not stored on this server, which is entirely possible with php-fpm/php-fcgi.
        # Comment the 'try_files' line out if you set up php-fpm/php-fcgi on another machine.  And then cross your fingers that you won't get hacked.
        try_files \$uri =404;

        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        #NOTE: You should have \"cgi.fix_pathinfo = 0;\" in php.ini

        include fastcgi_params;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param SERVER_NAME \$host;
#       fastcgi_intercept_errors on;
        fastcgi_pass unix:/var/run/php5-fpm.sock;
}
" > /etc/nginx/conf.d/wordpress-conf/wordpress.conf

service nginx reload

# Varnish config


# installation/configuration by system user

su $USER_NAME <<EOSYSUSRCMDS

mkdir -p /home/${USER_NAME}/.ssh
chmod 0700 /home/${USER_NAME}/.ssh
echo "${AUTH_KEYS}" >> /home/${USER_NAME}/.ssh/authorized_keys
chmod 0600 /home/${USER_NAME}/.ssh/authorized_keys

mkdir -p $WEBROOT
cd $WEBROOT

# Install WP-CLI

curl -s https://raw.github.com/wp-cli/wp-cli.github.com/master/installer.sh | bash
echo "export PATH=\"/home/${USER_NAME}/.wp-cli/bin:\$PATH\"" >> ~/.bash_profile
export PATH="/home/${USER_NAME}/.wp-cli/bin:$PATH"

# Install WP
wp core download --locale=${WP_LOCALE}
wp core config --dbname=${DB_NAME} --dbuser=${DB_USER} --dbpass=${DB_PASS} --locale=${WP_LOCALE} --dbcollate=${DB_COLLATION} --extra-php <<PHP
define( 'WP_CRON_CONTROL_SECRET', '${WP_CRON_CONTROL_SECRET}' );
PHP
wp core install --url=${WP_URL} --title=${WP_SITENAME} --admin_user=${WP_USER} --admin_password=${WP_PASS} --admin_email=${WP_USER_EMAIL}
wp option update blogdescription "${WP_SITEDESCRIPTION}"
echo "y" | wp site empty
wp plugin uninstall hello
wp plugin install advanced-custom-fields --activate
wp plugin install aryo-activity-log --activate
wp plugin install bj-lazy-load --activate
wp plugin install enforce-strong-password --activate
wp plugin install ewww-image-optimizer --activate
wp plugin install google-analytics-for-wordpress --activate
wp plugin install google-authenticator --activate
wp plugin install google-authenticator-encourage-user-activation --activate
wp plugin install google-authenticator-per-user-prompt --activate
wp plugin install ninja-forms --activate
wp plugin install relevanssi --activate
wp plugin install regenerate-thumbnails --activate
wp plugin install simple-page-ordering --activate
wp plugin install tablepress --activate
wp plugin install wordpress-seo --activate
wp plugin install wp-cron-control --activate
wp plugin install wp-crontrol --activate
wp plugin install wp-db-driver --activate
wp plugin install wp-pagenavi --activate
wp plugin install https://github.com/kasparsd/minit/archive/master.zip --activate
wp plugin install https://github.com/bjornjohansen/minit-yui/archive/master.zip --activate


# Set up cron
crontab -l | { cat; echo "*/5 * * * * wget -q -O – \"${WP_URL}/wp-cron.php?doing_wp_cron&${WP_CRON_CONTROL_SECRET}\""; } | crontab -

EOSYSUSRCMDS



# Output useful info

echo

echo "URL: $WP_URL"
echo "WEBROOT: $WEBROOT"

echo "USER_NAME: $USER_NAME"
echo "USER_PASS: $USER_PASS"

echo "DB_ROOT_PASS: $DB_ROOT_PASS"

echo "DB_NAME: $DB_NAME"
echo "DB_USER: $DB_USER"
echo "DB_PASS: $DB_PASS"

echo "WP_USER: $WP_USER ($WP_USER_EMAIL)"
echo "WP_PASS: $WP_PASS"

echo

# Output not so useful info
ENDTIME=$(date +%s)
echo "It took $(($ENDTIME - $STARTTIME)) seconds to install and setup everything. Happy WordPressing!"

echo

