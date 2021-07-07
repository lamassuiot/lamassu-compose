#!/bin/bash
# ==================================================================
#  _                                         
# | |                                        
# | |     __ _ _ __ ___   __ _ ___ ___ _   _ 
# | |    / _` | '_ ` _ \ / _` / __/ __| | | |
# | |___| (_| | | | | | | (_| \__ \__ \ |_| |
# |______\__,_|_| |_| |_|\__,_|___/___/\__,_|
#                                            
#                                            
# ==================================================================
# Create environment and self-signed certificates
mkdir -p lamassu

openssl genrsa -out lamassu/lamassu.key 4096
chmod 640 lamassu/lamassu.key
openssl req -new -x509 -key lamassu/lamassu.key -subj "/C=${C}/ST=${ST}/L=${L}/O=${O}/CN=$DOMAIN" -addext "subjectAltName = DNS:$DOMAIN, DNS:*.$DOMAIN" -out lamassu/lamassu.crt

services=(ca consul-server device-manager elastic enroller jaeger keycloak ocsp prometheus ui vault)
for s in "${services[@]}"; 
do
    mkdir -p lamassu/"$s"_certs
    cp lamassu/lamassu.crt lamassu/"$s"_certs/"$s".crt
    cp lamassu/lamassu.key lamassu/"$s"_certs/"$s".key
done

ca_dependant_services=(device-manager enroller)
for s in "${ca_dependant_services[@]}"; 
do
    mkdir -p lamassu/"$s"_certs
    cp lamassu/lamassu.crt lamassu/"$s"_certs/ca.crt
done

consul_dependant_services=(ca device-manager enroller ocsp prometheus)
for s in "${consul_dependant_services[@]}"; 
do
    mkdir -p lamassu/"$s"_certs
    cp lamassu/lamassu.crt lamassu/"$s"_certs/consul-server.crt
done

elastic_dependant_services=(jaeger)
for s in "${elastic_dependant_services[@]}"; 
do
    mkdir -p lamassu/"$s"_certs
    cp lamassu/lamassu.crt lamassu/"$s"_certs/elastic.crt
done

enroller_dependant_services=(ca ocsp)
for s in "${enroller_dependant_services[@]}"; 
do
    mkdir -p lamassu/"$s"_certs
    cp lamassu/lamassu.crt lamassu/"$s"_certs/enroller.crt
done

jaeger_dependant_services=(elastic)
for s in "${jaeger_dependant_services[@]}"; 
do
    mkdir -p lamassu/"$s"_certs
    cp lamassu/lamassu.crt lamassu/"$s"_certs/jaeger.crt
done

keycloak_dependant_services=(ca device-manager enroller ocsp)
for s in "${keycloak_dependant_services[@]}"; 
do
    mkdir -p lamassu/"$s"_certs
    cp lamassu/lamassu.crt lamassu/"$s"_certs/keycloak.crt
done

vault_dependant_services=(ca ocsp)
for s in "${vault_dependant_services[@]}"; 
do
    mkdir -p lamassu/"$s"_certs
    cp lamassu/lamassu.crt lamassu/"$s"_certs/vault.crt
done
