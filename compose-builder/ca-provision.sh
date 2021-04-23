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
        curl -k --cacert $VAULT_CA_FILE --header "X-Vault-Token: ${VAULT_TOKEN}" --data "${c}" "${VAULT_ADDR}/v1/${p}"
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
