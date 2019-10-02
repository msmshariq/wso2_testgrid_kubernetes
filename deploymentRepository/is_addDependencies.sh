#!/usr/bin/env bash

# deploy helm stable/tomcat/
set -e; set -o xtrace

ProductVersion="5.8.0"
releaseName="wso2is-tomcat-dep"
INPUT_DIR=$2
#namespace="web-app-is"  -- debug --

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

# check if zip tool exists

if [ -z $(which zip) ]; then
  sudo apt-get -y install zip
fi

helm repo add stable https://kubernetes-charts.storage.googleapis.com/
helm repo update

file=$INPUT_DIR/infrastructure.properties
declare -g -A infra_props
read_property_file "${INPUT_DIR}/infrastructure.properties" infra_props
namespace=${infra_props["namespace"]}

# install tomcat helm
helm install ${releaseName} stable/tomcat --namespace $namespace

#travelocity
wget http://maven.wso2.org/nexus/content/repositories/releases/org/wso2/is/org.wso2.sample.is.sso.agent/${ProductVersion}/org.wso2.sample.is.sso.agent-${ProductVersion}.war
unzip org.wso2.sample.is.sso.agent-${ProductVersion}.war -d travelocity.com

#PassiveSTSSampleApp
wget http://maven.wso2.org/nexus/content/repositories/releases/org/wso2/is/PassiveSTSSampleApp/${ProductVersion}/PassiveSTSSampleApp-${ProductVersion}.war
unzip PassiveSTSSampleApp-${ProductVersion}.war -d PassiveSTSSampleApp

mkdir is-app-copy; mv travelocity.com is-app-copy; mv PassiveSTSSampleApp is-app-copy

#get ingres ip
TOMCAT_SVC_NAME=$(kubectl get svc --namespace ${namespace} -o jsonpath='{.items[?(@.metadata.labels.app == "tomcat")].metadata.name}')

while [ -z $(kubectl get svc --namespace ${namespace} ${TOMCAT_SVC_NAME} -o jsonpath='{.status.loadBalancer.ingress[0].ip}') ];
do
  sleep 10;
done

TOMCAT_IP=$(kubectl get svc --namespace ${namespace} ${TOMCAT_SVC_NAME} -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

sed -i 's|https://localhost:9443|https://wso2is:9443|g' is-app-copy/travelocity.com/WEB-INF/classes/travelocity.properties
sed -i 's|SAML2.IdPEntityId=localhost|SAML2.IdPEntityId=wso2is|g' is-app-copy/travelocity.com/WEB-INF/classes/travelocity.properties
sed -i 's|http://localhost:8080|http://'${TOMCAT_IP}':8080|g' is-app-copy/travelocity.com/WEB-INF/classes/travelocity.properties

sed -i 's|https://localhost:9443|https://wso2is:9443|g' is-app-copy/PassiveSTSSampleApp/WEB-INF/web.xml
sed -i 's|http://localhost:8080/PassiveSTSSampleApp/|https://'${TOMCAT_IP}':8080/PassiveSTSSampleApp/|g' is-app-copy/PassiveSTSSampleApp/WEB-INF/web.xml

TOMCAT_POD_NAME=$(kubectl get pods --namespace ${namespace} -o jsonpath='{.items[?(@.metadata.labels.app == "tomcat")].metadata.name}')

kubectl cp is-app-copy/travelocity.com ${namespace}/${TOMCAT_POD_NAME}:/usr/local/tomcat/webapps/
kubectl cp is-app-copy/PassiveSTSSampleApp ${namespace}/${TOMCAT_POD_NAME}:/usr/local/tomcat/webapps/

sh catalina.sh start
