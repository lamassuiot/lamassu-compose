#!/bin/bash

DOCKERHUB_REPO="lamassuiot"

function get_latest_tag() {
    curl -s -L --fail "https://hub.docker.com/v2/repositories/${DOCKERHUB_REPO}/$1/tags/?page_size=1000" | \
        jq '.results | .[] | .name' -r | \
        sed 's/latest//' | \
        sort --version-sort | \
        tail -n 1 

}

LAMASSU_GATEWAY_DOCKER_TAG=$(get_latest_tag lamassu-gateway)
echo "LAMASSU_GATEWAY_DOCKER_TAG=$LAMASSU_GATEWAY_DOCKER_TAG"

LAMASSU_UI_DOCKER_TAG=$(get_latest_tag lamassu-ui)
echo "LAMASSU_UI_DOCKER_TAG=$LAMASSU_UI_DOCKER_TAG"

LAMASSU_DB_DOCKER_TAG=$(get_latest_tag lamassu-db)
echo "LAMASSU_DB_DOCKER_TAG=$LAMASSU_DB_DOCKER_TAG"

LAMASSU_AUTH_DOCKER_TAG=$(get_latest_tag lamassu-auth)
echo "LAMASSU_AUTH_DOCKER_TAG=$LAMASSU_AUTH_DOCKER_TAG"

LAMASSU_CA_DOCKER_TAG=$(get_latest_tag lamassu-ca)
echo "LAMASSU_CA_DOCKER_TAG=$LAMASSU_CA_DOCKER_TAG"

LAMASSU_DMS_ENROLLER_DOCKER_TAG=$(get_latest_tag lamassu-dms-enroller)
echo "LAMASSU_DMS_ENROLLER_DOCKER_TAG=$LAMASSU_DMS_ENROLLER_DOCKER_TAG"

LAMASSU_DEVICE_MANAGER_DOCKER_TAG=$(get_latest_tag lamassu-device-manager)
echo "LAMASSU_DEVICE_MANAGER_DOCKER_TAG=$LAMASSU_DEVICE_MANAGER_DOCKER_TAG"

LAMASSU_RABBITMQ_DOCKER_TAG=$(get_latest_tag lamassu-rabbitmq)
echo "LAMASSU_RABBITMQ_DOCKER_TAG=$LAMASSU_RABBITMQ_DOCKER_TAG"