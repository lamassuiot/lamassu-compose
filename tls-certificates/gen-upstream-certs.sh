#!/bin/bash

mkdir -p upstream
openssl genrsa -out upstream/ca.key 4096
chmod 644 upstream/ca.key
openssl req -new -x509 -days 365 -key upstream/ca.key -subj "/CN=internal-ca" -out upstream/ca.crt

function generate() {
    mkdir -p upstream/$1
    openssl genrsa -out upstream/$1/tls.key 4096
    chmod 644 upstream/$1/tls.key
    openssl req -new -key upstream/$1/tls.key -out upstream/$1/tls.csr -subj "/CN=$1" 
    openssl x509 -req -extfile <(printf "subjectAltName=DNS:$1") -in upstream/$1/tls.csr -days 365 -CA upstream/ca.crt -CAkey upstream/ca.key -CAcreateserial -out upstream/$1/tls.crt
}

generate api-gateway
generate vault
generate consul-server
generate auth
generate ui
generate lamassu-ca
generate lamassu-dms-enroller
generate lamassu-device-manager
generate lamassu-default-dms
generate rabbitmq
generate aws-connector
