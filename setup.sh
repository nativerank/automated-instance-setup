#!/usr/bin/env bash

set -xv

FORMAT="--site-url=www.domain.com"
REDIS=1
PAGESPEED=1
DEVSITE_SLUG=$(wp option get wp_nr_dev_slug)
WP_ROCKET_SETTINGS='{"analytics_enabled":"1","cache_mobile":1,"purge_cron_interval":0,"purge_cron_unit":"HOUR_IN_SECONDS","minify_html":1,"minify_google_fonts":1,"remove_query_strings":1,"minify_css":1,"minify_concatenate_css":1,"exclude_css":[],"critical_css":"","minify_js":1,"minify_concatenate_js":1,"exclude_inline_js":["recaptcha"],"exclude_js":[],"defer_all_js":1,"defer_all_js_safe":1,"emoji":1,"manual_preload":1,"sitemap_preload":1,"yoast_xml_sitemap":"1","sitemaps":[],"dns_prefetch":[],"cache_reject_uri":[],"cache_reject_cookies":[],"cache_reject_ua":[],"cache_purge_pages":[],"cache_query_strings":[],"automatic_cleanup_frequency":"","cdn_cnames":[],"cdn_zone":[],"cdn_reject_files":[],"heartbeat_admin_behavior":"reduce_periodicity","heartbeat_editor_behavior":"reduce_periodicity","heartbeat_site_behavior":"reduce_periodicity","google_analytics_cache":"1","cloudflare_email":"info@nativerank.com","cloudflare_zone_id":"","sucury_waf_api_key":"","consumer_key":"9c61671e","consumer_email":"websupport@nativerank.com","secret_key":"d46fe5bc","license":"1584626253","secret_cache_key":"5e7cb30fed140242993260","minify_css_key":"5e7cb336a02a9310104205","minify_js_key":"5e7cb336a02b1548322986","version":"3.5.1","cloudflare_old_settings":"","sitemap_preload_url_crawl":"500000","cache_ssl":1,"do_beta":0,"cache_logged_user":0,"do_caching_mobile_files":0,"embeds":0,"lazyload":0,"lazyload_iframes":0,"lazyload_youtube":0,"async_css":0,"database_revisions":0,"database_auto_drafts":0,"database_trashed_posts":0,"database_spam_comments":0,"database_trashed_comments":0,"database_expired_transients":0,"database_all_transients":0,"database_optimize_tables":0,"schedule_automatic_cleanup":0,"do_cloudflare":0,"cloudflare_devmode":0,"cloudflare_auto_settings":1,"cloudflare_protocol_rewrite":0,"sucury_waf_cache_sync":0,"control_heartbeat":0,"cdn":0,"varnish_auto_purge":0}'
CLOUDFLARE_API_KEY=$(wp option pluck wp_rocket_settings cloudflare_api_key)
USER_ID=$(wp user list | grep 'nativeaccess' | head -c 1)
TEMP_USER_ID=$(wp user list | grep 'admin\b' | head -c 1)
SITE_URL=$(wp config get WP_NR_SITEURL)
PUBLIC_IP=$(wp config get PUBLIC_IP)

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
  skip-redis*)
    REDIS=0
    ;;
  skip-pagespeed*)
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
  ZONE_ID=$(curl -X POST -H "Content-Type: application/json" -d "{\"domain\": \"${SITE_URL}\"}" https://nativerank.dev/cloudflareapi/zone_id)
  
  #printf -- "\n DEBUG: DEVSITE SLUG ${DEVSITE_SLUG} \n"
  #printf -- "\n DEBUG: SITEURL ${SITE_URL} \n"
  #printf -- "\n DEBUG: PUBLIC_IP ${PUBLIC_IP} \n"
  #printf -- "\n DEBUG: CLOUDFLARE API KEY ${CLOUDFLARE_API_KEY} \n"

  printf -- "\n Replace PUBLIC IP ${PUBLIC_IP} with production URL ${SITE_URL}....... \n"
  wp search-replace "${PUBLIC_IP}" "${SITE_URL}" --skip-plugins=w3-total-cache --all-tables --report-changed-only
  wp search-replace "nrdevsites.com" "nativerank.dev" --skip-plugins=w3-total-cache --all-tables --report-changed-only
  wp search-replace "www.nativerank.dev" "nativerank.dev" --skip-plugins=w3-total-cache --all-tables --report-changed-only

  printf -- "\n Replacing devsite slug (escaped) with production URL....... \n"
  wp search-replace "nativerank.dev\\/${DEVSITE_SLUG}" "${SITE_URL}" --skip-plugins=w3-total-cache --all-tables --report-changed-only

  printf -- "\n Replacing devsite slug with production (unescaped) URL....... \n"
  wp search-replace "nativerank.dev/${DEVSITE_SLUG}" "${SITE_URL}" --skip-plugins=w3-total-cache --all-tables --report-changed-only

  printf -- "\n Running the same replacements on Less, CSS, JS, Handlebars templates, and data.json....... \n"

  ### .LESS ###

  find /home/bitnami/apps/wordpress/htdocs/wp-content/themes/yootheme_child/less/src/ -iname "*.less" -exec sed -i "s/nrdevsites.com/nativerank.dev/g" {} +
  find /home/bitnami/apps/wordpress/htdocs/wp-content/themes/yootheme_child/less/src/ -iname "*.less" -exec sed -i "s/www.nativerank.dev/nativerank.dev/g" {} +

  find /home/bitnami/apps/wordpress/htdocs/wp-content/themes/yootheme_child/less/src/ -iname "*.less" -exec sed -i "s/http:/https:/g" {} +
  find /home/bitnami/apps/wordpress/htdocs/wp-content/themes/yootheme_child/less/src/ -iname "*.less" -exec sed -i "s/https:\/\/nativerank.dev/nativerank.dev/g" {} +

  find /home/bitnami/apps/wordpress/htdocs/wp-content/themes/yootheme_child/less/src/ -iname "*.less" -exec sed -i "s/nativerank.dev\/${DEVSITE_SLUG}//g" {} +

  ### .CSS ###

  find /home/bitnami/apps/wordpress/htdocs/wp-content/themes/yootheme_child/css/ -iname "*.css" -exec sed -i "s/nrdevsites.com/nativerank.dev/g" {} +
  find /home/bitnami/apps/wordpress/htdocs/wp-content/themes/yootheme_child/css/ -iname "*.css" -exec sed -i "s/www.nativerank.dev/nativerank.dev/g" {} +

  find /home/bitnami/apps/wordpress/htdocs/wp-content/themes/yootheme_child/css/ -iname "*.css" -exec sed -i "s/http:/https:/g" {} +
  find /home/bitnami/apps/wordpress/htdocs/wp-content/themes/yootheme_child/css/ -iname "*.css" -exec sed -i "s/https:\/\/nativerank.dev/nativerank.dev/g" {} +

  find /home/bitnami/apps/wordpress/htdocs/wp-content/themes/yootheme_child/css/ -iname "*.css" -exec sed -i "s/nativerank.dev\/${DEVSITE_SLUG}//g" {} +
  
  ### .JS ###
  
  find /home/bitnami/apps/wordpress/htdocs/wp-content/themes/yootheme_child/js/ -iname "*.js" -exec sed -i "s/nrdevsites.com/nativerank.dev/g" {} +
  find /home/bitnami/apps/wordpress/htdocs/wp-content/themes/yootheme_child/js/ -iname "*.js" -exec sed -i "s/www.nativerank.dev/nativerank.dev/g" {} +

  find /home/bitnami/apps/wordpress/htdocs/wp-content/themes/yootheme_child/js/ -iname "*.js" -exec sed -i "s/http:/https:/g" {} +
  find /home/bitnami/apps/wordpress/htdocs/wp-content/themes/yootheme_child/js/ -iname "*.js" -exec sed -i "s/https:\/\/nativerank.dev/nativerank.dev/g" {} +

  find /home/bitnami/apps/wordpress/htdocs/wp-content/themes/yootheme_child/js/ -iname "*.js" -exec sed -i "s/nativerank.dev\/${DEVSITE_SLUG}//g" {} +

  ### DATA.JSON ###

  find /home/bitnami/apps/wordpress/htdocs/wp-content/themes/yootheme_child/ -iname "data.json" -exec sed -i "s/nativerank.dev\/${DEVSITE_SLUG}//g" {} +

  ### .HBS ###

  find /home/bitnami/apps/wordpress/htdocs/wp-content/themes/yootheme_child/templates/ -iname "*.hbs" -exec sed -i "s/nrdevsites.com/nativerank.dev/g" {} +
  find /home/bitnami/apps/wordpress/htdocs/wp-content/themes/yootheme_child/templates/ -iname "*.hbs" -exec sed -i "s/www.nativerank.dev/nativerank.dev/g" {} +
  find /home/bitnami/apps/wordpress/htdocs/wp-content/themes/yootheme_child/templates/ -iname "*.hbs" -exec sed -i "s/nativerank.dev\/${DEVSITE_SLUG}/${SITE_URL}/g" {} +
  find /home/bitnami/apps/wordpress/htdocs/wp-content/themes/yootheme_child/templates/ -iname "*.hbs" -exec sed -i "s/http:\/\/${SITE_URL}/https:\/\/${SITE_URL}/g" {} +

  printf -- "\n Making it secure [http -> https]....... \n"
  
  wp search-replace "http://${SITE_URL}" "https://${SITE_URL}" --skip-plugins=w3-total-cache --all-tables --report-changed-only
  
  printf -- "\n Temporarily disable redis....... \n"
  wp redis disable
 
  printf -- "\n Configuring WP Rocket plugin and setting WP_CACHE....... \n"
  wp plugin install https://wp-rocket.me/download/126649/9c61671e/ --activate
  wp plugin deactivate w3-total-cache --uninstall

  wp option update wp_rocket_settings "$WP_ROCKET_SETTINGS" --format=json

  if [[ -n "$CLOUDFLARE_API_KEY" ]]; then
    echo "$CLOUDFLARE_API_KEY" | wp option patch insert wp_rocket_settings cloudflare_api_key
    fi
  if [[ -n "$ZONE_ID" ]]; then
    echo 1 | wp option patch update wp_rocket_settings do_cloudflare
    echo "$ZONE_ID" | wp option patch insert wp_rocket_settings cloudflare_zone_id
    wp plugin deactivate cloudflare --uninstall
  fi

    printf -- "\n Updating Redis Object Cache WP Plugin....... \n"
  wp plugin update redis-cache

  if [[ $REDIS ]]; then
    printf -- "\n Reactivate redis....... \n"
    wp redis enable
  fi

    printf -- "\n Running wp cache flush....... \n"

  wp cache flush --skip-plugins=w3-total-cache
  
  printf -- "\n Setting site URL in WordPress....... \n"

  wp option update siteurl "https://${SITE_URL}"
  wp option update home "https://${SITE_URL}"
 
    
  wp option delete nativerank_seo_wp_last_sync --skip-plugins=w3-total-cache 

}



printf -- "\n Initiating scripts... \n"

initiate_lighsailScript
wait
printf -- "\n Successfully migrated ${DEVSITE_SLUG} -> ${SITE_URL}. \n"
exit 0

