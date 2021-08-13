#!/usr/bin/env bash

# get public ip
PUBLIC_IP="$(curl ipinfo.io/ip)"

cd /opt/bitnami/wp-cli/bin

rm -f wp
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
cp wp-cli.phar wp
chmod +x wp
chown daemon:daemon wp

# chmod 664 /bitnami/wordpress/wp-config.php

# delete siteurl and home url from wp config so they'll only use option values, so our setup script (runs as daemon) can update them
wp config delete WP_SITEURL
wp config delete WP_HOME

if [[ -n "${PUBLIC_IP}" ]]; then
  # save IP to wp config
  wp config set PUBLIC_IP "${PUBLIC_IP}"
  # set siteurl to public ip
  wp option update siteurl "http://${PUBLIC_IP}"
  wp option update home "http://${PUBLIC_IP}"
fi

# set permissions for some plugin installation, etc. later on
chown -R daemon:bitnami /opt/bitnami/wordpress/wp-content/

# install updraftplus
wp plugin install https://updraftplus.com/wp-content/uploads/updraftplus.zip --activate

# ensure WP Rocket can cache the site
wp config set WP_CACHE true --raw --type=constant

# Security headers
sed -i 's/RequestHeader unset Proxy early/RequestHeader unset Proxy early\nHeader always set X-XSS-Protection "1; mode=block"\nHeader always set X-Content-Type-Options nosniff\nHeader always set Strict-Transport-Security "max-age=15768000; includeSubDomains"\n/i' /opt/bitnami/apache2/conf/httpd.conf

# Turn off expose_php in php.ini
sed -i 's/expose_php \?= \?On/expose_php = Off/i' /opt/bitnami/php/etc/php.ini

/opt/bitnami/wordpress/bnconfig --disable_banner 1

# install redis-server
apt-get update
apt-get install redis-server -y

# install fail2ban and wp-fail2ban
# apt-get install fail2ban -y
# sudo -u daemon wp plugin install wp-fail2ban --activate
# cp /opt/bitnami/wordpress/wp-content/plugins/wp-fail2ban/filters.d/wordpress-hard.conf /etc/fail2ban/filter.d/

# printf '\n\n%s\n\n' '[wordpress-hard]' >> /etc/fail2ban/jail.conf
# printf '%s\n' 'enabled = true' 'filter = wordpress-hard' 'logpath = /var/log/auth.log' 'maxretry = 3' 'port = http,https' 'ignoreip= 127.0.0.1/8 50.207.91.158' >> /etc/fail2ban/jail.conf
# sudo service fail2ban restart

wp config set WP_REDIS_CLIENT credis --type=constant

if [[ -z "$1" ]]; then
    printf -- "\n Site URL is required! \n"
    exit 64
fi

if [[ -z "$2" ]]; then
   printf -- "\n Must provide temporary password! \n"
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

USER_CREATION=$(wp user create admin websupport@nativerank.com --role=administrator)

echo "${USER_CREATION}"

wp user update 2 --user_pass="$TEMP_PASSWORD"

if [[ -n "$PASSWORD" ]]; then
  mkdir /tmp/wp_password/
  touch /tmp/wp_password/wp_password.txt
  echo "$PASSWORD" > /tmp/wp_password/wp_password.txt
  chown -R daemon:daemon /tmp/wp_password/
  chmod -R 770 /tmp/wp_password/
fi

printf -- "\n Setting WP_NR_SITEURL in WP Config \n"
wp config set WP_NR_SITEURL "${SITE_URL}"

printf -- "\n Configuring Pagespeed module \n"
sed -i "s/ModPagespeed on/ModPagespeed on\n\nModPagespeedRespectXForwardedProto on\nModPagespeedLoadFromFileMatch \"^https\?:\/\/${SITE_URL}\/\" \"\/opt\/bitnami\/apps\/wordpress\/htdocs\/\"\n\nModPagespeedLoadFromFileRuleMatch Disallow .\*;\n\nModPagespeedLoadFromFileRuleMatch Allow \\\.css\$;\nModPagespeedLoadFromFileRuleMatch Allow \\\.jpe\?g\$;\nModPagespeedLoadFromFileRuleMatch Allow \\\.png\$;\nModPagespeedLoadFromFileRuleMatch Allow \\\.gif\$;\nModPagespeedLoadFromFileRuleMatch Allow \\\.js\$;\n\nModPagespeedDisallow \"\*favicon\*\"\nModPagespeedDisallow \"\*.svg\"\nModPagespeedDisallow \"\*.mp4\"\nModPagespeedDisallow \"\*.txt\"\nModPagespeedDisallow \"\*.xml\"\n\nModPagespeedInPlaceSMaxAgeSec -1\nModPagespeedLazyloadImagesAfterOnload off/g" /opt/bitnami/apache2/conf/pagespeed.conf
sed -i "s/inline_css/inline_css,hint_preload_subresources/g" /opt/bitnami/apache2/conf/pagespeed.conf

# 403 if user is accessing directly
sed -i '1s/^/RewriteEngine On\nRewriteCond %{REMOTE_ADDR} !=50.207.91.158\nRewriteCond %{REMOTE_ADDR} !=3.16.217.226\nRewriteRule \"^\" \"\/\" [R=403,L]\nRewriteEngine Off\nErrorDocument 403 \"403 - You shall not pass.\"\n/' /opt/bitnami/wordpress/conf/httpd-prefix.conf

# bitnami comes with one default vhost. Simply replace the example domain
sed -i -e "s/wordpress.example.com/${SITE_URL}/g" /opt/bitnami/wordpress/conf/httpd-vhosts.conf
sed -i -e "s/www.//i" /opt/bitnami/wordpress/conf/httpd-vhosts.conf
sed -i 's/\/opt\/bitnami\/apps\/wordpress\/conf\/certs\//\/opt\/bitnami\/apache2\/conf\//i' /opt/bitnami/wordpress/conf/httpd-vhosts.conf
echo Include "/opt/bitnami/wordpress/conf/httpd-vhosts.conf" >> /opt/bitnami/apache2/conf/bitnami/bitnami-apps-vhosts.conf

/opt/bitnami/ctlscript.sh restart
