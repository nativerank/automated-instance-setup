#!/usr/bin/env bash

set -xv

if [[ -z "$1" ]]; then
  exit 64
fi

for i in "$@"; do
  case $i in
  -s=* | --site-url=*)
    SITE_URL="${i#*=}"
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
  exit 64
fi

if [[ $SITE_URL != www* ]]; then
  exit 64
fi

if [[ "${SITE_URL}" == */* ]]; then
  exit 64
fi

if [[ "${SITE_URL}" == *. ]]; then
  exit 64
fi

if [[ "${SITE_URL}" == www.DOMAIN.com ]]; then
  exit 64
fi

PUBLIC_IP="$(dig +short myip.opendns.com @resolver1.opendns.com)"

sudo -u bitnami wp config delete WP_SITEURL
sudo -u bitnami wp config delete WP_HOME

sudo -u daemon wp option update siteurl "http://${PUBLIC_IP}"
sudo -u daemon wp option update home "http://${PUBLIC_IP}"

sudo -u bitnami wp config set WP_NR_SITEURL "${SITE_URL}"

sudo -u daemon wp plugin install https://updraftplus.com/wp-content/uploads/updraftplus.zip --activate

sudo -u daemon wp user create admin websupport@nativerank.com --role=administrator
sudo -u daemon wp user update 2 --user_pass=shellmanager1055

sudo -u bitnami wp config set WP_CACHE true --raw --type=constant
sudo -u bitnami wp config set WP_ROCKET_CF_API_KEY_HIDDEN true --raw --type=constant


sed -i "s/ModPagespeed on/ModPagespeed on\n\nModPagespeedRespectXForwardedProto on\nModPagespeedLoadFromFileMatch \"^https\?:\/\/${SITE_URL}\/\" \"\/opt\/bitnami\/apps\/wordpress\/htdocs\/\"\n\nModPagespeedLoadFromFileRuleMatch Disallow .\*;\n\nModPagespeedLoadFromFileRuleMatch Allow \\\.css\$;\nModPagespeedLoadFromFileRuleMatch Allow \\\.jpe\?g\$;\nModPagespeedLoadFromFileRuleMatch Allow \\\.png\$;\nModPagespeedLoadFromFileRuleMatch Allow \\\.gif\$;\nModPagespeedLoadFromFileRuleMatch Allow \\\.js\$;\n\nModPagespeedDisallow \"\*favicon\*\"\nModPagespeedDisallow \"\*.svg\"\nModPagespeedDisallow \"\*.mp4\"\nModPagespeedDisallow \"\*.txt\"\nModPagespeedDisallow \"\*.xml\"\n\nModPagespeedInPlaceSMaxAgeSec -1\nModPagespeedLazyloadImagesAfterOnload off/g" /opt/bitnami/apache2/conf/pagespeed.conf
sed -i "s/inline_css/inline_css,hint_preload_subresources/g" /opt/bitnami/apache2/conf/pagespeed.conf

/opt/bitnami/apps/wordpress/bnconfig --disable_banner 1

apt-get install redis-server -y

/opt/bitnami/ctlscript.sh restart apache
