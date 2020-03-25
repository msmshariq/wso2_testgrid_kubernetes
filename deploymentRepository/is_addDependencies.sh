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
helm repo add bitnami https://charts.bitnami.com
helm repo update

file=$INPUT_DIR/infrastructure.properties
declare -g -A infra_props
read_property_file "${INPUT_DIR}/infrastructure.properties" infra_props
namespace=${infra_props["namespace"]}

deployment_prop_file=$INPUT_DIR/deployment.properties
declare -g -A deployment_props
read_property_file "${deployment_prop_file}" deployment_props
ISHttpsUrl=${deployment_props["ISHttpsUrl"]}
loadBalancerHostName=${deployment_props["loadBalancerHostName"]}

# install tomcat helm
#helm install ${releaseName} stable/tomcat --namespace $namespace

helm install ${releaseName} --set resources.requests.memory=2Gi --set resources.requests.cpu=1024m bitnami/tomcat --namespace $namespace
# --version 2.1.0

#travelocity
wget http://maven.wso2.org/nexus/content/repositories/releases/org/wso2/is/org.wso2.sample.is.sso.agent/${ProductVersion}/org.wso2.sample.is.sso.agent-${ProductVersion}.war
unzip org.wso2.sample.is.sso.agent-${ProductVersion}.war -d travelocity.com
rm org.wso2.sample.is.sso.agent-${ProductVersion}.war

#PassiveSTSSampleApp
wget http://maven.wso2.org/nexus/content/repositories/releases/org/wso2/is/PassiveSTSSampleApp/${ProductVersion}/PassiveSTSSampleApp-${ProductVersion}.war
unzip PassiveSTSSampleApp-${ProductVersion}.war -d PassiveSTSSampleApp
rm PassiveSTSSampleApp-${ProductVersion}.war


#get ingres ip
TOMCAT_SVC_NAME=$(kubectl get svc --namespace ${namespace} -o jsonpath='{.items[?(@.metadata.labels.app == "tomcat")].metadata.name}')

while [ -z $(kubectl get svc --namespace ${namespace} ${TOMCAT_SVC_NAME} -o jsonpath='{.status.loadBalancer.ingress[0].ip}') ];
do
  sleep 10;
done

TOMCAT_IP=$(kubectl get svc --namespace ${namespace} ${TOMCAT_SVC_NAME} -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "ISSamplesHttpUrl=http://$TOMCAT_IP:80" >> ${INPUT_DIR}/deployment.properties

sed -i 's|https://localhost:9443|'${ISHttpsUrl}'|g' travelocity.com/WEB-INF/classes/travelocity.properties
sed -i 's|SAML2.IdPEntityId=localhost|SAML2.IdPEntityId='${loadBalancerHostName}'|g' travelocity.com/WEB-INF/classes/travelocity.properties
sed -i 's|http://localhost:8080|http://'${TOMCAT_IP}':80|g' travelocity.com/WEB-INF/classes/travelocity.properties

sed -i 's|https://localhost:9443|'${ISHttpsUrl}'|g' PassiveSTSSampleApp/WEB-INF/web.xml
sed -i 's|http://localhost:8080/PassiveSTSSampleApp/|http://'${TOMCAT_IP}':80/PassiveSTSSampleApp/index.jsp|g' PassiveSTSSampleApp/WEB-INF/web.xml

TOMCAT_POD_NAME=$(kubectl get pods --namespace ${namespace} -o jsonpath='{.items[?(@.metadata.labels.app == "tomcat")].metadata.name}')

cd travelocity.com ; zip -r ../travelocity.com.war ./* ; cd ../ ;
kubectl cp travelocity.com.war ${namespace}/${TOMCAT_POD_NAME}:/opt/bitnami/tomcat/webapps/

cd PassiveSTSSampleApp ; zip -r ../PassiveSTSSampleApp.war ./* ; cd ../ ;
kubectl cp PassiveSTSSampleApp.war ${namespace}/${TOMCAT_POD_NAME}:/opt/bitnami/tomcat/webapps/

#kubectl exec -it ${TOMCAT_POD_NAME} --namespace ${namespace} -- bash -c "sh bin/catalina.sh start"
