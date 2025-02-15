# Dockerised Shibboleth Identity Provider v4

## Overview

This repository has been forked from [Unicon](https://github.com/Unicon/shibboleth-idp-dockerized) as that project has died on Shibboleth IdP v3 which is now end-of-life.

This fork attempts to maintain backwards compatibility with the Unicon image, to make upgrading to v4 as easy as possible.  

See the end of this file for v3 to v4 upgrade instructions.

## Creating a Shibboleth IdP Configuration

Assuming that you do not already have one, create your initial IdP configuration by run with:

    mkdir -p $(pwd)/opt/shibboleth-idp
    docker run -it -v $(pwd)/opt/shibboleth-idp:/ext-mount --rm <image> init-idp.sh

This runs the Shibboleth installer in a temporary container and will prompt for your details.  It then exports the new configuration to the local (Docker Host) file system. After the process completes, the temporary Docker container is deleted as it is no longer needed.

The files in the `/opt/shibboleth-idp/` directory are a complete export of the IdP configuration with your installation values.  Any files that don't have customisations, or are specific to you can be removed, and the default files from the base image will be used.

These files form the basis for you to build your own Shibboleth image.


## Using the Image

You can use this image as a base image for one's own IdP deployment. Assuming that you have a layout with your configuration, credentials, and war customizations (see above). The directory structure could look like:

    [basedir]
    |-- Dockerfile
    |-- opt/shibboleth-idp/
    |   |-- conf/
    |   |   |-- idp.properties
    |   |   |-- ...
    |   |-- credentials/
    |   |   |-- idp-backchannel.p12
    |   |   |-- idp-browser.p12
    |   |   |-- idp-encryption.crt
    |   |   |-- idp-encryption.key
    |   |   |-- idp-signing.crt
    |   |   |-- idp-signing.key
    |   |   |-- sealer.jks
    |   |   |-- sealer.kver
    |   |-- metadata/
    |   |   |-- idp-metadata.xml
    |   |   |-- [sp metadatafiles]
    |   |-- edit-webapp/
    |   |   |-- images/
    |   |   |   |-- dummylogo-mobile.png
    |   |   |   |-- dummylogo.png

Next, create a Dockerfile similar to this example:

    FROM ghcr.io/markvr/shibboleth-idp-dockerized:latest

    ADD opt/ /opt/
    RUN $IDP_HOME/bin/build.sh

And build with:

    docker build --tag="<your_org>/shibboleth-idp:<version>" .

This will build an image overlayed with your custom files.

You can attempt to run your customized image with:

    docker run -d --name="shib-local-test" <org_id>/shibboleth-idp:<version>

But this will likely fail to start unless you choose the default password of `changeme` for the backchannel password.  See below for supplying these passwords.

## Browser Certificate

This image expects to find the TLS certificate and key for browser based communication in `/opt/shibboleth-idp/credentials/idp-browser.p12`. A self-signed certificate has been generated automatically, but this isn't suitable for a production deployment.  If you are not running the IdP behind a load balancer which offloads the SSL then this certificate needs to be replaced with a suitable one from a Certificate Authority.

## Exporting and running from external configuration

Shibboleth has a LOT of configuration and it can be difficult to develop and debug configuration having to build it into an image first each time.

To simplify this, you can export a complete installation of Jetty and Shibboleth to your host system, and then mount and run this within a container.

Export:

    mkdir opt-export
    docker run -v $(pwd)/opt-export:/ext-mount <image> export.sh

Then to run from this config:

    docker run -v $(pwd)/opt-export:/opt <image>

You can then easily edit and run using this full configuration, before transferring any changes to your custom image.

## Run-time Parameters

Start the IdP will take several parameters. The following parameters can be specified when `run`ning a new IdP container:

### Port Mappings

The image exposes two ports. `4443` is the for standard browser-based TLS communication. `8443` is the backchannel TLS communication port. These ports will need to be mapped to the Docker host so that communication can occur.

* `-P`: Used to indicate that the Docker Service should map all exposed container ports to ephemeral host ports. Use `docker ps` to see the mappings.
* `-p <host>:<container>`: Explicitly maps the host ports to the container's exposed ports. This parameters can be used multiple times to map multiple sets of ports. `-p 443:4443` would make the IdP accessible on `https://<docker_host_ip>/idp/`.

### Environmental variables

The container will use environmental variables to control IdP functionality at runtime. Currently there are 3 such variables that can be set from the `docker run` command:

* `-e JETTY_BROWSER_SSL_KEYSTORE_PASSWORD=...`: The password for the browser TLS p12 key store (`/opt/shibboleth-idp/credentials/idp-browser.p12`). Defaults to `changeme`.
* `-e JETTY_BACKCHANNEL_SSL_KEYSTORE_PASSWORD=...`: The password for the SAML1 backchannel key store (`/opt/shibboleth-idp/credentials/idp-backchannel.p12`). Defaults to `changeme`.
* `-e JETTY_MAX_HEAP=...`: Specifies the maximum heap sized used by Jetty's child process to run the IdP application. Defaults to `2048m`

## Logging

Shibboleth generates the following logs:

- `process` - General startup and informational logs.
- `audit` - Structured logs, with one row for every login
- `access` - HTTP traffic logs from Jetty

By default this image outputs all these logs to the console which is all we can do by default.  You probably want to keep the `process` log going to the console, but direct the `audit` and `process` logs elsewhere, either to a central syslog server, or to a directory mounted into the container.

This repo contains copies of the the [default shibboleth logback file](opt/shibboleth-idp/conf/logback.xml.default) and [default jetty access logback file](opt/shib-jetty-base/logback-access.xml.default) which you can use as a reference or replace the customised files with to restore the original logging.  You should then mount the log location into the container as:

    docker run -v /some/where/local:/opt/shibboleth-idp/logs <org_id>/shibboleth-idp:<version>

## Externalizing Secrets and Credentials

Some adopters will not want to include their secrets (key files and passwords) in their customized images. This image has been enhanced to faciliate externalizing those and connecting them in at runtime.

To do this, you will *NOT* want to include the `credentials` directory in your image. Put that directory on the Docker host. When starting the container specify `-v <Host_credentials_directory>:/opt/shibboleth-idp/credentials`. This will mount the local credentials directory into the image.

To extract out passwords, you'll want to modify the `conf/idp.properties` file, by moving sensitive entries out of the file and into a file named `idp-secrets.properties`. Save the `idp-secrets.properties` and `ldap.properties` files onto the docker host into their own directory. Also, change the `conf/idp.properties`'s `idp.additionalProperties` setting to look something like:

    # Load any additional property resources from a comma-delimited list
    idp.additionalProperties= /ext-conf/idp-secrets.properties, /ext-conf/ldap.properties, /conf/saml-nameid.properties, /conf/services.properties

> Note the **/ext-conf/** changes/additions in the property.

This tells the IdP to look into the `/opt/shibboleth-idp/ext-conf/` directory for the `idp-secrets.properties` and `ldap.properties` files. To mount the ext-conf directory, add `-v <Host_ext-config_directory>:/opt/shibboleth-idp/ext-conf` to the start-up parameters.

## Upgrading from v3

Read the [upstream documentation](https://wiki.shibboleth.net/confluence/display/IDP4/Upgrading) first, which contains important information.

The Shibboleth documentation contains warnings that you must not attempt to just run a v4 IdP using v3 config, but must run the installer on the v3 config in an upgrade mode to modify it suitable for v4.

This is slightly tricky to using Docker, but the basic process is:

### Export a complete set of config from your v3 image to the Docker host

    mkdir -p $(pwd)/v3-export
    docker run -v $(pwd)/v3-export:/ext-mount <your v3 image> sh -c "cp -r /opt/shibboleth-idp/* /ext-mount/"

### Mount this into this v4 image and run the upgrade on it

    docker run -v $(pwd)/v3-export:/opt/shibboleth-idp \
      ghcr.io/markvr/shibboleth-idp-dockerized:latest \
      /opt/shibboleth-idp-src/bin/install.sh

This will prompt for the source and target locations - accept the defaults - and then it should detect a v3 to v4 upgrade.

### Build a v4 image with the upgraded config

Similar to the instructions above under "Using the image", move or copy relevant folders from this upgraded config to `opt/shibboleth-idp` in your source repo, and edit your Dockerfile to add this into your image.

You only need the following folders:

- `conf`
- `credentials`
- `edit-webapp`
- `metadata`
- `views`

The remaining folders contain system or binary files that are in the upstream image.
