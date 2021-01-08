#!/bin/bash

EXPORT_DIR=/ext-mount

# Exports the entire /opt directory to $EXPORT_DIR
# Usage (from host): docker run -v $(pwd)/export:/ext-mount <image> export.sh


cp -r /opt/* /$EXPORT_DIR

echo "Export complete"