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

set -e

#installation of database differs accoring to the type of database resource found.
#This function is to deploy the database correctly as found in the test plan.

function helm_deploy(){

  create_value_yaml
  create_gcr_secret
  #install resources using helm
  helmDeployment="wso2product$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 5 | head -n 1)"
  resources_deployment
  helm install $helmDeployment $deploymentRepositoryLocation/deploymentRepository/helm_am/product/ --namespace $namespace


}

# Read a property file to a given associative array
#
# $1 - Property file
# $2 - associative array
# How to call
# declare -A somearray
# read_property_file testplan-props.properties somearray
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

function create_value_yaml(){

file=$INPUT_DIR/infrastructure.properties
declare -g -A infra_props
read_property_file "${INPUT_DIR}/infrastructure.properties" infra_props
dockerAccessUserName=${infra_props["dockerAccessUserName"]}
dockerAccessPassword=${infra_props["dockerAccessPassword"]}
namespace=${infra_props["namespace"]}

DBEngine=${infra_props["DBEngine"]}
OS=${infra_props["OS"]}
JDK=${infra_props["JDK"]}

DB=$(echo $DBEngine | cut -d'-' -f 1  | tr '[:upper:]' '[:lower:]')
OS=$(echo $OS | cut -d'-' -f 1  | tr '[:upper:]' '[:lower:]')
JDK=$(echo $JDK | cut -d'-' -f 1  | tr '[:upper:]' '[:lower:]')

echo "creation of values.yaml file"

cat > values.yaml << EOF
context: "TestGrid"
username: $dockerAccessUserName
password: $dockerAccessPassword
email: $dockerAccessUserName
namespace: $namespace
svcaccount: "wso2svc-account"
dbType: $DB
operatingSystem: $OS
jdkType: $JDK
EOF
echo "testing values.yaml ... "
cat values.yaml

yes | cp -rf $deploymentRepositoryLocation/values.yaml $deploymentRepositoryLocation/deploymentRepository/helm_am/product/
}

function create_gcr_secret(){
  #create secret with gcr authentication
  kubectl create secret docker-registry gcr-wso2creds \
    --docker-server=asia.gcr.io \
    --docker-username=_json_key \
    --docker-password="$(cat $INPUT_DIR/key.json)" \
    --docker-email=$dockerAccessUserName --namespace $namespace
}

function resources_deployment(){


    if [ "$DB" == "mysql" ]
    then
        helm install wso2am-rdbms-service -f $deploymentRepositoryLocation/deploymentRepository/helm_am/mysql/values.yaml stable/mysql --namespace $namespace
        sleep 30s
    fi
    if [ "$DB" == "postgres" ]
    then
        helm install wso2am-rdbms-service -f $deploymentRepositoryLocation/deploymentRepository/helm_am/postgresql/values.yaml stable/postgresql --namespace $namespace
        sleep 30s
    fi
    if [ "$DB" == "mssql" ]
    then
        helm install wso2am-rdbms-service -f $deploymentRepositoryLocation/deploymentRepository/helm_am/mssql/values.yaml stable/mssql-linux --namespace $namespace
        kubectl create -f $deploymentRepositoryLocation/deploymentRepository/helm/jobs/db_provisioner_job.yaml --namespace $namespace
        sleep 30s
    fi

}


helm_deploy
