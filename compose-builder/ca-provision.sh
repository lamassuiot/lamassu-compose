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
set -e

shopt -s nullglob

function provision() {
    set +e
    pushd "$1" > /dev/null
    for f in  *.json; do
        echo $f
        p="$1/${f%.json}"
        c=$(cat $f | envsubst)
        echo "Provisioning $p"
        curl --cacert $VAULT_CA_FILE --header "X-Vault-Token: ${VAULT_TOKEN}" --data "${c}" "${VAULT_ADDR}/v1/${p}"
    done
    popd > /dev/null
    set -e 
}

pushd ca-data > /dev/null

provision sys/auth
provision sys/mounts
provision sys/policy
provision auth/approle/role
provision Lamassu-Root-CA1-RSA4096/roles
provision Lamassu-Root-CA1-RSA4096/root/generate
provision Lamassu-Root-CA2-RSA2048/roles
provision Lamassu-Root-CA2-RSA2048/root/generate
provision Lamassu-Root-CA3-ECC384/roles
provision Lamassu-Root-CA3-ECC384/root/generate
provision Lamassu-Root-CA4-ECC256/roles
provision Lamassu-Root-CA4-ECC256/root/generate
popd > /dev/null




# mounts the pki secrets engine 
curl --cacert $VAULT_CA_FILE --header "X-Vault-Token: ${VAULT_TOKEN}" --data '{"type":"pki"}' "${VAULT_ADDR}/v1/sys/mounts/Lamassu-System-CA"

# Tune the pki secrets engine to issue certificates with a maximum time-to-live (TTL) of 87600 hours
curl --cacert $VAULT_CA_FILE --header "X-Vault-Token: ${VAULT_TOKEN}" --request POST --data '{"max_lease_ttl":"87600h"}' "${VAULT_ADDR}/v1/sys/mounts/Lamassu-System-CA/tune"

# Generate the root certificate and extract the CA certificate and save it as CA_cert.crt
curl --cacert $VAULT_CA_FILE --header "X-Vault-Token: ${VAULT_TOKEN}" --request POST --data '{"common_name": "LamassuCA","ttl": "87600h"}' "${VAULT_ADDR}/v1/Lamassu-System-CA/root/generate/internal" | jq -r ".data.certificate" > CA_cert.crt



### Loop this steps for each intermediate CA
# 
curl --cacert $VAULT_CA_FILE --header "X-Vault-Token: ${VAULT_TOKEN}" --data '{"type":"pki"}' "${VAULT_ADDR}/v1/sys/mounts/Lamassu-DMS"

# Tune the pki secrets engine to issue certificates with a maximum time-to-live (TTL) of 87600 hours
curl --cacert $VAULT_CA_FILE --header "X-Vault-Token: ${VAULT_TOKEN}" --request POST --data '{"max_lease_ttl":"43800h"}' "${VAULT_ADDR}/v1/sys/mounts/Lamassu-DMS/tune"

# generate an intermediate certificate request
curl --cacert $VAULT_CA_FILE --header "X-Vault-Token: ${VAULT_TOKEN}" --request POST --data "${data}" "${VAULT_ADDR}/v1/Lamassu-DMS/intermediate/generate/internal" | jq -r ".data.csr" > DMS.csr

# sign intermediate certificate request
data=$(echo "{"\""csr"\"": "\""$(cat DMS.csr | sed ':a;N;$!ba;s/\n/\\n/g')"\"", "\""format"\"": "\""pem_bundle"\"","\""ttl"\"":"\""43800h"\""}")
echo ${data}
curl --cacert $VAULT_CA_FILE --header "X-Vault-Token: ${VAULT_TOKEN}" --request POST --data "${data}" "${VAULT_ADDR}/v1/Lamassu-System-CA/root/sign-intermediate" | jq -r ".data.certificate" > intermediate-DMS.crt

data=$(echo "{"\""certificate"\"": "\""$(cat intermediate-DMS.crt | sed ':a;N;$!ba;s/\n/\\n/g')"\""}")
echo ${data}
curl --cacert $VAULT_CA_FILE --header "X-Vault-Token: ${VAULT_TOKEN}" --request POST --data "${data}" "${VAULT_ADDR}/v1/Lamassu-DMS/intermediate/set-signed"

curl --cacert $VAULT_CA_FILE --header "X-Vault-Token: ${VAULT_TOKEN}" --request POST --data '{"allow_any_name": true,"ttl": "17520h","max_ttl": "26280h","key_type": "any"}' "${VAULT_ADDR}/v1/Lamassu-DMS/roles/enroller"


# 
curl --cacert $VAULT_CA_FILE --header "X-Vault-Token: ${VAULT_TOKEN}" --data '{"type":"pki"}' "${VAULT_ADDR}/v1/sys/mounts/Lamassu-Services"

# Tune the pki secrets engine to issue certificates with a maximum time-to-live (TTL) of 87600 hours
curl --cacert $VAULT_CA_FILE --header "X-Vault-Token: ${VAULT_TOKEN}" --request POST --data '{"max_lease_ttl":"43800h"}' "${VAULT_ADDR}/v1/sys/mounts/Lamassu-Services/tune"

# generate an intermediate certificate request
curl --cacert $VAULT_CA_FILE --header "X-Vault-Token: ${VAULT_TOKEN}" --request POST --data "${data}" "${VAULT_ADDR}/v1/Lamassu-Services/intermediate/generate/internal" | jq -r ".data.csr" > Services.csr

# sign intermediate certificate request
data=$(echo "{"\""csr"\"": "\""$(cat Services.csr | sed ':a;N;$!ba;s/\n/\\n/g')"\"", "\""format"\"": "\""pem_bundle"\"","\""ttl"\"":"\""43800h"\""}")
echo ${data}
curl --cacert $VAULT_CA_FILE --header "X-Vault-Token: ${VAULT_TOKEN}" --request POST --data "${data}" "${VAULT_ADDR}/v1/Lamassu-System-CA/root/sign-intermediate" | jq -r ".data.certificate" > intermediate-Services.crt

data=$(echo "{"\""certificate"\"": "\""$(cat intermediate-Services.crt | sed ':a;N;$!ba;s/\n/\\n/g')"\""}")
echo ${data}
curl --cacert $VAULT_CA_FILE --header "X-Vault-Token: ${VAULT_TOKEN}" --request POST --data "${data}" "${VAULT_ADDR}/v1/Lamassu-Services/intermediate/set-signed"

curl --cacert $VAULT_CA_FILE --header "X-Vault-Token: ${VAULT_TOKEN}" --request POST --data '{"allow_any_name": true,"ttl": "17520h","max_ttl": "26280h","key_type": "any"}' "${VAULT_ADDR}/v1/Lamassu-Services/roles/enroller"
