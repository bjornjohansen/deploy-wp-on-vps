# deploy-wp-on-vps

Deploy-script for setting up WordPress on a clean, fresh Ubuntu VPS.

**Note:** Works on Ubuntu 12.04 only (for now). [See issue #5](https://github.com/bjornjohansen/deploy-wp-on-vps/issues/5)

## Installs and configures
* Latest Nginx from official Nginx repo
* Latest PHP (v5.5 ATM) from PPA
* Varnish from official Varnish repo (No config yet, [see issue #4](https://github.com/bjornjohansen/deploy-wp-on-vps/issues/4))
* MariaDB instead of MySQL
* Postfix for handling outgoing (and system) email
* Installs and configures WordPress with some default should-use plugins

## Security features
* Auto-generates secure passwords
* Key-based SSH logins only
* Auto-configures firewall to allow for HTTP, HTTPS and SSH only
* «Hardens» MariaDB similar to the mysql_secure_installation script

