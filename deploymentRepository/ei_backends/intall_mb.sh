#!/usr/bin/env bash

OUTPUT_DIR=$4
INPUT_DIR=$2

# variables
ACTIVREMQ_RELEASE_NAME="activemq-wso2ei"
ACTIVEMQ_CHART_NAME="activemq-artemis"
RABBITMQ_RELEASE_NAME="rabbitmq-wso2ei"


read_property_file() {
    local property_file_path=$1
    # Read configuration into an associative array
    # IFS is the 'internal field separator'. In this case, your file uses '='
    local -n configArray=$2
    IFS="="
    while read -r key value
    do
      [[ -n ${key} ]] && configArray[$key]=$value
    done < ${property_file_path}
    unset IFS
}

file=$INPUT_DIR/infrastructure.properties
declare -g -A infra_props
read_property_file "${INPUT_DIR}/infrastructure.properties" infra_props
namespace=${infra_props["namespace"]}


# adding stable helm charts to the local repository
helm repo add stable https://kubernetes-charts.storage.googleapis.com/

#deploy activemq charts
helm install ${ACTIVREMQ_RELEASE_NAME} ei_backends/${ACTIVEMQ_CHART_NAME}/ --namespace ${namespace}

#get activemq hostname
activemq_ip=$(kubectl get services  --namespace ${namespace} "${ACTIVREMQ_RELEASE_NAME}"-"${ACTIVEMQ_CHART_NAME}" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
while [[ -z $activemq_ip ]]
do
  sleep 10
done

#deploy rabbitmq helm charts
helm install "${RABBITMQ_RELEASE_NAME}" stable/rabbitmq  --namespace ${namespace}

#get rabbitmq hostname
rabbitmq_ip=$(kubectl get services  --namespace ${namespace} "${RABBITMQ_RELEASE_NAME}" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
while [[ -z $rabbitmq_ip ]]
do
  sleep 10
done

# adding activemq and rabbitmq host-ip's to infrastructure.properties
echo "ActiveMqHostname=${activemq_ip}" >> "${INPUT_DIR}/infrastructure.properties"
echo "RabbitMqHostname=${rabbitmq_ip}" >> "${INPUT_DIR}/infrastructure.properties"
