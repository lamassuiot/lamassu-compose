#!/bin/bash
curl https://consul.dev-lamassu.zpd.ikerlan.es/v1/health/service/cloud-connector?dc=lamassu-dc -k | jq -c -r .[].Service.ID | while read object; do
     echo "ID [$object]"
     curl --request PUT https://consul.dev-lamassu.zpd.ikerlan.es/v1/agent/service/deregister/$object -k
#    api_call "$object"
done



#for i in "${connector_ids[@]}"
#do
#	echo "ID [$i]"
#     curl --request PUT https://consul.dev-lamassu.zpd.ikerlan.es/v1/agent/service/deregister/$i -k
#done
