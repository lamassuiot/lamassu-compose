#!/bin/bash
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
        curl -k --header "X-Vault-Token: ${VAULT_TOKEN}" --data "${c}" "${VAULT_ADDR}/v1/${p}"
    done
    popd > /dev/null
    set -e 
}

pushd data > /dev/null

provision sys/auth
provision sys/mounts/pki/lamassu/dev/_pki
provision sys/mounts/pki/lamassu/dev/_internal
provision sys/policy
provision auth/approle/role
provision pki/lamassu/dev/_internal/Lamassu-DMS-Enroller/roles
provision pki/lamassu/dev/_internal/Lamassu-DMS-Enroller/root/generate

popd > /dev/null