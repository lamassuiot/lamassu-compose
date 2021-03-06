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
2. Fill the next empty secret environment variables in `.env` file:
```
KEYCLOAK_DB_USER=<KEYCLOAK_DB_USER> //Keycloak database user.
KEYCLOAK_DB_PASSWORD=<KEYCLOAK_DB_PASSWORD> //Keycloak database user password.
KEYCLOAK_USER=<KEYCLOAK_USER> //Keycloak admin user.
KEYCLOAK_PASSWORD=<KEYCLOAK_PASSWORD> //Keycloak admin password.

ENROLLER_POSTGRESUSER=<ENROLLER_POSTGRESUSER> //Enroller database user.
ENROLLER_POSTGRESPASSWORD=<ENROLLER_POSTGRESPASSWORD> //Enroller database user password.

SCEP_POSTGRESUSER=<SCEP_POSTGRESUSER> //SCEP database user.
SCEP_POSTGRESPASSWORD=<SCEP_POSTGRESPASSWORD> //SCEP database user password.

ELASTIC_USERNAME=<ELASTIC_USERNAME> //Elasticsearch username.
ELASTIC_PASSWORD=<ELASTIC_PASSWORD> //Elasticseach user password.
```
3. All the services in Lamassu are secured with TLS. For testing and development purposes self signed certificates can be used. These certificates can be automatically created running the `compose-builder/gen-self-signed-certs.sh` script and providing the next environment variables:
    ```
    C=ES //Country code.
    ST=Guipuzcoa //State.
    L=Arrasate //Locality.
    O=Lamassu IoT //Organization.
    ```
4. Provision and configure Vault secret engine:
    1. Run Vault: `docker-compose up -d vault`. 
    2. Follow the Vault UI steps in `VAULT_ADDR` to create and get the unseal keys and root token.
    3. Unseal Vault from the UI in `VAULT_ADDR` and automatically provision it with needed authentication methods, policies and secret engines, running the `compose-builder/ca-provision.sh` script and providing the next environment variables:
    ```
    VAULT_CA_FILE=lamassu/vaul_certs/vault.crt //Vault server certificate CA to trust it.
    VAULT_TOKEN=<VAULT_TOKEN> //Vault root token.
    VAULT_ADDR=https://vault:8200 //Vault server address.
    ```
    4. Vault will be provisioned with 4 Root CAs, AppRole authentication method and one role and policy for each service or container that needs to exchange data with it.
    5. Get RoleID and SecretID for each service and set those values in the empty fields of the `.env` file.
    ```
    # Obtain CA Wrapper RoleID and SecretID
    curl --cacert $VAULT_CA_FILE --header "X-Vault-Token: ${VAULT_TOKEN}" ${VAULT_ADDR}/v1/auth/approle/role/Enroller-CA-role/role-id
    curl --cacert $VAULT_CA_FILE --header "X-Vault-Token: ${VAULT_TOKEN}" --request POST ${VAULT_ADDR}/v1/auth/approle/role/Enroller-CA-role/secret-id 
    # Set RoleID and SecretID in .env file
    CA_VAULTROLEID=<CA_VAULTROLEID>
    CA_VAULTSECRETID=<CA_VAULTSECRETID>
    
    # Obtain SCEP Servers RoleID and SecretID
    curl --cacert $VAULT_CA_FILE --header "X-Vault-Token: ${VAULT_TOKEN}" ${VAULT_ADDR}/v1/auth/approle/role/Lamassu-Root-<CA1/CA2/CA3/CA4>-role/role-id    
    curl --cacert $VAULT_CA_FILE --header "X-Vault-Token: ${VAULT_TOKEN}" --request POST ${VAULT_ADDR}/v1/auth/approle/role/Lamassu-Root-<CA1/CA2/CA3/CA4>-role/secret-id 
    # Set RoleIDs and SecretIDs in .env file
    SCEP_CA1_ROLE_ID=<SCEP_CA1_ROLE_ID>
    SCEP_CA2_ROLE_ID=<SCEP_CA2_ROLE_ID>
    SCEP_CA3_ROLE_ID=<SCEP_CA3_ROLE_ID>
    SCEP_CA4_ROLE_ID=<SCEP_CA4_ROLE_ID>

    SCEP_CA1_SECRET_ID=<SCEP_CA1_SECRET_ID>
    SCEP_CA2_SECRET_ID=<SCEP_CA2_SECRET_ID>
    SCEP_CA3_SECRET_ID=<SCEP_CA3_SECRET_ID>
    SCEP_CA4_SECRET_ID=<SCEP_CA4_SECRET_ID>

    ```
5. Configure Keycloak:
    1. Run Keycloak: `docker-compose up -d keycloak`.
    2. Keycloak image is configured with a Realm, a client and two different roles: admin and operator.
    3. Create a user with admin role to perform Enroller administrator tasks.
    4. Create a user with operator role to perform Device Manufacturing System tasks. This Device Manufacturing System must associate its CSR with this user matching the CN attribute and the username.
6. Download Vault CA certificates to MQTT Gateway CA path.
```
# Get CA certificates and save them in files
curl --cacert $VAULT_CA_FILE --header "X-Vault-Token: ${VAULT_TOKEN}" ${VAULT_ADDR}/v1/Lamassu-Root-CA1-RSA4096/ca/pem > lamassu/mosquitto_ca/Lamassu-Root-CA1-RSA4096.pem
curl --cacert $VAULT_CA_FILE --header "X-Vault-Token: ${VAULT_TOKEN}" ${VAULT_ADDR}/v1/Lamassu-Root-CA2-RSA2048/ca/pem > lamassu/mosquitto_ca/Lamassu-Root-CA1-RSA2048.pem
curl --cacert $VAULT_CA_FILE --header "X-Vault-Token: ${VAULT_TOKEN}" ${VAULT_ADDR}/v1/Lamassu-Root-CA3-ECC384/ca/pem > lamassu/mosquitto_ca/Lamassu-Root-CA3-ECC384.pem
curl --cacert $VAULT_CA_FILE --header "X-Vault-Token: ${VAULT_TOKEN}" ${VAULT_ADDR}/v1/Lamassu-Root-CA4-ECC256/ca/pem > lamassu/mosquitto_ca/Lamassu-Root-CA4-ECC256.pem

# Rehash CA path
openssl rehash lamassu/mosquitto_ca
```
7. Create keys and CSR for the Device Manufacturing System user:
```
openssl genrsa -out <username>.key 4096
openssl req -new -key <username>.csr -subj "/C=${C}/ST=${ST}/L=${L}/O=${O}/CN=<username>" -out <username>.csr

# Copy key to volume path
cp <username>.key lamassu/manufacturing_certs/<username>.key

# The key should be included as a volume in the Device Manufacturing System service to stablish the mTLS authentication. For this, edit the .env file and set the next environment variable:
MANUFACTURING_AUTHKEYFILE=/certs/<username>.key //Device Manufacturing System user key file.
```
8. Check for any empty environment variables in `.env` file and fill them.
9. Start all containers: `docker compose up -d`
