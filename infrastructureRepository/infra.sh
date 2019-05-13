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

ClusterName=""
INPUT_DIR=$2
OUTPUT_DIR=$4
source $INPUT_DIR/testplan-props.properties

#definitions
KEY_FILE_LOCATION=$accessKeyFileLocation

if [ -z $ClusterName ]
then
    SERVICE_ACCOUNT="gke-bot@testgrid.iam.gserviceaccount.com"
    CLUSTER_NAME="chathurangi-test-cluster"
    ZONE="us-central1-a"
    PROJECT_NAME="testgrid" 
fi
#TODO
#functions

function check_tools() {
    echo "Please enable google cluster API, if not enabled."
    if ! type 'kubectl'
    then
        echo "Please install Kubernetes command-line tool (kubectl) before you start with the setup\n"
        exit
    fi
    if ! type 'gcloud'
    then
        echo "Please install gcloud - google cloud command line tool before you start with the setup\n"
        exit
    fi
}

function create_key(){

    if [[ ! $KEY_FILE_LOCATION ]]
    then
        echo "credential file for authentication not found"
        exit 1
    fi
   `echo ${KEY_FILE_LOCATION} | base64 --decode` >> $INPUT_DIR/key.json

}

function auth() {

     #authentication access to the google cloud
    gcloud auth activate-service-account --key-file=$INPUT_DIR/key.json

    #service account setup
    gcloud config set account $SERVICE_ACCOUNT

    #access the cluster
    gcloud container clusters get-credentials $CLUSTER_NAME --zone $ZONE --project $PROJECT_NAME

    rm $INPUT_DIR/key.json
}

function create_randomName() {
    if [ -z $name ]
    then 
      echo "The name is not set"
    fi
    NAME="$name$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 5 | head -n 1)"
    echo $NAME
}

function create_namespace() {
    create_randomName
    kubectl create namespace $NAME
    kubectl config set-context $(kubectl config current-context) --namespace=$NAME
    kubectl config view | grep namespace:
}

function set_properties() {
    echo "namespace=$NAME" >> $OUTPUT_DIR/infrastructure.properties
    echo "randomPort=True">> $OUTPUT_DIR/infrastructure.properties
}

function infra_creation() {
    check_tools
    create_key
    auth
    create_namespace
    set_properties
}

infra_creation

