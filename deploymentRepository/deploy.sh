#!/bin/bash

#-------------------------------------------------------------------------------
# Copyright (c) 2019, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#--------------------------------------------------------------------------------

set -o xtrace

OUTPUT_DIR=$4
INPUT_DIR=$2
source $INPUT_DIR/infrastructure.properties

#definitions
SCRIPT=$script
DEPLOYMENT=$deployment
YAML=$yaml
SERVICE=$service

#create yaml files if they are created through a script
function create_yaml() {
    if [ -f $SCRIPT ]
    then
      source $SCRIPT
    else   
      echo "the script not exists"
    fi     
}

function create_randomName() {
    if [ -z $name]
    then 
      echo "The name is not set"
    fi
    NAME="$name$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 5 | head -n 1)"
    echo NAME
}

function create_namespace() {

    create_randomName
    kubectl create namespace $NAME
    kubectl config set-context $(kubectl config current-context) --namespace=$NAME
    kubectl config view | grep namespace:

}

#function to check whether a deployment is functioning properly
function readiness_deployment() {
    #kubectl get pods -n t pod -o jsonpath="{.status.phase}"
    deployment_status=$(kubectl get deployments -n $NAME $DEPLOYMENT -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')
    while [$deployment_status = "False"]
    do 
      sleep5
    done

}

function readiness_service() {

    service_status=$(kubectl describe services $DEPLOYMENT)
}

#create the resources in gke by defining a seperate namespace
function create_resources() {

    if [ -z $YAML ]
    then 
      echo "the yaml file is not created or the yaml file is not available"
    fi
    #create the deployments
    kubectl create -f $YAML
    #check whether the deployment is deployed properly
    #readiness_deployment
    sleep 1m

    if [ -z $DEPLOYMENT ]
    then
      echo "the deployment is not available"
    fi
    if [ -z $SERVICE ]
    then 
      echo "the service is not available"
    fi

    kubectl expose deployment $DEPLOYMENT --name=$DEPLOYMENT  --type=$SERVICE -n $NAME
    sleep 2m
}

#get the details about the endpoints which are needed for scenerio tests.
function get_endPoints() {

    externalIP=$(kubectl describe services $DEPLOYMENT --namespace=$NAME | grep "Ingress:" | cut -b 27-)
    echo externalIP
    echo "externalIP=$externalIP" >> $OUTPUT_DIR/deployment.properties
}

function view_logs() {

    kubectl -n kube-system logs $DEPLOYMENT 
    #-c container-name
    
}


function deploy() {

    create_yaml
    create_namespace
    create_resources
    get_endPoints

}

deploy
