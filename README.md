<a href="https://www.lamassu.io/">
    <img src="logo.png" alt="Lamassu logo" title="Lamassu" align="right" height="80" />
</a>

Lamassu Compose
===================
[![License: MPL 2.0](https://img.shields.io/badge/License-MPL%202.0-blue.svg)](http://www.mozilla.org/MPL/2.0/index.txt)

This repository contains the Docker compose files for deploying the [Lamassu](https://www.lamassu.io) services in Docker.

<img src="lamassu-app.png" alt="Lamassu App" title="Lamassu" />

## Lamassu UIs

| Service                                   | URL                                   |
|-------------------------------------------|---------------------------------------|
| Lamassu UI                                | https://dev.lamassu.io                |
| Keycloak (Authentication)                 | https://auth.dev.lamassu.io           |
| Vault (PKI storage)                       | https://vault.dev.lamassu.io          |
| Jaeger UI  (Tracing microservices calls)  | https://tracing.dev.lamassu.io        |
| RabbitMQ Admin Page  (Async events)       | https://ui-rabbitmq.dev.lamassu.io    |

## Setup 
Requirements: 

- `jq`. Get the latest version: https://stedolan.github.io/jq/download/ 
- `docker` and `docker-compose`: Get the latest version: https://docs.docker.com/engine/install/ubuntu/ and https://docs.docker.com/compose/install/


To launch Lamassu follow the next steps:

1. Set up your environment:

    1. Clone the repository and get into the directory: 
        ```
        git clone https://github.com/lamassuiot/lamassu-compose && cd lamassu-compose
        ```

    2. Change the next secret environment variables in `.env` file. **If not changed, it will use admin/admin**

        ```
        DB_USER=<DB_USER> //Database user.
        DB_PASSWORD=<DB_PASSWORD> //Database user password.
        ```


    3. Define the domain to be used:

        ```
        export DOMAIN=dev.lamassu.io
        sed -i 's/dev\.lamassu\.io/'$DOMAIN'/g' .env
        ```


2. The Gateway and TLS Certificates 

    Lamassu uses a Gateway to expose all the deployed services. Moreover, the gateway is in charge of performing the following tasks:
        - Routing traffic to services
        - Enforcing authentication policies
        - Enforcing authorization policies
        - Logging & tracing
        - Healthchecking
        - Securely expose services using TLS

    The different APIs exposed through the gateway have been configured to ONLY accept request originates inside the platform via a mTLS authentication:

    ```
    ┌────────────────┐                         ┌───────────────┐                        ┌─────────────┐
    │ Client/Browser │ ------<downstream>----- │    Gateway    │ ------<upstream>------ │     API     │
    └────────────────┘          TLS            └───────────────┘          mTLS          └─────────────┘
    ```

    1. Generate the upstream certificates. 

        ```
        cd tls-certificates
        ./gen-upstream-certs.sh
        ```

    2. There are 2 options for the downstream certificate:

        - **Import an existing certificate**: If you have valid certificates for your domain, you can use them by placing them under the `downstream` folder. The end result should be:
            ```
            ├── upstream
            │   └── ...
            └── downstream
                ├── tls.crt
                └── tls.key
            ```

        - **Generate a Self Signed certificate**: If you need to create a new self-signed certificate, run the following command:
            ```
            ./gen-downstream-certs.sh
            ```

3. Authentication service configuration:
    1. Run Keycloak: 
        ```
        docker-compose up -d auth
        ```
    2. Keycloak image is configured with a Realm, a client and two different roles: `admin` and `operator`.

    3. Create a user with admin role to perform Enroller administrator tasks. (The command below creates a user named **enroller** with **enroller** as its password):
        ```
        docker-compose exec auth /opt/jboss/keycloak/bin/add-user-keycloak.sh -r lamassu -u enroller -p enroller --roles admin
        ```
    4. Create a user with operator role to perform Device Manufacturing System tasks. This Device Manufacturing System must associate its CSR with this user matching the CN attribute and the username.(The command below creates a user named **operator** with **operator** as its password):
        ```
        docker-compose exec auth /opt/jboss/keycloak/bin/add-user-keycloak.sh -r lamassu -u operator -p operator --roles operator
        ```

    5. Reload keyclok server
        ```
        docker-compose exec auth /opt/jboss/keycloak/bin/jboss-cli.sh --connect command=:reload
        ```
    
    6. If Keycloak display the following output, keycloak has successfully reloaded. Otherwise, run the command again until you see the expected output:
    ```
    {
        "outcome" => "success",
        "result" => undefined
    }
    ```
4. Provision and configure Vault and Lamassu CA:
    1. Run Vault: 
        ```
        docker-compose up -d vault consul-server api-gateway
        ``` 
    2. Initalize vault: This process generates vault's unseal keys as well as the root token:
        ```
        docker-compose exec vault vault operator init -key-shares=5 -key-threshold=3 -tls-skip-verify -format=json > vault-credentials.json
        ```
    3. Verify the `vault-credentials.json` file has the expected content. It should be similar to this:
        ```
        {
            "unseal_keys_b64": [
                "Hfx46iMq/PXoBPhDZ0EAMM9MDWS8GTCANFbAkzVEzFOD",
                "lfo48PHGFGHmpaFn6Z6rWTXTXVS53m9duxsvwVjRDc2L",
                "dcVw6N81i+/pY34WTHQYkV848to7jNeVkgdJOtgxnRkS",
                "Aut6oL7+GomXCrrTH0FCKhJwAs2PrWFYSnWpgjLfwsH0",
                "pprFM0HJEUR4m3kaIT5sga87aJ4AjXi32KVn6dgfivii"
            ],
            "unseal_keys_hex": [
                "1dfc78ea232afcf5e804f84367410030cf4c0d64bc1930803456c0933544cc5383",
                "95fa38f0f1c61461e6a5a167e99eab5935d35d54b9de6f5dbb1b2fc158d10dcd8b",
                "75c570e8df358befe9637e164c7418915f38f2da3b8cd7959207493ad8319d1912",
                "02eb7aa0befe1a89970abad31f41422a127002cd8fad61584a75a98232dfc2c1f4",
                "a69ac53341c91144789b791a213e6c81af3b689e008d78b7d8a567e9d81f8af8a2"
            ],
            "unseal_shares": 5,
            "unseal_threshold": 3,
            "recovery_keys_b64": [],
            "recovery_keys_hex": [],
            "recovery_keys_shares": 5,
            "recovery_keys_threshold": 3,
            "root_token": "s.80Mpm0OmxlXzoSxZB2MMPcNu"
        }

        ```
    
    3. Export the following variables:
        ```
        export VAULT_TOKEN=$(cat vault-credentials.json | jq .root_token -r)
        export VAULT_ADDR=https://vault.$DOMAIN
        ```

    4. Unseal Vault using the keys obtained with the previous command:
        ```
        curl --request PUT "$VAULT_ADDR/v1/sys/unseal" -k --header 'Content-Type: application/json' --data-raw "{\"key\": \"$(cat vault-credentials.json | jq -r .unseal_keys_hex[0])\" }"
        curl --request PUT "$VAULT_ADDR/v1/sys/unseal" -k --header 'Content-Type: application/json' --data-raw "{\"key\": \"$(cat vault-credentials.json | jq -r .unseal_keys_hex[1])\" }"
        curl --request PUT "$VAULT_ADDR/v1/sys/unseal" -k --header 'Content-Type: application/json' --data-raw "{\"key\": \"$(cat vault-credentials.json | jq -r .unseal_keys_hex[2])\" }"
        ```
    
    5. Vault must be provisioned with some resources (authentication methods, policies and secret engines). That can be achieved by running the `ca-provision.sh` script. Vault will be provisioned with 4 Root CAs, 1 Special CA (Lamassu-DMS-Enroller) AppRole authentication method and one role and policy for each service or container that needs to exchange data with it. 

        ```
        cd config/vault/provision/
        ./provisioner.sh
        cd ../../../
        ```    

    6. Get RoleID and SecretID for each service and set those values in the empty fields of the `.env` file.
        ```
        export CA_VAULT_ROLEID=$(curl -k --header "X-Vault-Token: ${VAULT_TOKEN}" ${VAULT_ADDR}/v1/auth/approle/role/lamassu-ca-role/role-id | jq -r .data.role_id )
        export CA_VAULT_SECRETID=$(curl -k --header "X-Vault-Token: ${VAULT_TOKEN}" --request POST ${VAULT_ADDR}/v1/auth/approle/role/lamassu-ca-role/secret-id | jq -r .data.secret_id)

        # Set RoleID and SecretID in .env file
        sed -i 's/<LAMASSU_CA_VAULT_ROLE_ID>/'$CA_VAULT_ROLEID'/g' .env
        sed -i 's/<LAMASSU_CA_VAULT_SECRET_ID>/'$CA_VAULT_SECRETID'/g' .env
        ```

5. Configure the Device Manager:

    1. The Device Manage has a configurable variable that deteremines when a device can renew (also known as reenroll) its certificate. By default the reenrollment process can only be done 30 days prior to the cert's expiratio time. This value can be changed by modifying the `DEVICE_MANAGER_MINIMUM_REENROLL_DAYS` variable located in the `.env` file.

    
6. Start the remaining services:
```
docker-compose up -d
```

7. Configure the `Default DMS`
    1. First, authenticate against Keycloak:
        ```
        export AUTH_ADDR=auth.$DOMAIN

        export TOKEN=$(curl -k --location --request POST "https://$AUTH_ADDR/auth/realms/lamassu/protocol/openid-connect/token" --header 'Content-Type: application/x-www-form-urlencoded' --data-urlencode 'grant_type=password' --data-urlencode 'client_id=admin-cli' --data-urlencode 'username=enroller' --data-urlencode 'password=enroller' |jq -r .access_token)
        ```
    2. Then, register a new DMS named Lamassu-Default-DMS:
        
        **Note: while registering new DMS instances with non admin users, it is necessary to register the DMS using the user's username as the common name, otherwise, the user won't see its DMSs**   
        ```    
        export ENROLL_ADDR=$DOMAIN/api/dmsenroller

        export DMS_REGISTER_RESPONSE=$(curl -k --location --request POST "https://$ENROLL_ADDR/v1/Lamassu-Default-DMS/form" --header "Authorization: Bearer ${TOKEN}" --header 'Content-Type: application/json' --data-raw "{\"url\":\"https://${DOMAIN}:5000\", \"common_name\": \"Lamassu-Default-DMS\",\"country\": \"\",\"key_bits\": 3072,\"key_type\": \"rsa\",\"locality\": \"\",\"organization\": \"\",\"organization_unit\": \"\",\"state\": \"\"}")
        
        echo $DMS_REGISTER_RESPONSE | jq -r .priv_key | sed 's/\\n/\n/g' | sed -Ez '$ s/\n+$//' > lamassu-default-dms.key

        export DMS_ID=$(echo $DMS_REGISTER_RESPONSE | jq -r .dms.id)
        ```
    3. Enroll the new DMS
        ```
        curl -k --location --request PUT "https://$ENROLL_ADDR/v1/$DMS_ID" --header "Authorization: Bearer $TOKEN" --header 'Content-Type: application/json' --data-raw '{"status": "APPROVED"}'
        ```
    4. Get issued DMS Cert
        ```
        curl -k --location --request GET "https://$ENROLL_ADDR/v1/$DMS_ID/crt" --header "Authorization: Bearer $TOKEN" > lamassu-default-dms.crt
        ```
    5. The DMS requires the following keys and certicates:
    
        ```
        cp lamassu/lamassu.crt lamassu-default-dms/device-manager.crt
        cp lamassu/lamassu.crt lamassu-default-dms/https.crt
        cp lamassu/lamassu.key lamassu-default-dms/https.key
        ```
        
        ```
        cp lamassu-default-dms.crt lamassu-default-dms/enrolled-dms.crt
        cp lamassu-default-dms.key lamassu-default-dms/enrolled-dms.key
        ```
    
    6. And finally, start the DMS "server":
        ```
        cd lamassu-default-dms
        sed -i 's/dev\.lamassu\.io/'$DOMAIN'/g' index.js
        docker-compose up -d
        ```
        The server has the following endpoint:
        `dev.lamassu.io:5000/dms-issue/<DEVICE_ID>/<CA_NAME>` This endpoint enrolls a registered device
            
        Once enrolled, the device certificate can be obtained using the following endpoint exposed by the `DEVICE Manager` service:
        ```
        curl -k --location --request GET "https://$DOMAIN:8089/v1/devices/<DEVICE_ID>/cert" --header "Authorization: Bearer $TOKEN" 
        ```
### Using the APIs

The main 3 Open API documentation can be found on the following urls:
    - https://dev-lamassu.zpd.ikerlan.es/api/ca/v1/docs/
    - https://dev-lamassu.zpd.ikerlan.es/api/dmsenroller/v1/docs/
    - https://dev-lamassu.zpd.ikerlan.es/api/devmanager/v1/docs/


⚠️ The following endpoints defined in the Lamassu Device Manager Api specification are not correctly defined due to the limitations imposed by the Open API 3.0 schema. The current specification defines an `OIDC` security schema (meaining that a valid JWT token must be provided while requesting the API) while the implemented security schema uses the `mTLS` approach. This issue will be resolved once the specification is Open API 3.1 compliant. The affected endpoints are: