#!/bin/bash

#execute to print info in stdout
. /opt/configgen.sh
# generate json file
/opt/configgen.sh > /opt/nodeconfig.json

WEBSOCKIFY_CMD="/opt/websockify/run ${MAX_PORT} :5900"
SOCKET_PROTOCOL=ws
WEB_PROTOCOL=http

# uninstall appium specific
#TODO: redirect stdout/stderr to /dev/null
adb uninstall io.appium.uiautomator2.server.test
adb uninstall io.appium.uiautomator2.server
adb uninstall io.appium.settings
adb uninstall io.appium.unlock

# provide execute permissions to chromedrivers on startup
chmod -R a+x /opt/appium/node_modules/appium-chromedriver/chromedriver/linux

# Note: STF_PROVIDER_... is not a good choice for env variable as STF tries to resolve and provide ... as cmd argument to its service!
if [ -z "${STF_HOST_PROVIDER_PUBLIC}" ]; then
      #STF_HOST_PROVIDER_PUBLIC is empty
      STF_HOST_PROVIDER_PUBLIC=${STF_PUBLIC_HOST}
fi
if [ -z "${STF_HOST_PROVIDER_PRIVATE}" ]; then
      #STF_HOST_PROVIDER_PRIVATE is empty
      STF_HOST_PROVIDER_PRIVATE=${STF_PRIVATE_HOST}
fi


if [ -f /opt/nginx/ssl/ssl.crt ] && [ /opt/nginx/ssl/ssl.key ]; then
    WEBSOCKIFY_CMD="/opt/websockify/run ${MAX_PORT} :5900 --ssl-only --cert /opt/nginx/ssl/ssl.crt --key /opt/nginx/ssl/ssl.key"
    SOCKET_PROTOCOL=wss
    WEB_PROTOCOL=https
fi

# set of ports which must be accessible from client network!
STF_APPIUM_PORT=$((MIN_PORT+3))

ln -s -f /usr/lib/jvm/java-8-openjdk-amd64/bin/java /usr/bin/java
${WEBSOCKIFY_CMD} &
npm link --force node@10
node --version
node /opt/appium/ -p ${PORT} --log-timestamp --session-override --udid ${DEVICEUDID} ${APPIUM_RELAXED_SECURITY} \
           --nodeconfig /opt/nodeconfig.json --automation-name ${AUTOMATION_NAME} --log-level ${APPIUM_LOG_LEVEL} & >&1 & 2>&1
sleep 5
npm link --force node@8
node --version
stf provider --name "${DEVICEUDID}" --device-name "${DEVICENAME}" --min-port=${MIN_PORT} --max-port=${MAX_PORT} \
        --connect-sub tcp://${STF_PRIVATE_HOST}:${STF_TCP_SUB_PORT} --connect-push tcp://${STF_PRIVATE_HOST}:${STF_TCP_PUB_PORT} \
        --group-timeout 3600 --public-ip ${STF_PUBLIC_HOST} --storage-url ${WEB_PROTOCOL}://${STF_PUBLIC_HOST}/ --screen-jpeg-quality 40 \
	--appium-port ${PORT} --stf-appium-port ${STF_APPIUM_PORT} --public-node-ip ${STF_HOST_PROVIDER_PUBLIC} \
        --heartbeat-interval 10000 --vnc-initial-size 600x800 --vnc-port 5900 --no-cleanup --screen-ws-url-pattern "${SOCKET_PROTOCOL}://${STF_PUBLIC_HOST}/d/${STF_HOST_PROVIDER_PRIVATE}/<%= serial %>/<%= publicPort %>/"
