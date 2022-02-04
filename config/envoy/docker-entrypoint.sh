#!/bin/sh
set -e

echo "Generating envoy.yaml config file..."
cat /tmpl/envoy.yaml.tmpl | envsubst \$DOMAIN > /etc/envoy.yaml

if [ $DEBUG_MODE == "true" ]
then
    echo "Starting Envoy in debug mode..."
    /usr/local/bin/envoy -c /etc/envoy.yaml -l debug
else
    echo "Starting Envoy..."
    /usr/local/bin/envoy -c /etc/envoy.yaml
fi