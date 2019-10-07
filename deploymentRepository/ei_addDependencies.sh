#!/usr/bin/env bash

OUTPUT_DIR=$4

# variables
ACTIVREMQ_RELEASE_NAME="activemq-wso2ei"
ACTIVEMQ_CHART_NAME="activemq-artemis"
RABBITMQ_RELEASE_NAME="rabbitmq-wso2ei"

# adding stable helm charts to the local repository
helm repo add stable https://kubernetes-charts.storage.googleapis.com/

#deploy activemq charts
helm install ${ACTIVREMQ_RELEASE_NAME} ei_backends/${ACTIVEMQ_CHART_NAME}/

#get activemq hostname
activemq_ip=$(kubectl get services "${ACTIVREMQ_RELEASE_NAME}"-"${ACTIVEMQ_CHART_NAME}" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
while [[ -z $activemq_ip ]]
do
  sleep 10
done

#deploy rabbitmq helm charts
helm install "${RABBITMQ_RELEASE_NAME}" stable/rabbitmq

#get rabbitmq hostname
rabbitmq_ip=$(kubectl get services "${RABBITMQ_RELEASE_NAME}" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
while [[ -z $rabbitmq_ip ]]
do
  sleep 10
done

# adding activemq and rabbitmq host-ip's to infrastructure.properties
echo "ActiveMQ_IP_K8s=${activemq_ip}" >> "${OUTPUT_DIR}/infrastructure.properties"
echo "RabbitMQ_IP_k8s=${rabbitmq_ip}" >> "${OUTPUT_DIR}/infrastructure.properties"
