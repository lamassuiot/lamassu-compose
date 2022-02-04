#!/bin/bash

mkdir -p downstream
openssl genrsa -out downstream/tls.key 4096
openssl req -new -x509 -days 365 -key downstream/tls.key -subj "/CN=$DOMAIN" -addext "subjectAltName = DNS:$DOMAIN, DNS:*.$DOMAIN"  -out downstream/tls.crt