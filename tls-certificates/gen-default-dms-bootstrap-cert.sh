#!/bin/bash

mkdir -p default-dms-bootstrap
openssl genrsa -out default-dms-bootstrap/bootsrap.key 4096
openssl req -new -x509 -days 365 -key default-dms-bootstrap/bootsrap.key -subj "/CN=default-dms-bootsrap" -out default-dms-bootstrap/bootsrap.crt
