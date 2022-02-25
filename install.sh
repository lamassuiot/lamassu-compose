#!/bin/bash

echo "Insatlling Lamassu"

#Export .env variables
export $(grep -v '^#' .env | xargs)

echo "1) Generating upstream certificates"
cd tls-certificates
bash gen-upstream-certs.sh > /dev/null 2>&1

echo "2) Generating downstream certificates"
bash gen-downstream-certs.sh > /dev/null 2>&1
cd ..

echo "3) Launching Auth server"
docker-compose up -d auth

echo "4) Provisioning Auth server"
docker-compose exec auth /opt/jboss/keycloak/bin/add-user-keycloak.sh -r lamassu -u enroller -p enroller --roles admin > /dev/null 2>&1
docker-compose exec auth /opt/jboss/keycloak/bin/add-user-keycloak.sh -r lamassu -u operator -p operator --roles operator > /dev/null 2>&1

successful_auth_reload="false"
expected_auth_reload=$(echo '{"outcome" : "success", "result" : null}' | jq -r)

while [ $successful_auth_reload == "false" ]; do

    reload_status=$(docker-compose exec auth /opt/jboss/keycloak/bin/jboss-cli.sh --connect command=:reload --output-json)
    if jq -e . >/dev/null 2>&1 <<<"$reload_status"; then #Check if reload_status is json string
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

echo "5) Launching main services"
docker-compose up -d vault consul-server api-gateway

successful_vault_health="false"
while [ $successful_vault_health == "false" ]; do
    vault_status=$(curl --silent -k https://vault.$DOMAIN/v1/sys/health)
    if jq -e . >/dev/null 2>&1 <<<"$vault_status"; then #Check if reload_status is json string
        echo $vault_status
        successful_vault_health="true"
    else 
        sleep 5s
    fi
done

echo "6) Initializing and provisioning vault"

successful_vault_credentials="false"
while [ $successful_vault_credentials == "false" ]; do
    vault_status=$(docker-compose exec vault vault operator init -key-shares=5 -key-threshold=3 -tls-skip-verify -format=json)
    echo $vault_status
    if jq -e . >/dev/null 2>&1 <<<"$vault_status"; then #Check if reload_status is json string
        echo $vault_status > vault-credentials.json
        successful_vault_credentials="true"
    else 
        sleep 5s
    fi
done

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

export CA_VAULT_ROLEID_RESP=$(curl -k --header "X-Vault-Token: ${VAULT_TOKEN}" ${VAULT_ADDR}/v1/auth/approle/role/lamassu-ca-role/role-id)
export CA_VAULT_ROLEID=$(echo $CA_VAULT_ROLEID_RESP | jq -r .data.role_id)
export CA_VAULT_SECRETID_RESP=$(curl -k --header "X-Vault-Token: ${VAULT_TOKEN}" --request POST ${VAULT_ADDR}/v1/auth/approle/role/lamassu-ca-role/secret-id)
export CA_VAULT_SECRETID=$(echo $CA_VAULT_SECRETID_RESP  | jq -r .data.secret_id)

sed -i 's/<LAMASSU_CA_VAULT_ROLE_ID>/'$CA_VAULT_ROLEID'/g' docker-compose.yml
sed -i 's/<LAMASSU_CA_VAULT_SECRET_ID>/'$CA_VAULT_SECRETID'/g' docker-compose.yml

echo "7) Launching remainig services"

mkdir -p lamassu-default-dms/devices-crypto-material
mkdir -p lamassu-default-dms/config
touch lamassu-default-dms/config/dms.key
touch lamassu-default-dms/config/dms.crt

docker-compose up -d opa-server ui lamassu-dms-enroller lamassu-device-manager rabbitmq
sleep 20s 
docker-compose up -d lamassu-ca
sleep 5s

echo "8) Provisioning default DMS"

export AUTH_ADDR=auth.$DOMAIN
export TOKEN=$(curl -k --location --request POST "https://$AUTH_ADDR/auth/realms/lamassu/protocol/openid-connect/token" --header 'Content-Type: application/x-www-form-urlencoded' --data-urlencode 'grant_type=password' --data-urlencode 'client_id=frontend' --data-urlencode 'username=enroller' --data-urlencode 'password=enroller' |jq -r .access_token)
export ENROLL_ADDR=$DOMAIN/api/dmsenroller
export DMS_REGISTER_RESPONSE=$(curl -k --location --request POST "https://$ENROLL_ADDR/v1/Lamassu-Default-DMS/form" --header "Authorization: Bearer ${TOKEN}" --header 'Content-Type: application/json' --data-raw "{\"url\":\"https://${DOMAIN}:5000\", \" subject\":{ \"common_name\": \"Lamassu-Default-DMS\",\"country\": \"\",\"locality\": \"\",\"organization\": \"\",\"organization_unit\": \"\",\"state\": \"\"},\"key_metadata\":{\"bits\": 3072,\"type\": \"rsa\"}}")
echo $DMS_REGISTER_RESPONSE | jq -r .priv_key | sed 's/\\n/\n/g' | sed -Ez '$ s/\n+$//' | base64 -d > lamassu-default-dms/config/dms.key
export DMS_ID=$(echo $DMS_REGISTER_RESPONSE | jq -r .dms.id)
curl -k --location --request PUT "https://$ENROLL_ADDR/v1/$DMS_ID" --header "Authorization: Bearer $TOKEN" --header 'Content-Type: application/json' --data-raw '{"status": "APPROVED"}'
curl -k --location --request GET "https://$ENROLL_ADDR/v1/$DMS_ID/crt" --header "Authorization: Bearer $TOKEN" | base64 -d > lamassu-default-dms/config/dms.crt

docker-compose up -d dms-default