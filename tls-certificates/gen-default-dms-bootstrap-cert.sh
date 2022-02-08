#!/bin/bash

mkdir -p default-dms-bootstrap
openssl genrsa -out default-dms-bootstrap/bootstrap.key 4096
chmod 644 default-dms-bootstrap/bootstrap.key
openssl req -new -x509 -days 365 -key default-dms-bootstrap/bootstrap.key -subj "/CN=default-dms-bootsrap" -out default-dms-bootstrap/bootstrap.crt
