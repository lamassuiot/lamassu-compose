<a href="https://www.lamassu.io/">
    <img src="logo.png" alt="Lamassu logo" title="Lamassu" align="right" height="80" />
</a>

Lamassu Compose
===================
[![License: MPL 2.0](https://img.shields.io/badge/License-MPL%202.0-blue.svg)](http://www.mozilla.org/MPL/2.0/index.txt)

This repository contains the Docker compose files for deploying the [Lamassu](https://www.lamassu.io) services in Docker.

## Usage
To launch Lamassu follow the next steps:
1. Clone the repository and get into the directory: `git clone https://github.com/lamassuiot/lamassu-compose && cd lamassu-compose`.
2. Install the `jq` tool. It will be used later: https://stedolan.github.io/jq/download/ 
3. Change the next secret environment variables in `.env` file. **If not changed, it will use admin/admin**:

```
KEYCLOAK_DB_USER=<KEYCLOAK_DB_USER> //Keycloak database user.
KEYCLOAK_DB_PASSWORD=<KEYCLOAK_DB_PASSWORD> //Keycloak database user password.
KEYCLOAK_USER=<KEYCLOAK_USER> //Keycloak admin user.
KEYCLOAK_PASSWORD=<KEYCLOAK_PASSWORD> //Keycloak admin password.

ENROLLER_POSTGRESUSER=<ENROLLER_POSTGRESUSER> //Enroller database user.
ENROLLER_POSTGRESPASSWORD=<ENROLLER_POSTGRESPASSWORD> //Enroller database user password.

DEVICES_POSTGRESUSER=<DEVICES_POSTGRESUSER> //Device Manager database user.
DEVICES_POSTGRESPASSWORD=<DEVICES_POSTGRESPASSWORD> //Device Manager database password.

ELASTIC_USERNAME=<ELASTIC_USERNAME> //Elasticsearch username.
ELASTIC_PASSWORD=<ELASTIC_PASSWORD> //Elasticseach user password.
```

4. All the services in Lamassu are secured with TLS. For testing and development purposes self signed certificates can be used. These certificates can be automatically created running the `compose-builder/gen-self-signed-certs.sh` script. First provide the next environment variables used by the script:
```
export C=ES
export ST=Guipuzcoa
export L=Arrasate
export O=Lamassu IoT
export DOMAIN=dev.lamassu.io
```

After defining the env variables, generarte the self signed certificate:

```
./compose-builder/gen-self-signed-certs.sh
```

5. Unless you have a DNS server that is able to resolve the IP of your domain to yourhost, it is recommended adding a new entry to the `/etc/hosts` file. **Replace `dev.lamassu.io` with your domain (The same as the exported DOMAIN env variable).**  
```
127.0.0.1   dev.lamassu.io
127.0.0.1   vault.dev.lamassu.io
127.0.0.1   consul-server.dev.lamassu.io
127.0.0.1   keycloak.dev.lamassu.io
```

6. In order tu run Lamassus's docker-compose, some adjustments are required. The communication between the different containers will be done trough TLS using the certificates created earlier, thus, the communication between container must use the `DOMAIN` i.e. dev.lamassu.io. **Replace all domain ocurrences of dev.lamassu.io to your domian from both `docker-compose.yml` and `.env` files**:

```
sed -i 's/dev\.lamassu\.io/'$DOMAIN'/g' .env
sed -i 's/dev\.lamassu\.io/'$DOMAIN'/g' docker-compose.yml
```
 
7. Provision and configure Vault secret engine:
    1. Run Vault: 
    ```
    docker-compose up -d vault
    ``` 
    2. Initalize vault: This process generates vault's unseal keys as well as the root token:
    ```
    docker-compose exec vault vault operator init -key-shares=3 -key-threshold=2 -tls-skip-verify -format=json > vault-credentials.json
    ```

    3. Unseal Vault using the keys obtained with the previous command:
    ```
    curl --request PUT "$VAULT_ADDR/v1/sys/unseal" -k --header 'Content-Type: application/json' --data-raw "{\"key\": \"$(cat vault-credentials.json | jq -r .unseal_keys_hex[0])\" }"

    curl --request PUT "$VAULT_ADDR/v1/sys/unseal" -k --header 'Content-Type: application/json' --data-raw "{\"key\": \"$(cat vault-credentials.json | jq -r .unseal_keys_hex[1])\" }"
    ```
    
    4. Vault must be provisioned with some resources (authentication methods, policies and secret engines). That can be achieved by running the `ca-provision.sh` script. First export the following variables:

    **Note: Use the absolute path for the VAULT_CA_FILE env var file path**
    ```
    export VAULT_CA_FILE=$(pwd)/lamassu/vault_certs/vault.crt
    export VAULT_TOKEN=$(cat vault-credentials.json | jq .root_token -r)
    export VAULT_ADDR=https://$DOMAIN:8200
    ```

    After defining the env variables, provision vault:

    ```
    cd compose-builder
    ./ca-provision.sh
    ```

    5. Vault will be provisioned with 4 Root CAs, 3 Special CAS (Lamassu-Lamassu-DMS) AppRole authentication method and one role and policy for each service or container that needs to exchange data with it. 
    
    6. The Device Manager has an embedded EST server. Such service protects its endpoints by only allowing REST calls presenting a peer TLS certificate issued by the (DMS) Enroller. The (DMS) Enroller CA cert must be mounted by the EST Server. To obtain the certificate run the following commands:

    ```
    cat intermediate-DMS.crt > ../lamassu/device-manager_certs/dms-ca.crt
    cat CA_cert.crt >> ../lamassu/device-manager_certs/dms-ca.crt
    ```

    Change the context to the upper directory
    ```
    cd ..
    ```

    7. Get RoleID and SecretID for each service and set those values in the empty fields of the `.env` file.
    ```
    export CA_VAULTROLEID=$(curl --cacert $VAULT_CA_FILE --header "X-Vault-Token: ${VAULT_TOKEN}" ${VAULT_ADDR}/v1/auth/approle/role/Enroller-CA-role/role-id | jq -r .data.role_id )

    export CA_VAULTSECRETID=$(curl --cacert $VAULT_CA_FILE --header "X-Vault-Token: ${VAULT_TOKEN}" --request POST ${VAULT_ADDR}/v1/auth/approle/role/Enroller-CA-role/secret-id | jq -r .data.secret_id)

    # Set RoleID and SecretID in .env file
    sed -i 's/ROLE_ID_TO_BE_REPLACED/'$CA_VAULTROLEID'/g' .env
    sed -i 's/SECRET_ID_TO_BE_REPLACED/'$CA_VAULTSECRETID'/g' .env
    ```
    
8. Configure Keycloak:
    1. Run Keycloak: 
    ```
    docker-compose up -d keycloak
    ```
    2. Keycloak image is configured with a Realm, a client and two different roles: admin and operator.

    3. Create a user with admin role to perform Enroller administrator tasks. (The command below creates a user named **enroller** with **enroller** as its password):
    ```
    docker-compose exec keycloak /opt/jboss/keycloak/bin/add-user-keycloak.sh -r lamassu -u enroller -p enroller --roles admin
    ```
    4. Create a user with operator role to perform Device Manufacturing System tasks. This Device Manufacturing System must associate its CSR with this user matching the CN attribute and the username.(The command below creates a user named **operator** with **operator** as its password):
    ```
    docker-compose exec keycloak /opt/jboss/keycloak/bin/add-user-keycloak.sh -r lamassu -u operator -p operator --roles admin
    ```

    5. Reload keyclok server
    ```
    docker-compose exec keycloak /opt/jboss/keycloak/bin/jboss-cli.sh --connect command=:reload
    ```
    
9. Start the remaining services:
```
docker-compose up -d
```

10. Configure a new DMS Instance
    1. First, authenticate against Keycloak:
    ```
     export TOKEN=$(curl -k --location --request POST "https://$DOMAIN:8443/auth/realms/lamassu/protocol/openid-connect/token" --header 'Content-Type: application/x-www-form-urlencoded' --data-urlencode 'grant_type=password' --data-urlencode 'client_id=admin-cli' --data-urlencode 'username=enroller' --data-urlencode 'password=enroller' |jq -r .access_token)
    ```
    2. Then, register a new DMS named Lamassu-Defaul-DMS:   
    ```    
    export DMS_REGISTER_RESPONSE=$(curl -k --location --request POST "https://$DOMAIN:8085/v1/csrs/Lamassu-Defaul-DMS/form" --header "Authorization: Bearer ${TOKEN}" --header 'Content-Type: application/json' --data-raw '{"common_name": "Lamassu-Defaul-DMS","country": "","key_bits": 3072,"key_type": "rsa","locality": "","organization": "","organization_unit": "","state": ""}')
    
    echo $DMS_REGISTER_RESPONSE | jq -r .priv_key | sed 's/\\n/\n/g' > lamassu-default-dms.key
    export DMS_ID=$(echo $DMS_REGISTER_RESPONSE | jq -r .csr.id)
    ```
    3. Lamassu UI only allows provisioning devices belonging to the default DMS. Set the DMS ID generated earlier
    ```
    sed -i 's/REPLACE_WITH_DEFAULT_DMS_ID/'$DMS_ID'/g' .env
    ``` 

    4. Enroll the new DMS
    ```
    curl -k --location --request PUT "https://$DOMAIN:8085/v1/csrs/$DMS_ID" --header "Authorization: Bearer $TOKEN" --header 'Content-Type: application/json' --data-raw '{"status": "APPROVED"}'
    ```
    5. Get issued DMS Cert
    ```
    curl -k --location --request GET "https://$DOMAIN:8085/v1/csrs/$DMS_ID/crt" --header "Authorization: Bearer $TOKEN" > lamassu-default-dms.crt 
    ```
    6. The DMS requires the following keys and certicates:
    
    ```
    cp lamassu/lamassu.crt lamassu-client/device-manager.crt
    cp lamassu/lamassu.crt lamassu-client/https.crt
    cp lamassu/lamassu.key lamassu-client/https.key
    ```
    
    ```
    cp lamassu-default-dms.crt lamassu-client/enrolled-dms.crt
    cp lamassu-default-dms.key lamassu-client/enrolled-dms.key
    ```
    7. Reboot once again all services:
    ```
    docker-compose down
    ```
    After shutting down all services run the command:
    ```
    docker-compose up -d
    ```
    
    8. And finally, start the DMS "server":
    ```
    docker-compose up -d
    ```
    The server has the following endpoint:
    `dev.lamassu.io:5000/dms-issue/<DEVICE_ID>/<CA_NAME>` This endpoint enrolls a registered device
        
    Once enrolled, the device certificate can be obtained using the following endpoint exposed by the `DEVICE Manager` service:
    ```
    curl -k --location --request GET "https://$DOMAIN:8089/v1/devices/<DEVICE_ID>/cert" --header "Authorization: Bearer $TOKEN" 
    ```
    
    
