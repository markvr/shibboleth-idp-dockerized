FROM centos:centos8 as temp

ENV jetty_version=9.4.35.v20201120 \
    jetty_hash=d4969e3fe66c3ab213df86e6a468e51e7f7e5a3f \
    idp_version=4.0.1 \
    idp_hash=832f73568c5b74a616332258fd9dc555bb20d7dd9056c18dc0ccf52e9292102a

RUN yum -y -q install wget tar which java-11-openjdk maven git openssl && \
    update-alternatives --set java java-11-openjdk.x86_64

ENV JETTY_HOME=/opt/jetty-home \
    JETTY_BASE=/opt/shib-jetty-base \
    IDP_HOME=/opt/shibboleth-idp \
    IDP_SRC=/opt/shibboleth-idp-src

# Download Jetty, verify the hash, and install
RUN wget -q https://repo.maven.apache.org/maven2/org/eclipse/jetty/jetty-distribution/$jetty_version/jetty-distribution-$jetty_version.tar.gz \
    && echo "$jetty_hash  jetty-distribution-$jetty_version.tar.gz" | sha1sum -c - \
    && tar -zxvf jetty-distribution-$jetty_version.tar.gz -C /opt \
    && ln -s /opt/jetty-distribution-$jetty_version/ /opt/jetty-home \
    && rm -f jetty-distribution-$jetty_version.tar.gz

# Clone the "best practice" Jetty configuration, build with Maven and copy results to $JETTY_BASE
# This is long winded but seems to what the Shibboleth project expect people to do.
# Unfortunately Maven seems to need to download the entirety of Maven central repo, so this step is quite slow.
RUN git clone https://git.shibboleth.net/git/java-idp-jetty-base.git /tmp/java-idp-jetty-base && \
    cd /tmp/java-idp-jetty-base && \
    git checkout 9.4.0 && \
    mvn -B -q package && \
    cp -r target/idp-jetty-base/jetty-base $JETTY_BASE

# Copy over custom config for running in Docker
COPY opt/shib-jetty-base $JETTY_BASE

# Download Shibboleth IdP, verify the hash, and install an example configuration
RUN wget -q https://shibboleth.net/downloads/identity-provider/$idp_version/shibboleth-identity-provider-$idp_version.tar.gz \
    && echo "$idp_hash  shibboleth-identity-provider-$idp_version.tar.gz" | sha256sum -c - \
    && tar -zxvf shibboleth-identity-provider-$idp_version.tar.gz -C /opt \
    && ln -s /opt/shibboleth-identity-provider-$idp_version $IDP_SRC \
    && $IDP_SRC/bin/install.sh \
        -Didp.noprompt=true \
        -Didp.scope=local \
        -Didp.target.dir=$IDP_HOME \
        -Didp.src.dir=$IDP_SRC \
        -Didp.host.name=idp.example.com \
        -Didp.sealer.password=changeme \
        -Didp.keystore.password=changeme \
        -Didp.entityID=idp.example.com \
    && rm shibboleth-identity-provider-$idp_version.tar.gz 

# Create a self-signed browser facing certificate and key for demo/test purposes
RUN openssl req -x509 -newkey rsa:4096 -keyout /tmp/key.pem -out /tmp/cert.pem -days 365 -nodes -subj '/CN=localhost' && \
    openssl pkcs12 -export -out $IDP_HOME/credentials/idp-browser.p12 -inkey /tmp/key.pem -in /tmp/cert.pem --password pass:changeme

# Copy our custom config in
COPY opt/shibboleth-idp $IDP_HOME

# Shell scripts
COPY bin /opt/bin
RUN chmod +x /opt/bin/*

FROM centos:centos8

RUN yum -y update \
    && yum -y -q install which java-11-openjdk \
    && yum -y clean all

ENV PATH=$PATH:/opt/bin \
    IDP_HOME=/opt/shibboleth-idp \
    IDP_SRC=/opt/shibboleth-idp-src \
    JETTY_HOME=/opt/jetty-home \
    JETTY_BASE=/opt/shib-jetty-base \
    JETTY_MAX_HEAP=2048m \
    JETTY_BROWSER_SSL_KEYSTORE_PATH=../shibboleth-idp/credentials/idp-browser.p12 \
    JETTY_BROWSER_SSL_KEYSTORE_PASSWORD=changeme \
    JETTY_BACKCHANNEL_SSL_KEYSTORE_PATH=/opt/shibboleth-idp/credentials/idp-backchannel.p12 \
    JETTY_BACKCHANNEL_SSL_KEYSTORE_PASSWORD=changeme

COPY --from=temp /opt/ /opt/

# RUN chmod +x /opt/jetty-home/bin/jetty.sh

# Opening 4443 (browser TLS), 8443 (mutual auth TLS)
EXPOSE 4443 8443

CMD ["/opt/bin/run-jetty.sh"]
