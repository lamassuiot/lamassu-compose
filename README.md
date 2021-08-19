<a href="https://www.lamassu.io/">
    <img src="logo.png" alt="Lamassu logo" title="Lamassu" align="right" height="80" />
</a>

Lamassu Compose
===================
[![License: MPL 2.0](https://img.shields.io/badge/License-MPL%202.0-blue.svg)](http://www.mozilla.org/MPL/2.0/index.txt)

This repository contains the Docker compose files for deploying the [Lamassu](https://www.lamassu.io) services in Docker.

## Lamassu URLs

| Service                                   | URL                          |
|-------------------------------------------|------------------------------|
| Lamassu UI                                | https://dev.lamassu.io:443   |
| Keycloak (Authentication)                 | https://dev.lamassu.io:8443  |
| Consul (Health Status & Service Discovery)| https://dev.lamassu.io:8501  |
| Vault (PKI storage)                       | https://dev.lamassu.io:8200  |
| Kibana (Log inspection)                   | https://dev.lamassu.io:5601  |
| Jaeger UI  (Tracing microservices calls)  | http://dev.lamassu.io:16686  |

## Usage
To launch Lamassu follow the next steps:
1. Clone the repository and get into the directory: `git clone https://github.com/lamassuiot/lamassu-compose && cd lamassu-compose`.
2. Install the `jq` tool. It will be used later: https://stedolan.github.io/jq/download/ 
3. Change the next secret environment variables in `.env` file. **If not changed, it will use admin/admin. Open Distro for Elasticsearch (from now on refered as elasric), uses 4 different users admin/admin fluentd/admin jaeger/admin kibana/admin. The first set of credentilas correspond to the elastic's admin user, while the remainig three are used by fluentd, jager and kibana respectivly. The main reason for having 4 different user credentials is to grant different permissions for each service.**


```
KEYCLOAK_DB_USER=<KEYCLOAK_DB_USER> //Keycloak database user.
KEYCLOAK_DB_PASSWORD=<KEYCLOAK_DB_PASSWORD> //Keycloak database user password.
KEYCLOAK_USER=<KEYCLOAK_USER> //Keycloak admin user.
KEYCLOAK_PASSWORD=<KEYCLOAK_PASSWORD> //Keycloak admin password.

ENROLLER_POSTGRESUSER=<ENROLLER_POSTGRESUSER> //Enroller database user.
ENROLLER_POSTGRESPASSWORD=<ENROLLER_POSTGRESPASSWORD> //Enroller database user password.

DEVICES_POSTGRESUSER=<DEVICES_POSTGRESUSER> //Device Manager database user.
DEVICES_POSTGRESPASSWORD=<DEVICES_POSTGRESPASSWORD> //Device Manager database password.

ELASTIC_ADMIN_USERNAME=<ELASTIC_ADMIN_USERNAME> //Elasticseach admin username. This user manages and controlls the elastic server.
ELASTIC_ADMIN_PASSWORD=<ELASTIC_ADMIN_PASSWORD> //Elasticseach admin password.
ELASTIC_FLUENTD_USERNAME=<ELASTIC_FLUENTD_USERNAME> //Elasticseach fluentd username.
ELASTIC_FLUENTD_PASSWORD=<ELASTIC_FLUENTD_PASSWORD> //Elasticseach fluentd password.
ELASTIC_JAEGER_USERNAME=<ELASTIC_JAEGER_USERNAME> //Elasticseach fluentd username.
ELASTIC_JAEGER_PASSWORD=<ELASTIC_JAEGER_PASSWORD> //Elasticseach fluentd password.
ELASTIC_KIBANA_USERNAME=<ELASTIC_KIBANA_USERNAME> //Kibana-Elasticsearch username.
ELASTIC_KIBANA_PASSWORD=<ELASTIC_KIBANA_PASSWORD> //Kibana-Elasticsearch password.

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

Elastic accepts keys in the pkcs8 format. The following command will convert the pem encoded key to the correspondig pkcs8 encoding format.
```
openssl pkcs8 -in lamassu/elastic_certs/elastic.key -topk8 -out lamassu/elastic_certs/elastic-pkcs8.key -nocrypt
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
    
7. Configure Keycloak:
    1. Run Elastic (This also will trigger the launching of Keyclaok and its DB): 
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
    
    6. Keycloak also needs to be configured with a client used by the device manager to authenticate himself using a service account. **Note that the following commands assume the  credentials for the ADMIN user have been not changed (admin/admin). Otherwise just change the first command accordingly** 
    ```
    docker-compose exec keycloak /opt/jboss/keycloak/bin/kcadm.sh config credentials --server http://localhost:8080/auth --realm master --user admin --password admin
    export KC_DEV_MANAGER_CLIENT_UUID=$(docker-compose exec keycloak /opt/jboss/keycloak/bin/kcadm.sh create clients -r lamassu -s clientId=device-manager -s 'redirectUris=["*"]' -s 'webOrigins=["*"]' -s 'clientAuthenticatorType=client-secret' -s 'serviceAccountsEnabled=true' -i)
    export KC_KIBANA_CLIENT_UUID=$(docker-compose exec keycloak /opt/jboss/keycloak/bin/kcadm.sh create clients -r lamassu -s clientId=kibana -s 'redirectUris=["*"]' -s 'webOrigins=["*"]' -s 'clientAuthenticatorType=client-secret' -i)

    ```
    7. Check the contents of the KC_DEV_MANAGER_CLIENT_UUID variable containing a UUID string such as `8bfc57b4-23d6-4a1d-893a-592d3a579706`:
    
    ```
    echo $KC_DEV_MANAGER_CLIENT_UUID
    echo $KC_KIBANA_CLIENT_UUID
    
    export KC_DEV_MANAGER_CLIENT_UUID=`echo $KC_DEV_MANAGER_CLIENT_UUID | sed 's/\\r//g'`
    export KC_KIBANA_CLIENT_UUID=`echo $KC_KIBANA_CLIENT_UUID | sed 's/\\r//g'`
    ```
    
    ```
    export KC_DEV_MANAGER_CLIENT_SECRET=$(docker-compose exec keycloak /opt/jboss/keycloak/bin/kcadm.sh create -r lamassu clients/$KC_DEV_MANAGER_CLIENT_UUID/client-secret -o | jq -r .value)
    ```
    ```
    export KC_KIBANA_CLIENT_SECRET=$(docker-compose exec keycloak /opt/jboss/keycloak/bin/kcadm.sh create -r lamassu clients/$KC_KIBANA_CLIENT_UUID/client-secret -o | jq -r .value)
    ```
    8. Replace the device manager client secret from the `.env` file:
    ```
    sed -i 's/KEYCLOAK_DEV_MANAGER_CLIENT_SECRET_TO_BE_REPLACED/'$KC_DEV_MANAGER_CLIENT_SECRET'/g' .env    
    ```
    9. Elasic will integrare Keycloak using the OIDC protocol. Elastic will  be configured to map keycloak roles into elasticsearch roles. The mapping process looks for the JWT `role` claim. This claim is not present in the JWT obtained when logging in via keycloak, thus it is required to run the following commands:
   ```
    CLIENT_SCOPE_ROLE_ID=$(docker-compose exec keycloak /opt/jboss/keycloak/bin/kcadm.sh get client-scopes -r lamassu | jq '.[] | select(.name=="roles") | .id' -r | sed -Ez '$ s/\n+$//')

    docker-compose exec keycloak /opt/jboss/keycloak/bin/kcadm.sh create client-scopes/$CLIENT_SCOPE_ROLE_ID/protocol-mappers/models -r lamassu -s name=roles -s protocol=openid-connect -s protocolMapper=oidc-usermodel-realm-role-mapper -s 'config."multivalued"=true' -s 'config."userinfo.token.claim"=true' -s 'config."id.token.claim"=true' -s 'config."access.token.claim"=true' -s 'config."claim.name"=roles' -s 'config."jsonType.label"=String'
   ```
    10. The last step is to validate that the obtained JWT token includes the `role` claim. The following command will authenticate the enroller/enroller user:
   ```
   curl -k --location --request POST "https://$DOMAIN:8443/auth/realms/lamassu/protocol/openid-connect/token" --header 'Content-Type: application/x-www-form-urlencoded' --data-urlencode 'grant_type=password' --data-urlencode 'client_id=frontend' --data-urlencode 'username=enroller' --data-urlencode 'password=enroller' |jq -r .access_token | jq -R 'split(".") | .[1] | @base64d | fromjson'
   ```
    The following json represents a decoded JWT token obtained by running the previous command. As it can be seen, the last claim in the token is the `roles` claim containing the list of roles assigned to the enroller user.
   ```
   {
      "exp": 1628503449,
      "iat": 1628503149,
      "jti": "8b170887-3ca7-4102-bbb6-87eb60821889",
      "iss": "https://dev.lamassu.io:8443/auth/realms/lamassu",
      "aud": "account",
      "sub": "469bc497-5a11-4ca0-b5cf-f91db850f2a7",
      "typ": "Bearer",
      "azp": "frontend",
      "session_state": "0bac4e43-648e-4f4d-8755-32bf0c191391",
      "acr": "1",
      "allowed-origins": [
        "*"
      ],
      "realm_access": {
        "roles": [
          "default-roles-lamassu",
          "offline_access",
          "admin",
          "uma_authorization"
        ]
      },
      "resource_access": {
        "account": {
          "roles": [
            "manage-account",
            "manage-account-links",
            "view-profile"
          ]
        }
      },
      "scope": "profile email",
      "email_verified": false,
      "preferred_username": "enroller", 
      "roles": [
        "default-roles-lamassu",
        "offline_access",
        "admin",
        "uma_authorization"
      ]
    }
    ```
8. Configure Open Distro for Elasticsearch
    1.  In order to manage and initialize elastic's security module. This script requires that the admin's cert distinguished name matches the one specified in the `elasticsearch.yml` file 

    ```
    ADMIN_DN=$(openssl x509 -subject -nameopt RFC2253 -noout -in lamassu/elastic_certs/elastic.crt | sed 's/subject=//g')
    sed -i 's/ADMIN_DN_TO_REPLACE/'$ADMIN_DN'/g' elastic/elasticsearch.yml
    ```
    2. Launch Elastic:
    ```
    docker-compose up -d elastic
    ```

    3. As mentioned earlier, elastic will bootstraped with 3 users. Elastic uses a special file listing all internal users named `internal_users.yml`. This file also containes the hashed credentials of each user as well as the main roles assigned to them. Run the following commands to configure the file accordingly 

    ```
    ELASTIC_ADMIN_USERNAME=$(awk -F'=' '/^ELASTIC_ADMIN_USERNAME/ { print $2}' .env)
    ELASTIC_ADMIN_PASSWORD_HASH=$(docker-compose exec elastic /usr/share/elasticsearch/plugins/opendistro_security/tools/hash.sh -p $(awk -F'=' '/^ELASTIC_ADMIN_PASSWORD/ { print $2}' .env) | tr -dc '[[:print:]]')

    ELASTIC_FLUENTD_USERNAME=$(awk -F'=' '/^ELASTIC_FLUENTD_USERNAME/ { print $2}' .env)
    ELASTIC_FLUENTD_PASSWORD_HASH=$(docker-compose exec elastic /usr/share/elasticsearch/plugins/opendistro_security/tools/hash.sh -p $(awk -F'=' '/^ELASTIC_FLUENTD_PASSWORD/ { print $2}' .env) | tr -dc '[[:print:]]')

    ELASTIC_JAEGER_USERNAME=$(awk -F'=' '/^ELASTIC_JAEGER_USERNAME/ { print $2}' .env)
    ELASTIC_JAEGER_PASSWORD_HASH=$(docker-compose exec elastic /usr/share/elasticsearch/plugins/opendistro_security/tools/hash.sh -p $(awk -F'=' '/^ELASTIC_JAEGER_PASSWORD/ { print $2}' .env) | tr -dc '[[:print:]]')

    ELASTIC_KIBANA_USERNAME=$(awk -F'=' '/^ELASTIC_KIBANA_USERNAME/ { print $2}' .env)
    ELASTIC_KIBANA_PASSWORD=$(awk -F'=' '/^ELASTIC_KIBANA_PASSWORD/ { print $2}' .env)
    ELASTIC_KIBANA_PASSWORD_HASH=$(docker-compose exec elastic /usr/share/elasticsearch/plugins/opendistro_security/tools/hash.sh -p $(awk -F'=' '/^ELASTIC_KIBANA_PASSWORD/ { print $2}' .env) | tr -dc '[[:print:]]')

    echo $ELASTIC_ADMIN_USERNAME
    echo $ELASTIC_ADMIN_PASSWORD_HASH
    echo $ELASTIC_FLUENTD_USERNAME
    echo $ELASTIC_FLUENTD_PASSWORD_HASH
    echo $ELASTIC_JAEGER_USERNAME
    echo $ELASTIC_JAEGER_PASSWORD_HASH
    echo $ELASTIC_KIBANA_USERNAME
    echo $ELASTIC_KIBANA_PASSWORD_HASH
    ```
    4. Verify the above commands were successfully. It should be similar to this:
    ```
    admin
    $2y$12$WYfRkIctUpVY7YDdZfHU.elQ/tRBKWQNqPqKsQEtk/zh9g3DmVSP2
    fluentd
    $2y$12$Joux9O6vGU659lckKJqMeOSM6HLWJ6Ib4G02SYs7Yy3EQZV0fm.Jq
    jaeger
    $2y$12$DgUW3qo/Wgck5iu0gSeGUuS9iYlBcrSdk.1aBiyyhybObJ10ARgfW
    kibana
    $2y$12$FOMAPbHUV89WM5j9QV7seupdqhfTamLQlUiKMFnRFMEjOOiw2frJe
    ```
    5. Replace the templated `internal_users.yml` file:
    ```
    sed -i 's/ELASTIC_ADMIN_USERNAME_TO_REPLACE/'$ELASTIC_ADMIN_USERNAME'/g' elastic/elastic-internal-users.yml
    sed -i 's~ELASTIC_ADMIN_PASSWORD_TO_REPLACE~'$ELASTIC_ADMIN_PASSWORD_HASH'~g' elastic/elastic-internal-users.yml
    sed -i 's/ELASTIC_FLUENTD_USERNAME_TO_REPLACE/'$ELASTIC_FLUENTD_USERNAME'/g' elastic/elastic-internal-users.yml
    sed -i 's~ELASTIC_FLUENTD_PASSWORD_TO_REPLACE~'$ELASTIC_FLUENTD_PASSWORD_HASH'~g' elastic/elastic-internal-users.yml
    sed -i 's/ELASTIC_JAEGER_USERNAME_TO_REPLACE/'$ELASTIC_JAEGER_USERNAME'/g' elastic/elastic-internal-users.yml
    sed -i 's~ELASTIC_JAEGER_PASSWORD_TO_REPLACE~'$ELASTIC_JAEGER_PASSWORD_HASH'~g' elastic/elastic-internal-users.yml
    sed -i 's/ELASTIC_KIBANA_USERNAME_TO_REPLACE/'$ELASTIC_KIBANA_USERNAME'/g' elastic/elastic-internal-users.yml
    sed -i 's~ELASTIC_KIBANA_PASSWORD_TO_REPLACE~'$ELASTIC_KIBANA_PASSWORD_HASH'~g' elastic/elastic-internal-users.yml
    ```
    6. Elastic will be configured to accept incoming requests from authenticated keycloak users by providing a valid bearer token. Internal users defined in the `internal_users.yml` must be authenticated through using http basic auth. Run the following commands to configure elasticsearch's integration with keycloak:

    ```
    sed -i 's/dev\.lamassu\.io/'$DOMAIN'/g' elastic/elastic-security-config.yml
    ```
    7. Initializa/Update elastic's security plugin:

    ```
    docker-compose exec elastic /usr/share/elasticsearch/plugins/opendistro_security/tools/securityadmin.sh -cd /usr/share/elasticsearch/plugins/opendistro_security/securityconfig/ -icl -nhnv -cacert /usr/share/elasticsearch/config/elastic.crt -cert /usr/share/elasticsearch/config/elastic.crt -key /usr/share/elasticsearch/config/elastic-pkcs8.key
    ```
    8. The remaining configuration steps will determine the permission that each authenticated keyclaok user will have whitin elastic. The following command will assign full access ONLY to keycloak users having the KEYCLOAK `admin` role. 
    ```
    ELASTIC_ADMIN_PASSWORD=$(awk -F'=' '/^ELASTIC_ADMIN_PASSWORD/ { print $2}' .env)
    BASIC_AUTH=$(printf "%s" "$ELASTIC_ADMIN_USERNAME:$ELASTIC_ADMIN_PASSWORD" | base64 )

    curl -k --location --request PUT "https://$DOMAIN:9200/_opendistro/_security/api/rolesmapping/all_access" \
    --header "Authorization: Basic $BASIC_AUTH" \
    --header 'Content-Type: application/json' \
    --data-raw '{
      "backend_roles" : [ "admin" ],
      "hosts" : [ ],
      "users" : [ ]
    }'
    ```
    9. Finally, try obtaning the list of elasticsearch indices using a keycloak user:
    ```
    TOKEN=$(curl -k --location --request POST "https://$DOMAIN:8443/auth/realms/lamassu/protocol/openid-connect/token" --header 'Content-Type: application/x-www-form-urlencoded' --data-urlencode 'grant_type=password' --data-urlencode 'client_id=frontend' --data-urlencode 'username=enroller' --data-urlencode 'password=enroller' |jq -r .access_token)

    curl -k --location --request GET "https://$DOMAIN:9200/_cat/indices?format=json" --header "Authorization: Bearer $TOKEN"
    ```
    If everything worked as intended, the request should return an output similar to the one below:
    ```
    [
        {
            "health": "green",
            "status": "open",
            "index": ".opendistro_security",
            "uuid": "Xu3BxJwASXS1rGHnhc_d1g",
            "pri": "1",
            "rep": "0",
            "docs.count": "9",
            "docs.deleted": "9",
            "store.size": "94.9kb",
            "pri.store.size": "94.9kb"
        }
    ]
    ```
    
    Now, try to obtain the list of elasticsearch indices. This time use the `operator` user instead:
    ```
    TOKEN=$(curl -k --location --request POST "https://$DOMAIN:8443/auth/realms/lamassu/protocol/openid-connect/token" --header 'Content-Type: application/x-www-form-urlencoded' --data-urlencode 'grant_type=password' --data-urlencode 'client_id=frontend' --data-urlencode 'username=operator' --data-urlencode 'password=operator' |jq -r .access_token)

    curl -k --location --request GET "https://$DOMAIN:9200/_cat/indices?format=json" --header "Authorization: Bearer $TOKEN"
    ```
    This time, the request is not succesful as the `operator` user has not assigned keyclok's `admin` role:
    ```
    {
       "error":{
          "root_cause":[
             {
                "type":"security_exception",
                "reason":"no permissions for [indices:monitor/settings/get] and User [name=operator, backend_roles=[default-roles-lamassu, offline_access, uma_authorization, operator], requestedTenant=null]"
             }
          ],
          "type":"security_exception",
          "reason":"no permissions for [indices:monitor/settings/get] and User [name=operator, backend_roles=[default-roles-lamassu, offline_access, uma_authorization, operator], requestedTenant=null]"
       },
       "status":403
    }
    ```
    10. Kibana will be launched in order to inspect the logs stored in Elastic. Run the following commands to configure kibana:
    ```
    sed -i 's/dev\.lamassu\.io/'$DOMAIN'/g' kibana.yml
    sed -i 's/KIBANA_USERNAME_TO_REPLACE/'$ELASTIC_KIBANA_USERNAME'/g' kibana.yml
    sed -i 's/KIBANA_PASSWORD_TO_REPLACE/'$ELASTIC_KIBANA_PASSWORD'/g' kibana.yml
    sed -i 's/KIBANA_KEYCLOAK_CLIENT_ID_TO_REPLACE/'$KC_KIBANA_CLIENT_SECRET'/g' kibana.yml
    ```
    And run kibana
    ```
    docker-compose up -d kibana
    ```
9. Provision and configure Vault secret engine:
    1. Run Vault: 
    ```
    docker-compose up -d vault
    ``` 
    2. Initalize vault: This process generates vault's unseal keys as well as the root token:
    ```
    docker-compose exec vault vault operator init -key-shares=3 -key-threshold=2 -tls-skip-verify -format=json > vault-credentials.json
    ```
    
    Verify the `vault-credentials.json` file has the expected content. It should be similar to this:
    ```
    {
      "unseal_keys_b64": [
        "a1ps/xdjFuWxbU8ji+JpBzUeGUNH1XiBnwdbkCLn0vQY",
        "LUCvq/JvRlYY6gpDpZUlKC43wJKzaLsLU/Ru/3BVpj17",
        "LiiO4EtfHayKwAXYHVIOlEKTiftOqpoVThW6WCOrbTTs"
      ],
      "unseal_keys_hex": [
        "6b5a6cff176316e5b16d4f238be26907351e194347d578819f075b9022e7d2f418",
        "2d40afabf26f465618ea0a43a59525282e37c092b368bb0b53f46eff7055a63d7b",
        "2e288ee04b5f1dac8ac005d81d520e94429389fb4eaa9a154e15ba5823ab6d34ec"
      ],
      "unseal_shares": 3,
      "unseal_threshold": 2,
      "recovery_keys_b64": [],
      "recovery_keys_hex": [],
      "recovery_keys_shares": 5,
      "recovery_keys_threshold": 3,
      "root_token": "s.X8lNJLvR9KMeOQpujSu6gSDh"
     }
    ```
    
    3. Export the following variables:
    ```
    export VAULT_CA_FILE=$(pwd)/lamassu/vault_certs/vault.crt
    export VAULT_TOKEN=$(cat vault-credentials.json | jq .root_token -r)
    export VAULT_ADDR=https://$DOMAIN:8200
    ```

    4. Unseal Vault using the keys obtained with the previous command:
    ```
    curl --request PUT "$VAULT_ADDR/v1/sys/unseal" -k --header 'Content-Type: application/json' --data-raw "{\"key\": \"$(cat vault-credentials.json | jq -r .unseal_keys_hex[0])\" }"

    curl --request PUT "$VAULT_ADDR/v1/sys/unseal" -k --header 'Content-Type: application/json' --data-raw "{\"key\": \"$(cat vault-credentials.json | jq -r .unseal_keys_hex[1])\" }"
    ```
    
    5. Vault must be provisioned with some resources (authentication methods, policies and secret engines). That can be achieved by running the `ca-provision.sh` script. 

    ```
    cd compose-builder
    ./ca-provision.sh
    ```

    6. Vault will be provisioned with 4 Root CAs, 3 Special CAS (Lamassu-Lamassu-DMS) AppRole authentication method and one role and policy for each service or container that needs to exchange data with it. 
    
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
    Unseal vault 
    ```
    curl --request PUT "$VAULT_ADDR/v1/sys/unseal" -k --header 'Content-Type: application/json' --data-raw "{\"key\": \"$(cat vault-credentials.json | jq -r .unseal_keys_hex[0])\" }"

    curl --request PUT "$VAULT_ADDR/v1/sys/unseal" -k --header 'Content-Type: application/json' --data-raw "{\"key\": \"$(cat vault-credentials.json | jq -r .unseal_keys_hex[1])\" }"
    ```
