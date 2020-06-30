#!/usr/bin/env bash

wp config set WP_SITEURL "https://${SITE_URL}"
wp config set WP_HOME "https://${SITE_URL}"

wp config set WP_CACHE true --raw --type=constant
wp config set WP_ROCKET_CF_API_KEY_HIDDEN true --raw --type=constant

find /opt/bitnami/apache2/conf/ -name "httpd.conf" -exec sed -i "s/#LoadModule cgid_module modules\/mod_cgid.so/LoadModule cgid_module modules\/mod_cgid.so/g" {} +
find /opt/bitnami/apache2/conf/ -name "httpd.conf" -exec sed -i 's/<Directory "\/opt\/bitnami\/apache2\/cgi-bin">/<Directory "\/opt\/bitnami\/apache2\/cgi-bin">\nAddHandler cgi-script .cgi .pl\nOptions +ExecCGI\n/g' {} +

curl https://raw.githubusercontent.com/nativerank/cgi-instance-setup/master/setup.cgi --output /opt/bitnami/apache2/cgi-bin/setup.cgi

sed -i "s/ModPagespeed on/ModPagespeed on\n\nModPagespeedRespectXForwardedProto on\nModPagespeedLoadFromFileMatch \"^https\?:\/\/${SITE_URL}\/\" \"\/opt\/bitnami\/apps\/wordpress\/htdocs\/\"\n\nModPagespeedLoadFromFileRuleMatch Disallow .\*;\n\nModPagespeedLoadFromFileRuleMatch Allow \\\.css\$;\nModPagespeedLoadFromFileRuleMatch Allow \\\.jpe\?g\$;\nModPagespeedLoadFromFileRuleMatch Allow \\\.png\$;\nModPagespeedLoadFromFileRuleMatch Allow \\\.gif\$;\nModPagespeedLoadFromFileRuleMatch Allow \\\.js\$;\n\nModPagespeedDisallow \"\*favicon\*\"\nModPagespeedDisallow \"\*.svg\"\nModPagespeedDisallow \"\*.mp4\"\nModPagespeedDisallow \"\*.txt\"\nModPagespeedDisallow \"\*.xml\"\n\nModPagespeedInPlaceSMaxAgeSec -1\nModPagespeedLazyloadImagesAfterOnload off/g" /opt/bitnami/apache2/conf/pagespeed.conf
sed -i "s/inline_css/inline_css,hint_preload_subresources/g" /opt/bitnami/apache2/conf/pagespeed.conf

/opt/bitnami/apps/wordpress/bnconfig --disable_banner 1

apt-get install redis-server -y

/opt/bitnami/ctlscript.sh restart apache