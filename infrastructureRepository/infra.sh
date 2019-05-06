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

echo "I got these parameters from testplan-props.properties:"

INPUT_DIR=$2
source $INPUT_DIR/testplan-props.properties

#definitions
KEY_FILE_LOCATION=$accessKeyFileLocation
SERVICE_ACCOUNT="gke-bot@testgrid.iam.gserviceaccount.com"
CLUSTER_NAME="chathurangi-test-cluster"
ZONE="us-central1-a"
PROJECT_NAME="testgrid" 

#functions

function check_tools() {

    echo "Please enable google cluster API, if not enabled."

    if ! type 'kubectl'
    then
       echo "Please install Kubernetes command-line tool (kubectl) before you start with the setup\n"
    fi

    if ! type 'gcloud'
    then
       echo "Please install gcloud - google cloud command line tool before you start with the setup\n"
    fi

}

function auth() {

    if [[ ! $KEY_FILE_LOCATION ]]
    then
        echo "credential file for authentication not found"
    fi

    #authentication access to the google cloud
    gcloud auth activate-service-account --key-file=${KEY_FILE_LOCATION}

    #service account setup
    gcloud config set account $SERVICE_ACCOUNT

    #access the cluster
    gcloud container clusters get-credentials $CLUSTER_NAME --zone $ZONE --project $PROJECT_NAME

}


function infra_creation() {

    check_tools
    auth

}

infra_creation

