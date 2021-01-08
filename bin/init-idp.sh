#!/bin/bash

EXPORT_DIR=/ext-mount
TARGET_DIR=/opt/shibboleth-idp-tmp

echo "Please complete the following for your IdP environment:"
$IDP_SRC/bin/install.sh -Didp.target.dir=/opt/shibboleth-idp-tmp -Didp.src.dir=$IDP_SRC install

# find /opt/shibboleth-idp-tmp/ -type d -exec chmod 750 {} \;

#mkdir -p $EXPORT_DIR/
#chmod -R 750 $EXPORT_DIR/

# Copy config to export directory
cp -r $TARGET_DIR/credentials/ $EXPORT_DIR/
cp -r $TARGET_DIR/metadata/ $EXPORT_DIR/
cp -r $TARGET_DIR/conf/ $EXPORT_DIR/
cp -r $TARGET_DIR/views/ $EXPORT_DIR/
cp -r $TARGET_DIR/edit-webapp/ $EXPORT_DIR/


echo "Export complete"
echo "Files that are not customized can be removed from what was exported, the default file in the Docker image will be used instead"
