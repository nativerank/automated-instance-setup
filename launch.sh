#!/usr/bin/env bash

revertWPConfigPermissions() {
    chmod 644 /bitnami/wordpress/wp-config.php
}

chmod 664 /bitnami/wordpress/wp-config.php

# get public ip
PUBLIC_IP="$(curl ipinfo.io/ip)"

# delete siteurl and home url from wp config so they'll only use option values, so our setup script (runs as daemon) can update them
/opt/bitnami/wp-cli/bin/wp config delete WP_SITEURL
/opt/bitnami/wp-cli/bin/wp config delete WP_HOME

if [[ -n "${PUBLIC_IP}" ]]; then
  # save IP to wp config
  /opt/bitnami/wp-cli/bin/wp config set PUBLIC_IP "${PUBLIC_IP}"
  # set siteurl to public ip
  /opt/bitnami/wp-cli/bin/wp option update siteurl "http://${PUBLIC_IP}"
  /opt/bitnami/wp-cli/bin/wp option update home "http://${PUBLIC_IP}"
fi

# set permissions for some plugin installation, etc. later on
chown -R daemon:bitnami /opt/bitnami/wordpress/wp-content/

# install updraftplus
/opt/bitnami/wp-cli/bin/wp plugin install https://updraftplus.com/wp-content/uploads/updraftplus.zip --activate

# ensure WP Rocket can cache the site
/opt/bitnami/wp-cli/bin/wp config set WP_CACHE true --raw --type=constant

# Security headers
sed -i 's/RequestHeader unset Proxy early/RequestHeader unset Proxy early\nHeader always set X-XSS-Protection "1; mode=block"\nHeader always set X-Content-Type-Options nosniff\nHeader always set Strict-Transport-Security "max-age=15768000; includeSubDomains"\n/i' /opt/bitnami/apache2/conf/httpd.conf

# Turn off expose_php in php.ini
sed -i 's/expose_php \?= \?On/expose_php = Off/i' /opt/bitnami/php/etc/php.ini

/opt/bitnami/wordpress/bnconfig --disable_banner 1

# install redis-server
apt-get update
apt-get install redis-server -y

/opt/bitnami/wp-cli/bin/wp config set WP_REDIS_CLIENT credis --type=constant

if [[ -z "$1" ]]; then
    printf -- "\n Site URL is required! \n"
    revertWPConfigPermissions
    wait

    exit 64
fi

if [[ -z "$2" ]]; then
   printf -- "\n Must provide temporary password! \n"
   revertWPConfigPermissions
   wait

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
  revertWPConfigPermissions
  wait

  exit 64
fi

if [[ "${SITE_URL}" == */* ]]; then
  printf -- "\n Site URL cannot start with a slash \n"
  revertWPConfigPermissions
  wait

  exit 64
fi

if [[ "${SITE_URL}" == *. ]]; then
  printf -- "\n Site URL must contain a TLD (top-level domain) \n"
  revertWPConfigPermissions
  wait

  exit 64
fi

if [[ "${SITE_URL}" == www.DOMAIN.com ]]; then
  printf -- "\n Make sure to insert your Site URL in place of 'www.DOMAIN.com' \n"
  revertWPConfigPermissions
  wait

  exit 64
fi

USER_CREATION=$(/opt/bitnami/wp-cli/bin/wp user create admin websupport@nativerank.com --role=administrator)

echo "${USER_CREATION}"

/opt/bitnami/wp-cli/bin/wp user update 2 --user_pass="$TEMP_PASSWORD"

if [[ -n "$PASSWORD" ]]; then
  mkdir /tmp/wp_password/
  touch /tmp/wp_password/wp_password.txt
  echo "$PASSWORD" > /tmp/wp_password/wp_password.txt
  chown -R daemon:daemon /tmp/wp_password/
  chmod -R 770 /tmp/wp_password/
fi

printf -- "\n Setting WP_NR_SITEURL in WP Config \n"
/opt/bitnami/wp-cli/bin/wp config set WP_NR_SITEURL "${SITE_URL}"

printf -- "\n Disabling Pagespeed module \n"
sed -i "s/Include conf\/pagespeed/#Include conf\/pagespeed/g" /opt/bitnami/apache2/conf/httpd.conf

# configure pagespeed just in case we enable it later (conflicts with WP Rocket https://docs.wp-rocket.me/article/1376-mod-pagespeed)
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


# enable Varnish
[ -f /opt/bitnami/scripts/varnish/start.sh.disabled ] && sudo mv /opt/bitnami/scripts/varnish/start.sh.disabled /opt/bitnami/scripts/varnish/start.sh
sudo mv /etc/monit/conf.d/varnish.conf.disabled /etc/monit/conf.d/varnish.conf
sudo gonit reload

sudo cp /opt/bitnami/varnish/etc/varnish/default.vcl /opt/bitnami/varnish/etc/varnish/default.vcl.backup






revertWPConfigPermissions
wait
printf -- "\n Setup Lightsail instance for ${SITE_URL} \n"
exit 0
