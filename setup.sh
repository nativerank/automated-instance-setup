#!/usr/bin/env bash

set -xv

curl https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar --output /tmp/wp
chmod +x /tmp/wp
chown daemon:daemon /tmp/wp

FORMAT="--site-url=www.domain.com"
REDIS=1
PAGESPEED=1
DEVSITE_SLUG=$(/tmp/wp option get wp_nr_dev_slug --path="/opt/bitnami/wordpress")
SITE_URL=$(/tmp/wp config get WP_NR_SITEURL --path="/opt/bitnami/wordpress")
PUBLIC_IP=$(/tmp/wp config get PUBLIC_IP --path="/opt/bitnami/wordpress")

if [[ -z "$1"  && -z "$SITE_URL" ]]; then
  printf -- "\n Invalid or no argument supplied \n"
  printf -- "\n CORRECT SYNTAX ---> ${FORMAT} \n"
  exit 64
fi

for i in "$@"; do
  case $i in
  -d=* | --dev-slug=*)
    DEVSITE_SLUG="${i#*=}"
    ;;
  -s=* | --site-url=*)
    SITE_URL="${i#*=}"
    ;;
  --skip-redis | skip-redis)
    REDIS=0
    ;;
  --skip-pagespeed | skip-pagespeed)
    PAGESPEED=0
    ;;
  --default)
    DEFAULT=YES
    ;;
  *)
    # unknown option
    ;;
  esac
done

if [[ -z "$DEVSITE_SLUG" ]]; then
    printf -- "\n Invalid or missing Devsite Slug \n"
    exit 64
fi

if [[ $DEVSITE_SLUG == *.* ]]; then
  printf -- "\n Devsite Slug can not contain a period (.) \n"
  printf -- "\n CORRECT SYNTAX ---> ${FORMAT} \n"
  exit 64
fi

if [[ $DEVSITE_SLUG == */* ]]; then
  printf -- "\n Devsite Slug can not contain a slash (/) \n"
  printf -- "\n CORRECT SYNTAX ---> ${FORMAT} \n"
  exit 64
fi

if [[ $SITE_URL == *http* ]]; then
  printf -- "\n ERROR: Site Url can not contain http \n"
  printf -- "\n CORRECT SYNTAX ---> ${FORMAT} \n"
  exit 64
fi

if [[ $SITE_URL != www* ]]; then
  printf -- "\n ERROR: Wrong Site URL format \n"
  printf -- "\n CORRECT SYNTAX ---> ${FORMAT} \n"
  exit 64
fi

if [[ "${SITE_URL}" == */* ]]; then
  printf -- "\n ERROR: Site Url can not contain a slash (/) \n"
  printf -- "\n CORRECT SYNTAX ---> ${FORMAT} \n"
  exit 64
fi

if [[ "${SITE_URL}" == *. ]]; then
  printf -- "\n ERROR: Site Url can not end with a period (.) \n"
  printf -- "\n CORRECT SYNTAX ---> ${FORMAT} \n"
  exit 64
fi

if [[ "${SITE_URL}" == www.DOMAIN.com ]]; then
  printf -- "\n ERROR: Be sure to replace DOMAIN.com with the domain for this account \n"
  printf -- "\n CORRECT SYNTAX ---> ${FORMAT} \n"
  exit 64
fi




initiate_lighsailScript() {

  #printf -- "\n DEBUG: DEVSITE SLUG ${DEVSITE_SLUG} \n"
  #printf -- "\n DEBUG: SITEURL ${SITE_URL} \n"
  #printf -- "\n DEBUG: PUBLIC_IP ${PUBLIC_IP} \n"

  printf -- "\n Replace PUBLIC IP ${PUBLIC_IP} with production URL ${SITE_URL}....... \n"
  /tmp/wp search-replace "${PUBLIC_IP}" "${SITE_URL}" --skip-plugins=w3-total-cache --all-tables --report-changed-only --path="/opt/bitnami/wordpress"
  /tmp/wp search-replace "nrdevsites.com" "nativerank.dev" --skip-plugins=w3-total-cache --all-tables --report-changed-only --path="/opt/bitnami/wordpress"
  /tmp/wp search-replace "www.nativerank.dev" "nativerank.dev" --skip-plugins=w3-total-cache --all-tables --report-changed-only --path="/opt/bitnami/wordpress"

  printf -- "\n Replacing devsite slug (escaped) with production URL....... \n"
  /tmp/wp search-replace "nativerank.dev\\/${DEVSITE_SLUG}" "${SITE_URL}" --skip-plugins=w3-total-cache --all-tables --report-changed-only --path="/opt/bitnami/wordpress"

  printf -- "\n Replacing devsite slug with production (unescaped) URL....... \n"
  /tmp/wp search-replace "nativerank.dev/${DEVSITE_SLUG}" "${SITE_URL}" --skip-plugins=w3-total-cache --all-tables --report-changed-only --path="/opt/bitnami/wordpress"

  printf -- "\n Running the same replacements on Less, CSS, JS, Handlebars templates, and data.json....... \n"
  ### .LESS ###

  find /opt/bitnami/wordpress/wp-content/themes/yootheme_child/less/src/ -iname "*.less" -exec sed -i "s/nrdevsites.com/nativerank.dev/g" {} +
  find /opt/bitnami/wordpress/wp-content/themes/yootheme_child/less/src/ -iname "*.less" -exec sed -i "s/www.nativerank.dev/nativerank.dev/g" {} +

  find /opt/bitnami/wordpress/wp-content/themes/yootheme_child/less/src/ -iname "*.less" -exec sed -i "s/http:/https:/g" {} +
  find /opt/bitnami/wordpress/wp-content/themes/yootheme_child/less/src/ -iname "*.less" -exec sed -i "s/https:\/\/nativerank.dev/nativerank.dev/g" {} +

  find /opt/bitnami/wordpress/wp-content/themes/yootheme_child/less/src/ -iname "*.less" -exec sed -i "s/nativerank.dev\/${DEVSITE_SLUG}//g" {} +

  ### .CSS ###

  find /opt/bitnami/wordpress/wp-content/themes/yootheme_child/css/ -iname "*.css" -exec sed -i "s/nrdevsites.com/nativerank.dev/g" {} +
  find /opt/bitnami/wordpress/wp-content/themes/yootheme_child/css/ -iname "*.css" -exec sed -i "s/www.nativerank.dev/nativerank.dev/g" {} +

  find /opt/bitnami/wordpress/wp-content/themes/yootheme_child/css/ -iname "*.css" -exec sed -i "s/http:/https:/g" {} +
  find /opt/bitnami/wordpress/wp-content/themes/yootheme_child/css/ -iname "*.css" -exec sed -i "s/https:\/\/nativerank.dev/nativerank.dev/g" {} +

  find /opt/bitnami/wordpress/wp-content/themes/yootheme_child/css/ -iname "*.css" -exec sed -i "s/nativerank.dev\/${DEVSITE_SLUG}//g" {} +

  ### .JS ###

  find /opt/bitnami/wordpress/wp-content/themes/yootheme_child/js/ -iname "*.js" -exec sed -i "s/nrdevsites.com/nativerank.dev/g" {} +
  find /opt/bitnami/wordpress/wp-content/themes/yootheme_child/js/ -iname "*.js" -exec sed -i "s/www.nativerank.dev/nativerank.dev/g" {} +

  find /opt/bitnami/wordpress/wp-content/themes/yootheme_child/js/ -iname "*.js" -exec sed -i "s/http:/https:/g" {} +
  find /opt/bitnami/wordpress/wp-content/themes/yootheme_child/js/ -iname "*.js" -exec sed -i "s/https:\/\/nativerank.dev/nativerank.dev/g" {} +

  find /opt/bitnami/wordpress/wp-content/themes/yootheme_child/js/ -iname "*.js" -exec sed -i "s/nativerank.dev\/${DEVSITE_SLUG}//g" {} +

  ### DATA.JSON ###

  find /opt/bitnami/wordpress/wp-content/themes/yootheme_child/ -iname "data.json" -exec sed -i "s/nativerank.dev\/${DEVSITE_SLUG}//g" {} +

  ### .HBS ###

  find /opt/bitnami/wordpress/wp-content/themes/yootheme_child/templates/ -iname "*.hbs" -exec sed -i "s/nrdevsites.com/nativerank.dev/g" {} +
  find /opt/bitnami/wordpress/wp-content/themes/yootheme_child/templates/ -iname "*.hbs" -exec sed -i "s/www.nativerank.dev/nativerank.dev/g" {} +
  find /opt/bitnami/wordpress/wp-content/themes/yootheme_child/templates/ -iname "*.hbs" -exec sed -i "s/nativerank.dev\/${DEVSITE_SLUG}/${SITE_URL}/g" {} +
  find /opt/bitnami/wordpress/wp-content/themes/yootheme_child/templates/ -iname "*.hbs" -exec sed -i "s/http:\/\/${SITE_URL}/https:\/\/${SITE_URL}/g" {} +

  printf -- "\n Making it secure [http -> https]....... \n"
  /tmp/wp search-replace "http://${SITE_URL}" "https://${SITE_URL}" --skip-plugins=w3-total-cache --all-tables --report-changed-only --path="/opt/bitnami/wordpress"

  printf -- "\n Temporarily disable redis....... \n"
  /tmp/wp redis disable --path="/opt/bitnami/wordpress"

    printf -- "\n Updating Redis Object Cache WP Plugin....... \n"
  /tmp/wp plugin update redis-cache --path="/opt/bitnami/wordpress"

  # REDIS is "1" or "0"; both are non-empty, so test the value, not just that it is set.
  if [[ "$REDIS" == 1 ]]; then
    printf -- "\n Reactivate redis....... \n"
    /tmp/wp redis enable --path="/opt/bitnami/wordpress"
  fi

    printf -- "\n Running wp cache flush....... \n"
  /tmp/wp cache flush --skip-plugins=w3-total-cache --path="/opt/bitnami/wordpress"

  printf -- "\n Setting site URL in WordPress....... \n"
  /tmp/wp option update siteurl "https://${SITE_URL}" --path="/opt/bitnami/wordpress"
  /tmp/wp option update home "https://${SITE_URL}" --path="/opt/bitnami/wordpress"


  /tmp/wp option delete nativerank_seo_wp_last_sync --skip-plugins=w3-total-cache --path="/opt/bitnami/wordpress"
}



printf -- "\n Initiating scripts... \n"

initiate_lighsailScript
wait
printf -- "\n Successfully migrated ${DEVSITE_SLUG} -> ${SITE_URL}. \n"
exit 0

