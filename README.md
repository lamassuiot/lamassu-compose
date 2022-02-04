<a href="https://www.lamassu.io/">
    <img src="logo.png" alt="Lamassu logo" title="Lamassu" align="right" height="80" />
</a>

Lamassu Compose
===================
[![License: MPL 2.0](https://img.shields.io/badge/License-MPL%202.0-blue.svg)](http://www.mozilla.org/MPL/2.0/index.txt)

This repository contains the Docker compose files for deploying the [Lamassu](https://www.lamassu.io) services in Docker.

<img src="lamassu-app.png" alt="Lamassu App" title="Lamassu" />

## Known Issues

:warning: As per this release, docker has a known bug that causes dockerd hanging when fluentd is shut down. This issue occurs as docker will try to reconnect to fluentd indefinetly. For mor information refer to the issue: https://github.com/moby/moby/issues/40063 

The issue should be solved once the `fluentd-async` docker plugin is updated with this PR: https://github.com/fluent/fluent-logger-golang/pull/82 

To prevent his issue from happening, the docker-compose `logging` directive has been commented. 

## Lamassu URLs

| Service                                   | URL                               |
|-------------------------------------------|-----------------------------------|
| Lamassu UI                                | https://dev.lamassu.io            |
| Keycloak (Authentication)                 | https://auth.dev.lamassu.io       |
| Vault (PKI storage)                       | https://vault.dev.lamassu.io      |
| Jaeger UI  (Tracing microservices calls)  | https://tracing.dev.lamassu.io    |

## Usage
To launch Lamassu follow the next steps:
1. Clone the repository and get into the directory: `git clone https://github.com/lamassuiot/lamassu-compose && cd lamassu-compose`.
2. Install the `jq` tool. It will be used later: https://stedolan.github.io/jq/download/ 
3. Change the next secret environment variables in `.env` file. **If not changed, it will use admin/admin**

```
DB_USER=<KEYCLOAK_DB_USER> //Database user.
DB_PASSWORD=<KEYCLOAK_DB_PASSWORD> //Database user password.
```


4. Define the domain to be used:

```
export DOMAIN=dev.lamassu.io
```

5. The Gateway and TLS Certificates 

    Lamassu uses a Gateway to expose all the deployed services. Moreover, the gateway is in charge of performing the following tasks:
        - Routing traffic to services
        - Enforcing authentication policies
        - Enforcing authorization policies
        - Logging & tracing
        - Healthchecking
        - Securely expose services using TLS

    The different APIs exposed through the gateway have been configured to ONLY accept request originates inside the platform via a mTLS authentication:

    ```
    ┌───────────────────┐                            ┌───────────────────┐                          ┌───────────────────┐
    │   Client/Browser  │ -------<downstream>------- │      Gateway      │ -------<upstream>------- │        API        │
    └───────────────────┘            TLS             └───────────────────┘           mTLS           └───────────────────┘
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
            ├── downstream
            │   ├── tls.crt
            │   └── tls.key
            ```

        - **Generate a Self Signed certificate**: If you need to create a new self-signed certificate, run the following command:
            ```
            ./gen-downstream-certs.sh
            ```


6. Unless you have a DNS server that is able to resolve the IP of your domain to yourhost, it is recommended adding a new entry to the `/etc/hosts` file. **Replace `dev.lamassu.io` with your domain (The same as the exported DOMAIN env variable).**  
```
127.0.0.1   dev.lamassu.io
127.0.0.1   vault.dev.lamassu.io
127.0.0.1   keycloak.dev.lamassu.io
```

7. In order tu run Lamassus's docker-compose, some adjustments are required. The communication between the different containers will be done trough TLS using the certificates created earlier, thus, the communication between container must use the `DOMAIN` i.e. dev.lamassu.io. **Replace all domain ocurrences of dev.lamassu.io to your domian from the following files**:

```
sed -i 's/dev\.lamassu\.io/'$DOMAIN'/g' config/envoy/config.yaml
```
    
7. Configure Keycloak:
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
    docker-compose exec keycloak /opt/jboss/keycloak/bin/add-user-keycloak.sh -r lamassu -u operator -p operator --roles operator
    ```

    5. Reload keyclok server
    ```
    docker-compose exec keycloak /opt/jboss/keycloak/bin/jboss-cli.sh --connect command=:reload
    ```
    
    If Keycloak display the following output, keycloak has successfully reloaded. Otherwise, run the command again until you see the expected output:
    ```
    {
        "outcome" => "success",
        "result" => undefined
    }
    ```
9. Provision and configure Vault secret engine:
    1. Run Vault: 
    ```
    docker-compose up -d vault
    ``` 
    2. Initalize vault: This process generates vault's unseal keys as well as the root token:
    ```
    docker-compose exec vault vault operator init -key-shares=5 -key-threshold=3 -tls-skip-verify -format=json > vault-credentials.json
    ```
    
    Verify the `vault-credentials.json` file has the expected content. It should be similar to this:
    ```
    {
        "keys": [
            "700060e1b7b2fb8611dd573981ceac18fb5c4947e9e756b51054aa435f49ecb019",
            "a16c1d059391e67edd9ddbd9138cca7b5430f191170392167a63b7bb4b086d0ce3",
            "e22edcde992bac128e5b30295da8be5795926c7253ef17a159bf9ecddc05d8c053",
            "ad0e6680d1ee343d79d7a5c539f43885679671931b5700eab321420d045e7e0d2b",
            "2eebfbb487bc9fcb89f3fd7ef17b92b0a4243bdec2be1e1aeaa79651f496d36824"
        ],
        "keys_base64": [
            "cABg4bey+4YR3Vc5gc6sGPtcSUfp51a1EFSqQ19J7LAZ",
            "oWwdBZOR5n7dndvZE4zKe1Qw8ZEXA5IWemO3u0sIbQzj",
            "4i7c3pkrrBKOWzApXai+V5WSbHJT7xehWb+ezdwF2MBT",
            "rQ5mgNHuND1516XFOfQ4hWeWcZMbVwDqsyFCDQRefg0r",
            "Luv7tIe8n8uJ8/1+8XuSsKQkO97Cvh4a6qeWUfSW02gk"
        ],
        "root_token": "s.IOuVWvB8B1xcWYhNrx1A4mvy"
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
    
    5. Vault must be provisioned with some resources (authentication methods, policies and secret engines). That can be achieved by running the `ca-provision.sh` script. 

    ```
    cd config/vault/provision/
    ./provisioner.sh

    cd ../../../
    ```

    6. Vault will be provisioned with 4 Root CAs, 1 Special CA (Lamassu-Lamassu-DMS) AppRole authentication method and one role and policy for each service or container that needs to exchange data with it. 
    
    7. The Device Manager has an embedded EST server. Such service protects its endpoints by only allowing REST calls presenting a peer TLS certificate issued by the (DMS) Enroller. The (DMS) Enroller CA cert must be mounted by the EST Server. To obtain the certificate run the following commands:

    ```
    cat intermediate-DMS.crt > ../lamassu/device-manager_certs/dms-ca.crt
    cat CA_cert.crt >> ../lamassu/device-manager_certs/dms-ca.crt
    ```
    
    Change the context to the upper directory
    ```
    cd ..
    ```

    8. Get RoleID and SecretID for each service and set those values in the empty fields of the `.env` file.
    ```
    export CA_VAULTROLEID=$(curl --cacert $VAULT_CA_FILE --header "X-Vault-Token: ${VAULT_TOKEN}" ${VAULT_ADDR}/v1/auth/approle/role/Enroller-CA-role/role-id | jq -r .data.role_id )

    export CA_VAULTSECRETID=$(curl --cacert $VAULT_CA_FILE --header "X-Vault-Token: ${VAULT_TOKEN}" --request POST ${VAULT_ADDR}/v1/auth/approle/role/Enroller-CA-role/secret-id | jq -r .data.secret_id)

    # Set RoleID and SecretID in .env file
    sed -i 's/ROLE_ID_TO_BE_REPLACED/'$CA_VAULTROLEID'/g' .env
    sed -i 's/SECRET_ID_TO_BE_REPLACED/'$CA_VAULTSECRETID'/g' .env
    ```
    
9. The Device Manage has a configurable variable that deteremines when a device can renew (also known as reenroll) its certificate. By default the reenrollment process can only be done 30 days prior to the cert's expiratio time. This value can be changed by modifying the `DEVICES_MINIMUMREENROLLDAYS` variable located in the `.env` file
    
10. Start the remaining services:
```
docker-compose up -d
```

11. Configure a new DMS Instance
    1. First, authenticate against Keycloak:
    ```
    export TOKEN=$(curl -k --location --request POST "https://$DOMAIN:8443/auth/realms/lamassu/protocol/openid-connect/token" --header 'Content-Type: application/x-www-form-urlencoded' --data-urlencode 'grant_type=password' --data-urlencode 'client_id=admin-cli' --data-urlencode 'username=enroller' --data-urlencode 'password=enroller' |jq -r .access_token)
    ```
    2. Then, register a new DMS named Lamassu-Default-DMS:
    **Note: while registering new DMS instances with non admin users, it is necessary to register the DMS using the user's username as the common name, otherwise, the user won't see its DMSs**   
    ```    
    export DMS_REGISTER_RESPONSE=$(curl -k --location --request POST "https://$DOMAIN:8085/v1/csrs/Lamassu-Default-DMS/form" --header "Authorization: Bearer ${TOKEN}" --header 'Content-Type: application/json' --data-raw "{\"url\":\"https://${DOMAIN}:5000\", \"common_name\": \"Lamassu-Default-DMS\",\"country\": \"\",\"key_bits\": 3072,\"key_type\": \"rsa\",\"locality\": \"\",\"organization\": \"\",\"organization_unit\": \"\",\"state\": \"\"}")
    
    echo $DMS_REGISTER_RESPONSE | jq -r .priv_key | sed 's/\\n/\n/g' | sed -Ez '$ s/\n+$//' > lamassu-default-dms.key

    export DMS_ID=$(echo $DMS_REGISTER_RESPONSE | jq -r .csr.id)
    ```
    3. Enroll the new DMS
    ```
    curl -k --location --request PUT "https://$DOMAIN:8085/v1/csrs/$DMS_ID" --header "Authorization: Bearer $TOKEN" --header 'Content-Type: application/json' --data-raw '{"status": "APPROVED"}'
    ```
    4. Get issued DMS Cert
    ```
    curl -k --location --request GET "https://$DOMAIN:8085/v1/csrs/$DMS_ID/crt" --header "Authorization: Bearer $TOKEN" > lamassu-default-dms.crt 
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
    
    7.  Reboot all services but the default DMS:
    ```
    cd ..
    docker-compose down
    docker-compose up -d
    ```