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
mkdir lamassu/ocsp_certs
mkdir lamassu/mosquitto_ca
services=(consul-server vault keycloak enrollerscep enroller ca enrollerui manufacturingenroll manufacturing manufacturingui scep scepproxy scepextension device deviceui mosquitto prometheus jaeger elastic)
for s in "${services[@]}"; 
do
    mkdir -p lamassu/"$s"_certs
    openssl genrsa -out lamassu/"$s"_certs/"$s".key 4096
    chmod 640 lamassu/"$s"_certs/"$s".key
    openssl req -new -x509 -key lamassu/"$s"_certs/"$s".key -subj "/C=${C}/ST=${ST}/L=${L}/O=${O}/CN=$s" -addext "subjectAltName = DNS: $s" -out lamassu/"$s"_certs/"$s".crt
done

# Distribute certificates to services
trust_services=(consul-server vault keycloak)
lamassu_services=(enrollerscep enroller ca manufacturingenroll manufacturing device scep scepproxy scepextension ocsp)
for t_s in "${trust_services[@]}";
do
    for l_s in "${lamassu_services[@]}";
    do
        cp lamassu/"$t_s"_certs/"$t_s".crt lamassu/"$l_s"_certs/"$t_s".crt
    done
done

# Create certificate for OCSP signed by Enroller
openssl genrsa -out lamassu/ocsp_certs/ocsp.key 4096
openssl req -new -key lamassu/ocsp_certs/ocsp.key -subj "/C=${C}/ST=${ST}/L=${L}/O=${O}/CN=ocsp" -out lamassu/ocsp_certs/ocsp.csr
openssl x509 -req -in lamassu/ocsp_certs/ocsp.csr -CA lamassu/enroller_certs/enroller.crt -CAkey lamassu/enroller_certs/enroller.key -CAcreateserial -extfile compose-builder/openssl.conf -extensions ocsp -out lamassu/ocsp_certs/ocsp.crt

# Distribute SCEP Proxy and Enroller certificates to Device Manufacturing System
cp lamassu/scepproxy_certs/scepproxy.crt lamassu/manufacturing_certs/
cp lamassu/enroller_certs/enroller.crt lamassu/manufacturing_certs/
cp lamassu/enroller_certs/enroller.crt lamassu/manufacturingenroll_certs/

# Distribute Consul certificate to Prometheus
cp lamassu/consul-server_certs/consul-server.crt lamassu/prometheus_certs/

# Distribute Jaeger certificate to Elasticsearch 
cp lamassu/jaeger_certs/jaeger.crt lamassu/elastic_certs/
cp lamassu/elastic_certs/elastic.crt lamassu/jaeger_certs/

# Distribute Enroller certificates to SCEP Proxy and OCSP Responder
cp lamassu/enroller_certs/enroller.crt lamassu/scepproxy_certs/
cp lamassu/enroller_certs/enroller.crt lamassu/ocsp_certs/

# Distribute SCEP Proxy certificate to SCEP Extension
cp lamassu/scepproxy_certs/scepproxy.crt lamassu/scepextension_certs/

# Distribute MQTT Gateway certificate to Device Virtual
cp lamassu/mosquitto_certs/mosquitto.crt lamassu/device_certs/