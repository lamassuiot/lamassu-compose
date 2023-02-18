#!/bin/bash
set -e

if [ $DEBUG_MODE == "true" ]; then
    echo "Starting Envoy in debug mode..."
    /usr/local/bin/envoy -c /etc/envoy.yaml -l debug
else
    echo "Starting Envoy..."
    /usr/local/bin/envoy -c /etc/envoy.yaml
fi