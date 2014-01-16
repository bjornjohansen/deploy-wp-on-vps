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

## Usage
As root, run:
`curl https://raw2.github.com/bjornjohansen/deploy-wp-on-vps/master/deploy.sh | bash`

## Warning
You probably don't know me and probably shouldn't trust me. The script does _a lot_ of things to your system – as root. No harm will be done on purpose, you have my word for it (which you should **not** trust – this is the internet). Inspect the script on your own, and make sure you understand what it does.