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


#definitions
OUTPUT_DIR=$4
INPUT_DIR=$2
source $INPUT_DIR/infrastructure.properties

TEST="test1"
SCRIPT=$script
DEPLOYMENT="pod"
YAML=$yaml
END_POINT=$end_point

#create yaml files if they are created through a script
function create_yaml() {
    if [ -f $SCRIPT ]
    then
      source $SCRIPT
    else   
      echo "$file_name not exists"
    fi     
}

function create_randomName() {

    NAME="$name$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 5 | head -n 1)"
    echo NAME
}

function create_namespace() {

    create_randomName
    kubectl create namespace $NAME
    sleep 20
    kubectl config set-context $(kubectl config current-context) --namespace=$NAME
    kubectl config view | grep namespace:

}

#function to check whether a deployment is functioning properly
function readiness_deployment() {
    #kubectl get pods -n t pod -o jsonpath="{.status.phase}"
    deployment_status=$(kubectl get deployments -n $NAME $DEPLOYMENT -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')
    while [! $deployment_status]
    do 
      sleep5
    done

}

#create the resources in gke by defining a seperate namespace
function create_resources() {

    #create the deployments
    kubectl create -f $YAML
    readiness_deployment
    kubectl expose deployment $DEPLOYMENT --name=$DEPLOYMENT  --type=LoadBalancer -n $NAME

}

#get the details about the endpoints which are needed for scenerio tests.
function get_endPoints() {

    LOAD_BALANCER=$(kubectl describe services $END_POINT --namespace=$NAME | grep "Ingress:" | cut -b 27-)
    echo LOAD_BALANCER
    echo "LOAD_BALANCER=$LOAD_BALANCER" >> $OUTPUT_DIR/deployment.properties
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
