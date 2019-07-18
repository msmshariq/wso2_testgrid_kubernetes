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

source $OUTPUT_DIR/deployment.properties

#installation of database differs accoring to the type of database resource found.
#This function is to deploy the database correctly as found in the test plan.

function helm_deploy(){ 

  create_value_yaml

  #install resources using helm
  helmDeployment="wso2product$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 5 | head -n 1)"
  resources_deployment
  helm install $helmDeployment $deploymentRepositoryLocation/deploymentRepository/helm/product/

  readiness_deployments
}

function create_value_yaml(){

echo $dockerAccessUserName
echo $dockerAccessPassword
echo $namespace

cat > values.yaml << EOF
username: $dockerAccessUserName
password: $dockerAccessPassword
email: $dockerAccessUserName
namespace: $namespace
svcaccount: "wso2svc-account"
dbType: $DBEngine
operatingSystem: $OS
jdkType: $JDK
EOF
yes | cp -rf $deploymentRepositoryLocation/values.yaml $deploymentRepositoryLocation/deploymentRepository/helm/product/
}

function resources_deployment(){

    DB=$(echo $DBEngine | cut -d'-' -f 1  | tr '[:upper:]' '[:lower:]')

    if [ "$DB" == "mysql" ]
    then
        helm install wso2-rdbms-service -f $deploymentRepositoryLocation/deploymentRepository/helm/mysql/values.yaml stable/mysql
    fi
    if [ "$DB" == "postgres" ]
    then
        helm install wso2-rdbms-service -f $deploymentRepositoryLocation/deploymentRepository/helm/postgresql/values.yaml stable/postgresql
    fi
    if [ "$DB" == "mssql" ]
    then
        helm install wso2-rdbms-service -f $deploymentRepositoryLocation/deploymentRepository/helm/mssql/values.yaml stable/mssql-linux
        kubectl create -f $deploymentRepositoryLocation/deploymentRepository/helm/jobs/db_provisioner_job.yaml --namespace $namespace
    fi

}

function readiness_deployments(){
    start=`date +%s`
    i=0;
    # todo add a terminal condition/timeout.
    for ((i=0; i<$dep_num; i++)) ; do
      num_true=0;
      while [ "$num_true" -eq "0" ] ; do
        sleep 5
        deployment_status=$(kubectl get deployments -n $namespace ${dep[$i]} -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')
        if [ "$deployment_status" == "True" ] ; then
          num_true=1;
        fi
      done
    done

    end=`date +%s`
    runtime=$((end-start))
    echo "Deployment \"${dep}\" got ready in ${runtime} seconds."
    echo
}

helm_deploy
