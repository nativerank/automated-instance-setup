#!/usr/bin/env bash

set -xv

# get public ip
PUBLIC_IP="$(dig +short myip.opendns.com @resolver1.opendns.com)"

# save to wp config
sudo -u bitnami wp config set PUBLIC_IP "${PUBLIC_IP}"

# delete siteurl and home url from wp config so they'll only use option values, so our setup script (runs as daemon) can update them
sudo -u bitnami wp config delete WP_SITEURL
sudo -u bitnami wp config delete WP_HOME

sudo -u daemon wp option update siteurl "http://${PUBLIC_IP}"
sudo -u daemon wp option update home "http://${PUBLIC_IP}"

# set permissions for some plugin installation, etc. later on
chown -R daemon:bitnami /opt/bitnami/apps/wordpress/htdocs/wp-content/

# install updraftplus
sudo -u daemon wp plugin install https://updraftplus.com/wp-content/uploads/updraftplus.zip --activate

# ensure WP Rocket can cache the site
sudo -u bitnami wp config set WP_CACHE true --raw --type=constant

# pagespeed
sed -i "s/ModPagespeed on/ModPagespeed on\n\nModPagespeedRespectXForwardedProto on\nModPagespeedLoadFromFileMatch \"^https\?:\/\/${SITE_URL}\/\" \"\/opt\/bitnami\/apps\/wordpress\/htdocs\/\"\n\nModPagespeedLoadFromFileRuleMatch Disallow .\*;\n\nModPagespeedLoadFromFileRuleMatch Allow \\\.css\$;\nModPagespeedLoadFromFileRuleMatch Allow \\\.jpe\?g\$;\nModPagespeedLoadFromFileRuleMatch Allow \\\.png\$;\nModPagespeedLoadFromFileRuleMatch Allow \\\.gif\$;\nModPagespeedLoadFromFileRuleMatch Allow \\\.js\$;\n\nModPagespeedDisallow \"\*favicon\*\"\nModPagespeedDisallow \"\*.svg\"\nModPagespeedDisallow \"\*.mp4\"\nModPagespeedDisallow \"\*.txt\"\nModPagespeedDisallow \"\*.xml\"\n\nModPagespeedInPlaceSMaxAgeSec -1\nModPagespeedLazyloadImagesAfterOnload off/g" /opt/bitnami/apache2/conf/pagespeed.conf
sed -i "s/inline_css/inline_css,hint_preload_subresources/g" /opt/bitnami/apache2/conf/pagespeed.conf

# Security headers
sed -i 's/RequestHeader unset Proxy early/RequestHeader unset Proxy early\nHeader always set X-XSS-Protection "1; mode=block"\nHeader always set X-Content-Type-Options nosniff\nHeader always set Strict-Transport-Security "max-age=15768000; includeSubDomains"\n/i' /opt/bitnami/apache2/conf/httpd.conf

# Turn off expose_php in php.ini
ssed -i 's/expose_php \?= \?On/expose_php = Off/i' /opt/bitnami/php/etc/php.ini

/opt/bitnami/apps/wordpress/bnconfig --disable_banner 1

# install redis-server
apt-get update
apt-get install redis-server -y

# install fail2ban and wp-fail2ban
# apt-get install fail2ban -y
# sudo -u daemon wp plugin install wp-fail2ban --activate
# cp /opt/bitnami/apps/wordpress/htdocs/wp-content/plugins/wp-fail2ban/filters.d/wordpress-hard.conf /etc/fail2ban/filter.d/

# printf '\n\n%s\n\n' '[wordpress-hard]' >> /etc/fail2ban/jail.conf
# printf '%s\n' 'enabled = true' 'filter = wordpress-hard' 'logpath = /var/log/auth.log' 'maxretry = 3' 'port = http,https' 'ignoreip= 127.0.0.1/8 50.207.91.158' >> /etc/fail2ban/jail.conf
# sudo service fail2ban restart

sudo -u bitnami wp config set WP_REDIS_CLIENT credis --type=constant

if [[ -z "$1" ]] || [[ -z "$2" ]]; then
  exit 64
fi

for i in "$@"; do
  case $i in
  -s=* | --site-url=*)
    SITE_URL="${i#*=}"
    ;;
  -tp=* | --temp-password=*)
    TEMP_PASSWORD="${i#*=}"
    ;;
  -p=* | --password=*)
    PASSWORD="${i#*=}"
    ;;
  --default)
    DEFAULT=YES
    ;;
  *)
    # unknown option
    ;;
  esac
done

if [[ $SITE_URL == *http* ]]; then
  printf -- "\n Site URL cannot contain protocol \n"
  exit 64
fi

# if [[ $SITE_URL != www* ]]; then
#   exit 64
# fi

if [[ "${SITE_URL}" == */* ]]; then
  printf -- "\n Site URL cannot start with a slash \n"
  exit 64
fi

if [[ "${SITE_URL}" == *. ]]; then
  printf -- "\n Site URL must contain a TLD (top-level domain) \n"
  exit 64
fi

if [[ "${SITE_URL}" == www.DOMAIN.com ]]; then
  printf -- "\n Make sure to insert your Site URL in place of 'www.DOMAIN.com' \n"
  exit 64
fi

sudo -u daemon wp user create admin websupport@nativerank.com --role=administrator
sudo -u daemon wp user update 2 --user_pass="$TEMP_PASSWORD"

if [[ -n "$PASSWORD" ]]; then
  mkdir /tmp/wp_password/
  touch /tmp/wp_password/wp_password.txt 
  echo "$PASSWORD" > /tmp/wp_password/wp_password.txt 
  chown -R daemon:daemon /tmp/wp_password/
  chmod -R 770 /tmp/wp_password/
fi

printf -- "\n Setting WP_NR_SITEURL in WP Config \n"
sudo -u bitnami wp config set WP_NR_SITEURL "${SITE_URL}"

# Copy default self-signed certs so it doesn't print warning in logs
sudo cp /opt/bitnami/apache2/conf/server.crt /opt/bitnami/apps/wordpress/conf/certs/server.crt
sudo cp /opt/bitnami/apache2/conf/server.key /opt/bitnami/apps/wordpress/conf/certs/server.key

# 403 if user is accessing directly
sed -i '1s/^/RewriteEngine On\nRewriteCond %{REMOTE_ADDR} !=50.207.91.158\RewriteCond %{REMOTE_ADDR} !=3.16.217.226\nRewriteRule \"^\" \"\/\" [R=403,L]\nRewriteEngine Off\nErrorDocument 403 \"403 - You shall not pass.\"\n/' /opt/bitnami/apps/wordpress/conf/httpd-prefix.conf

# bitnami comes with one default vhost. Simply replace the example domain 
sed -i -e "s/wordpress.example.com/${SITE_URL}/g" /opt/bitnami/apps/wordpress/conf/httpd-vhosts.conf
sed -i -e "s/www.//i" /opt/bitnami/apps/wordpress/conf/httpd-vhosts.conf
echo Include "/opt/bitnami/apps/wordpress/conf/httpd-vhosts.conf" >> /opt/bitnami/apache2/conf/bitnami/bitnami-apps-vhosts.conf

/opt/bitnami/ctlscript.sh restart
