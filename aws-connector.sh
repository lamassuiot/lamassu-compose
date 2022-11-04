#!/bin/bash

LAMASSU_AWS_CDK_DEPLOYER_DOCKER_VERSION=latest
LAMASSU_AWS_CONNECTOR_DOCKER_VERSION=latest

BLUE='\033[0;34m'
RED='\033[0;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
NOCOLOR='\033[0m'

while test $# -gt 0; do
  case "$1" in
    --lamassu-compose-path)
      export LAMASSU_COMPOSE_PATH=$2
      shift;;
    --connector-namne)
      export CONNECTOR_NAME=$2
      shift;;
    --aws-access-key-id)
      export AWS_ACCESS_KEY_ID=$2
      shift;;
    --aws-secret-access-key)
      export AWS_SECRET_ACCESS_KEY=$2
      shift;;
    --aws-default-region)
      export AWS_DEFAULT_REGION=$2
      shift;;
    --)
      break;;
     *)
      shift;;
    esac
done

if [[ -z "${LAMASSU_COMPOSE_PATH}" ]]; then
    echo "required option --lamassu-compose-path"
    exit 1
fi

if [[ -z "${CONNECTOR_NAME}" ]]; then
    echo "required option --connector-namne"
    exit 1
fi

if [[ -z "${AWS_ACCESS_KEY_ID}" ]]; then
    echo "required option --aws-access-key-id"
    exit 1
fi

if [[ -z "${AWS_SECRET_ACCESS_KEY}" ]]; then
    echo "required option --aws-secret-access-key"
    exit 1
fi

if [[ -z "${AWS_DEFAULT_REGION}" ]]; then
    echo "required option --aws-default-region"
    exit 1
fi

if [[ -z "${AWS_DEFAULT_REGION}" ]]; then
    echo "required option --aws-default-region"
    exit 1
fi

echo -e "${BLUE}=== Insatlling AWS - Lamassu Connecor ===${NOCOLOR}"

echo -e "${GREEN}Versions:${NOCOLOR}"
echo "LAMASSU_CDK_STACK version:  ${LAMASSU_AWS_CDK_DEPLOYER_DOCKER_VERSION}"
echo "AWS_CONNECTOR version:  ${LAMASSU_AWS_CDK_DEPLOYER_DOCKER_VERSION}"

echo -e "${BLUE}==================================${NOCOLOR}"


echo -e "\n${BLUE}1) Dependencies checking${NOCOLOR}"

function is_command_installed(){
    if ! command -v $1 &> /dev/null
    then
		return 1
    else
        return 0
    fi
}

function exit_if_command_not_installed(){
    is_command_installed $1
    if [ $? -eq 0 ]; then
        echo "✅ $1"
    else
        echo "$1: Not detected. Exiting"
        exit 1
    fi
}

exit_if_command_not_installed docker
exit_if_command_not_installed docker-compose

docker ps > /dev/null
if [ $? -eq 1 ]; then
    echo "Docker might not be executable by this user. Exiting"
    exit 1
fi


echo -e "\n${BLUE}2) Deploying AWS CDK${NOCOLOR}"
docker run \
	-e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
	-e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}  \
	-e AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}  \
	-v /var/run/docker.sock:/var/run/docker.sock \
	lamassuiot/aws-cdk-deployer:${LAMASSU_AWS_CDK_DEPLOYER_DOCKER_VERSION}

echo -e "\n${BLUE}3) Configuring AWS Connector${NOCOLOR}"
cd $LAMASSU_COMPOSE_PATH
ls aws-connector.yml

if [ $? -eq 1 ]; then
    echo "Invalid Lamassu Compose Path. Could not locate aws-connector.yml file"
    exit 1
fi

export LAMASSU_AWS_CONNECTOR_DOCKER_IMAGE=lamassuiot/lamassu-aws-connector-dev:${LAMASSU_AWS_CONNECTOR_DOCKER_VERSION}

#Export .aws-connector.env variables
envsubst < .aws-connector.env | tee .aws-connector.env  > /dev/null

echo -e "\n${BLUE}4) Deploying AWS Connector${NOCOLOR}"
docker-compose -f aws-connector.yml up -d