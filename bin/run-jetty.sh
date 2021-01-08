#!/bin/bash

export JETTY_ARGS="\
        jetty.ssl.port=4443 \
        idp.backchannel.keyStorePath=$JETTY_BACKCHANNEL_SSL_KEYSTORE_PATH \
        idp.backchannel.keyStorePassword=$JETTY_BACKCHANNEL_SSL_KEYSTORE_PASSWORD \
        jetty.sslContext.keyStorePath=$JETTY_BROWSER_SSL_KEYSTORE_PATH \
        jetty.sslContext.trustStorePath=$JETTY_BROWSER_SSL_KEYSTORE_PATH \
        jetty.sslContext.keyStorePassword=$JETTY_BACKCHANNEL_SSL_KEYSTORE_PASSWORD \
        jetty.sslContext.trustStorePassword=$JETTY_BACKCHANNEL_SSL_KEYSTORE_PASSWORD \
        jetty.sslContext.keyManagerPassword=$JETTY_BACKCHANNEL_SSL_KEYSTORE_PASSWORD"
        
export _JAVA_OPTIONS="-Didp.war.path=$IDP_HOME/war/idp.war -Xmx$JETTY_MAX_HEAP"

exec /opt/jetty-home/bin/jetty.sh run