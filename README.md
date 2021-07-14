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

4. All the services in Lamassu are secured with TLS. For testing and development purposes self signed certificates can be used. These certificates can be automatically created running the `compose-builder/gen-self-signed-certs.sh` script and providing the next environment variables:
```
export C=ES
export ST=Guipuzcoa
export L=Arrasate
export O=Lamassu IoT
export DOMAIN=lamassu.dev
```

5. Unless you have a DNS server that is able to resolve the IP of your domain to yourhost, it is recommended adding a new entry to the `/etc/hosts` file. **Replace `lamassu.dev` with your domain (The same as the exported DOMAIN env variable).**  
```
127.0.0.1   lamassu.dev
127.0.0.1   vault.lamassu.dev
127.0.0.1   consul-server.lamassu.dev
127.0.0.1   keycloak.lamassu.dev
```

6. In order tu run Lamassus's docker-compose, some adjustments are required. The communication between the different containers will be done trough TLS using the certificates created earlier, thus, the communication between container must use the `DOMAIN` i.e. lamassu.dev. **Replace all domain ocurrences of lamassu.dev to your domian from both `docker-compose.yml` and `.env` files**:

```
sed -i 's/lamassu\.dev/mydomain.dev/g' .env
sed -i 's/lamassu\.dev/mydomain.dev/g' docker-compose.yml
```
 
7. Provision and configure Vault secret engine:
    1. Run Vault: 
    ```
    docker-compose up -d vault
    ``` 
    2. Follow the Vault UI steps in `VAULT_ADDR` to create and get the unseal keys and root token.
    3. Unseal Vault from the UI in `VAULT_ADDR` and automatically provision it with needed authentication methods, policies and secret engines, running the `ca-provision.sh` script and providing the next environment variables:
    **Note: Use the absolute path for the VAULT_CA_FILE env var file path **
    ```
    export VAULT_CA_FILE=/lamassu/vault_certs/vault.crt
    export VAULT_TOKEN=<VAULT_ROOT_TOKEN>
    export VAULT_ADDR=https://lamassu.dev:8200
    ```
    4. Vault will be provisioned with 4 Root CAs, 3 Special CAS (Lamassu-Lamassu-DMS) AppRole authentication method and one role and policy for each service or container that needs to exchange data with it. 
    5. The Device Manager has an embedded EST server. Such service protects its endpoints by only allowing REST calls presenting a peer TLS certificate issued by the (DMS) Enroller. The (DMS) Enroller CA cert must be mounted by the EST Server. To obtain the certificate run the following commands:
    ```
    cat intermediate-DMS.crt > ../lamassu/device-manager_certs/dms-ca.crt
    cat CA_cert.crt >> ../lamassu/device-manager_certs/dms-ca.crt
    ```
    6. Get RoleID and SecretID for each service and set those values in the empty fields of the `.env` file.
    ```
    # Obtain CA Wrapper RoleID and SecretID
    curl --cacert $VAULT_CA_FILE --header "X-Vault-Token: ${VAULT_TOKEN}" ${VAULT_ADDR}/v1/auth/approle/role/Enroller-CA-role/role-id
    curl --cacert $VAULT_CA_FILE --header "X-Vault-Token: ${VAULT_TOKEN}" --request POST ${VAULT_ADDR}/v1/auth/approle/role/Enroller-CA-role/secret-id 

    # Set RoleID and SecretID in .env file
    CA_VAULTROLEID=<CA_VAULTROLEID>
    CA_VAULTSECRETID=<CA_VAULTSECRETID>
    ```
    
8. Configure Keycloak:
    1. Run All the services: 
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
    
9. Reboot all services:
```
docker-compose down
```
After shutting down all services run the command:
```
docker-compose up -d
```
9. Configure a new DMS Instance
    1. First, authenticate against Keycloak:
    ```
     export TOKEN=$(curl -k --location --request POST 'https://lamassu.dev:8443/auth/realms/lamassu/protocol/openid-connect/token' --header 'Content-Type: application/x-www-form-urlencoded' --data-urlencode 'grant_type=password' --data-urlencode 'client_id=admin-cli' --data-urlencode 'username=enroller' --data-urlencode 'password=enroller' |jq -r .access_token)
    ```
    2. Then, register a new DMS named Lamassu-Defaul-DMS:   
    ```    
    export DMS_REGISTER_RESPONSE=$(curl -k --location --request POST 'https://lamassu.dev:8085/v1/csrs/Lamassu-Defaul-DMS/form' --header "Authorization: Bearer ${TOKEN}" --header 'Content-Type: application/json' --data-raw '{"common_name": "Lamassu-Defaul-DMS","country": "","key_bits": 3072,"key_type": "rsa","locality": "","organization": "","organization_unit": "","state": ""})
    
    echo $DMS_REGISTER_RESPONSE | jq -r .priv_key | sed 's/\\n/\n/g' > lamassu-default-dms.key'
    export DMS_ID=$(echo $DMS_REGISTER_RESPONSE | jq -r .csr.id)

    ```
    3. Enroll the new DMS
    ```
    curl -k --location --request PUT "https://lamassu.dev:8085/v1/csrs/$DMS_ID" --header "Authorization: Bearer $TOKEN" --header 'Content-Type: application/json' --data-raw '{"status": "APPROVED"}'
    ```
    4. Get issued DMS Cert
    ```
    curl -k --location --request GET "https://lamassu.dev:8085/v1/csrs/$DMS_ID/crt" --header "Authorization: Bearer $TOKEN"     
    ```
