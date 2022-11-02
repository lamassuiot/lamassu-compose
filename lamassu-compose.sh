#!/bin/bash
LAMASSU_COMPOSE_GITHUB_TAG=v1.1.0
LAMASSU_SIMULATION_TOOLS_GITHUB_TAG=b669c23

BLUE='\033[0;34m'
RED='\033[0;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
NOCOLOR='\033[0m'

install_simulator=0
domain=dev.lamassu.io

while test $# -gt 0; do
  case "$1" in
    -d|--domain)
      export DOMAIN=$2
      shift;;
    --compose-version)
      export LAMASSU_COMPOSE_GITHUB_TAG=$2
      shift;;
    --simulation-version)
      export LAMASSU_SIMULATION_TOOLS_GITHUB_TAG=$2
      shift;;
    -w|--with-simulators)
      install_simulator=1
      shift;;
    --)
      break;;
     *)
       shift;;
    esac
done

if [[ -z "${DOMAIN}" ]]; then
    export DOMAIN=$domain
fi


echo -e "${BLUE}=== Insatlling Lamassu Compose ===${NOCOLOR}"
echo -e "${GREEN}Versions:${NOCOLOR}"
echo "LAMASSU_COMPOSE version:  ${LAMASSU_COMPOSE_GITHUB_TAG}"
echo "SIMULATION_TOOLS version: ${LAMASSU_SIMULATION_TOOLS_GITHUB_TAG}"

echo -e "\n${GREEN}Options:${NOCOLOR}"
echo -e "DOMAIN: $DOMAIN"

echo -e "\n${GREEN}Addons:${NOCOLOR}"
if [ $install_simulator -eq 1 ]; then
echo -e "SIMULATION_TOOLS"
fi

echo -e "${BLUE}==================================${NOCOLOR}"


echo -e "\n${BLUE}1) Dependencies checking${NOCOLOR}"

function is_command_installed(){
    if ! command -v $1 &> /dev/null
    then
		return 1
    else
        return 0
    fi
}

function exit_if_command_not_installed(){
    is_command_installed $1
    if [ $? -eq 0 ]; then
        echo "✅ $1"
    else 
        echo "$1: Not detected. Exiting"
        exit 1
    fi
}

exit_if_command_not_installed docker
exit_if_command_not_installed docker-compose
exit_if_command_not_installed git
exit_if_command_not_installed curl
exit_if_command_not_installed openssl
exit_if_command_not_installed jq
exit_if_command_not_installed dig #used to check if domain is available

docker ps > /dev/null
if [ $? -eq 1 ]; then
    echo "Docker might not be executable by this user. Exiting"
    exit 1
fi

function exit_if_cant_resolve_domain(){
    hostname=$1
    ip=`dig +short $hostname`
    if [ -n "$ip" ]; then
        echo "✅ $1"
    else
        echo -e "${RED}$1: Not resolved. Exiting"
        exit 1
    fi
}

echo -e "\n${BLUE}2) Domain resolution checking${NOCOLOR}"

exit_if_cant_resolve_domain $DOMAIN
exit_if_cant_resolve_domain auth.$DOMAIN
exit_if_cant_resolve_domain vault.$DOMAIN


echo -e "\n3) Cloning Lamassu Compose"
echo "using version $LAMASSU_COMPOSE_GITHUB_TAG"
git clone --branch $LAMASSU_COMPOSE_GITHUB_TAG https://github.com/lamassuiot/lamassu-compose > /dev/null
cd lamassu-compose

export LAMASSU_UI_DOCKER_IMAGE="lamassuiot/lamassu-ui:1.1.0"
export LAMASSU_DMS_ENROLLER_DOCKER_IMAGE="lamassuiot/lamassu-dms-enroller-dev:latest"
export LAMASSU_DEVICE_MANAGER_DOCKER_IMAGE="lamassuiot/lamassu-device-manager-dev:latest"
export LAMASSU_DB_DOCKER_IMAGE="lamassuiot/lamassu-db-dev:latest"
export LAMASSU_CA_DOCKER_IMAGE="lamassuiot/lamassu-ca-dev:latest"
export LAMASSU_CLOUD_PROXY_DOCKER_IMAGE="lamassuiot/lamassu-cloud-proxy-dev:latest"
export LAMASSU_OCSP_DOCKER_IMAGE="lamassuiot/lamassu-ocsp-dev:latest"
export LAMASSU_ALERTS_DOCKER_IMAGE="lamassuiot/lamassu-alerts-dev:latest"
export LAMASSU_GATEWAY_DOCKER_IMAGE="lamassuiot/lamassu-gateway-dev:latest"
export LAMASSU_AUTH_DOCKER_IMAGE="lamassuiot/lamassu-auth-dev:latest"
export LAMASSU_RABBITMQ_DOCKER_IMAGE="lamassuiot/lamassu-rabbitmq-dev:latest"

echo -e "\n4) Generating Databse credentials"

export DB_USER=admin
export DB_PASSWORD=$(cat /proc/sys/kernel/random/uuid | sed 's/[-]//g' | head -c 10; echo;)

echo "DB_USER=$DB_USER"
echo "DB_PASSWORD=$DB_PASSWORD"

#Export .env variables
envsubst < .env | tee .env  > /dev/null

echo -e "\n5) Generating upstream certificates"
cd tls-certificates
bash gen-upstream-certs.sh > /dev/null 2>&1

echo -e "\n6) Generating downstream certificates"
bash gen-downstream-certs.sh > /dev/null 2>&1
cd ..

echo -e "\n7) Generating the docker network"
docker network create lamassu-iot-network -d bridge

echo -e "\n8) Launching Auth server and API-Gateway"
docker-compose up -d auth api-gateway

echo -e "\n9) Provisioning Auth server"
successful_auth_status="false"

while [ $successful_auth_status == "false" ]; do
    auth_status=$(curl -k -s https://auth.$DOMAIN/auth/realms/lamassu)
    if [[ $(echo $auth_status | jq .realm -r) == "lamassu" ]]; then
        successful_auth_status="true"
    else
        sleep 5s
    fi
done

docker-compose exec -T auth /opt/jboss/keycloak/bin/add-user-keycloak.sh -r lamassu -u enroller -p enroller --roles admin > /dev/null 2>&1
docker-compose exec -T auth /opt/jboss/keycloak/bin/add-user-keycloak.sh -r lamassu -u operator -p operator --roles operator > /dev/null 2>&1

successful_auth_reload="false"
expected_auth_reload=$(echo '{"outcome" : "success", "result" : null}' | jq -r)

while [ $successful_auth_reload == "false" ]; do
    reload_status=$(docker-compose exec -T auth /opt/jboss/keycloak/bin/jboss-cli.sh --connect command=:reload --output-json)
    if jq -e . >/dev/null 2>&1 <<<"$reload_status" && [[ "$reload_status" != "" ]]; then #Check if reload_status is json string
        reload_status=$(echo $reload_status | jq -r)
        if [ "$reload_status" == "$expected_auth_reload" ]; then
            successful_auth_reload="true"
        else
            sleep 3s
        fi
    else
        sleep 3s
    fi
done

echo -e "\n10) Launching main services"
docker-compose up -d vault consul-server api-gateway

successful_vault_health="false"
while [ $successful_vault_health == "false" ]; do
    vault_status=$(curl --silent -k https://vault.$DOMAIN/v1/sys/health)
    if jq -e . >/dev/null 2>&1 <<<"$vault_status" && [[ "$vault_status" != "" ]]; then #Check if reload_status is json string
        echo $vault_status
        successful_vault_health="true"
    else
        sleep 5s
    fi
done

echo -e "\n11) Initializing and provisioning vault"

successful_vault_credentials="false"
while [ $successful_vault_credentials == "false" ]; do
    vault_creds=$(docker-compose exec -T vault vault operator init -key-shares=5 -key-threshold=3 -tls-skip-verify -format=json)
    echo $vault_creds
    if jq -e . >/dev/null 2>&1 <<<"$vault_creds" && [[ "$vault_creds" != "" ]]; then #Check if reload_status is json string
        echo $vault_creds > vault-credentials.json
        successful_vault_credentials="true"
    else
        sleep 5s
    fi
done

cat vault-credentials.json | jq .unseal_keys_hex -r > vault-ca-credentials.json

export VAULT_TOKEN=$(cat vault-credentials.json | jq .root_token -r)
export VAULT_ADDR=https://vault.$DOMAIN

curl --request PUT "$VAULT_ADDR/v1/sys/unseal" -k --header 'Content-Type: application/json' --data-raw "{\"key\": \"$(cat vault-credentials.json | jq -r .unseal_keys_hex[0])\" }"
curl --request PUT "$VAULT_ADDR/v1/sys/unseal" -k --header 'Content-Type: application/json' --data-raw "{\"key\": \"$(cat vault-credentials.json | jq -r .unseal_keys_hex[1])\" }"
curl --request PUT "$VAULT_ADDR/v1/sys/unseal" -k --header 'Content-Type: application/json' --data-raw "{\"key\": \"$(cat vault-credentials.json | jq -r .unseal_keys_hex[2])\" }"

sleep 5s

cd config/vault/provision/
curl --silent -k https://vault.$DOMAIN/v1/sys/health -I
bash provisioner.sh
cd ../../../

sleep 5s

export CA_VAULT_ROLE_ID_RESP=$(curl -k --header "X-Vault-Token: ${VAULT_TOKEN}" ${VAULT_ADDR}/v1/auth/approle/role/lamassu-ca-role/role-id)
export CA_VAULT_ROLE_ID=$(echo $CA_VAULT_ROLE_ID_RESP | jq -r .data.role_id)
export CA_VAULT_SECRET_ID_RESP=$(curl -k --header "X-Vault-Token: ${VAULT_TOKEN}" --request POST ${VAULT_ADDR}/v1/auth/approle/role/lamassu-ca-role/secret-id)
export CA_VAULT_SECRET_ID=$(echo $CA_VAULT_SECRET_ID_RESP  | jq -r .data.secret_id)

echo "CA_VAULT_ROLE_ID=${CA_VAULT_ROLE_ID}" >> .env
echo "CA_VAULT_SECRET_ID=${CA_VAULT_SECRET_ID}" >> .env

echo -e "\n12) Launching remainig services"

docker-compose up -d opa-server ui lamassu-dms-enroller lamassu-device-manager rabbitmq
sleep 20s
docker-compose up -d

sleep 5s

echo -e "\n13) Create CAs"

successful_ca_health="false"
export AUTH_ADDR=auth.$DOMAIN
while [ $successful_ca_health == "false" ]; do
    export TOKEN=$(curl -k -s --location --request POST "https://$AUTH_ADDR/auth/realms/lamassu/protocol/openid-connect/token" --header 'Content-Type: application/x-www-form-urlencoded' --data-urlencode 'grant_type=password' --data-urlencode 'client_id=frontend' --data-urlencode 'username=enroller' --data-urlencode 'password=enroller' | jq -r .access_token)
    ca_status=$(curl -k -s --location --request GET "https://$DOMAIN/api/ca/v1/health" --header "Authorization: Bearer ${TOKEN}" --header 'Accept: application/json')
    echo $ca_status
    if [[ $(echo $ca_status | jq .healthy -r) == "true" ]]; then
        successful_ca_health="true"
    else
        sleep 5s
    fi
done

export TOKEN=$(curl -k --location --request POST "https://$AUTH_ADDR/auth/realms/lamassu/protocol/openid-connect/token" --header 'Content-Type: application/x-www-form-urlencoded' --data-urlencode 'grant_type=password' --data-urlencode 'client_id=frontend' --data-urlencode 'username=enroller' --data-urlencode 'password=enroller' | jq -r .access_token)

export CA_ADDR=$DOMAIN/api/ca
export CREATE_CA_RESP=$(curl -k -s --location --request POST "https://$CA_ADDR/v1/pki/LamassuRSA4096" --header "Authorization: Bearer ${TOKEN}" --header 'Content-Type: application/json' --data-raw "{\"ca_ttl\": 262800, \"enroller_ttl\": 175200, \"subject\":{ \"common_name\": \"LamassuRSA4096\",\"country\": \"ES\",\"locality\": \"Arrasate\",\"organization\": \"LKS Next, S. Coop\",\"state\": \"Gipuzkoa\"},\"key_metadata\":{\"bits\": 4096,\"type\": \"RSA\"}}")
echo $CREATE_CA_RESP

if [ $install_simulator -eq 1 ]; then
    echo -e "\n14) Installing simulation tools"
    echo "using version $LAMASSU_SIMULATION_TOOLS_GITHUB_TAG"
    git clone --branch $LAMASSU_SIMULATION_TOOLS_GITHUB_TAG https://github.com/lamassuiot/lamassu-simulation-tools > /dev/null
    cd lamassu-simulation-tools

    export LAMASSU_GATEWAY=https://${DOMAIN}
    envsubst < .env | tee .env  > /dev/null

    docker-compose up -d
fi