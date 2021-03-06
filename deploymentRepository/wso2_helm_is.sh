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

set -e; set -o xtrace

#installation of database differs accoring to the type of database resource found.
#This function is to deploy the database correctly as found in the test plan.

function helm_deploy(){

  create_value_yaml
  create_gcr_secret
  #install resources using helm
  helmDeployment="wso2product$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 5 | head -n 1)"
  change_k8sContext
  resources_deployment
  helm install $helmDeployment $deploymentRepositoryLocation/deploymentRepository/helm_is/product/

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

loadBalancerHostName=wso2am-$(($RANDOM % 10000)).gke.wso2testgrid.com
echo "loadBalancerHostName=$loadBalancerHostName" >> ${OUTPUT_DIR}/deployment.properties

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
hostname: $loadBalancerHostName
EOF
echo "testing values.yaml ... "
cat values.yaml

yes | cp -rf $deploymentRepositoryLocation/values.yaml $deploymentRepositoryLocation/deploymentRepository/helm_is/product/
}

function create_gcr_secret(){
  #create secret with gcr authentication
  kubectl create secret docker-registry gcr-wso2creds \
    --docker-server=asia.gcr.io \
    --docker-username=_json_key \
    --docker-password="$(cat $INPUT_DIR/key.json)" \
    --docker-email=$dockerAccessUserName --namespace $namespace
}

function change_k8sContext(){
  if [[ ! -d ${HOME}/.kube/configfiles ]]; then
    mkdir ${HOME}/.kube/configfiles
  fi
  mkdir ${HOME}/.kube/configfiles/dir-${namespace}
  # copying the original config (.kube/config)
  cp ${HOME}/.kube/config ${HOME}/.kube/configfiles/dir-${namespace}/
  # Modifying namespace of new config-file
  kubectl config set-context $(kubectl config current-context) --kubeconfig ${HOME}/.kube/configfiles/dir-${namespace}/config --namespace ${namespace}
  # Modifying $KUBECONFIG environment variable
  export KUBECONFIG=${HOME}/.kube/configfiles/dir-${namespace}/config

  #  TO DO: remove created directory for kubeconfig ($HOME/.kube/configfiles/dir-$namespace)
}

function resources_deployment(){

    helm repo add stable https://kubernetes-charts.storage.googleapis.com/
    helm repo update

    if [ "$DB" == "mysql" ]
    then
        helm install wso2is-rdbms-service -f $deploymentRepositoryLocation/deploymentRepository/helm_is/mysql/values.yaml stable/mysql
        sleep 30s
    fi
    if [ "$DB" == "postgres" ]
    then
        helm install wso2is-rdbms-service -f $deploymentRepositoryLocation/deploymentRepository/helm_is/postgresql/values.yaml stable/postgresql
        sleep 30s
    fi
    if [ "$DB" == "mssql" ]
    then
        helm install wso2is-rdbms-service -f $deploymentRepositoryLocation/deploymentRepository/helm_is/mssql/values.yaml stable/mssql-linux
        kubectl create -f $deploymentRepositoryLocation/deploymentRepository/helm_is/jobs/db_provisioner_job.yaml
        sleep 30s
    fi

}


helm_deploy
