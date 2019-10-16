#!/usr/bin/env bash

set -o xtrace

OUTPUT_DIR=$4
INPUT_DIR=$2

# VFS_PODNAME="my-ftp-76fc745d99-jp976"
# namespace="vfs-dep-test"
# vfsUser="wso2user"
# vfsPWD="FTPUserPassword"

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

file=$INPUT_DIR/infrastructure.properties
declare -g -A infra_props
read_property_file "${INPUT_DIR}/infrastructure.properties" infra_props

vfsUser=${infra_props["FTPUserName"]}
vfsPWD=${infra_props["FTPUserPassword"]}
namespace=${infra_props["namespace"]}

#vsf configfile
conf_vfs="/etc/vsftpd/vsftpd.conf"

kubectl exec -it ${VFS_PODNAME} --namespace $namespace  -- bash -c " \
cp ${conf_vfs} /etc/vsftpd/vsftpd.conf.original; \
sed -i 's/xferlog_std_format=NO/xferlog_std_format=YES/g' ${conf_vfs}; \
echo 'userlist_enable=YES' >> ${conf_vfs}; \
echo 'userlist_file=/etc/vsftpd.userlist' >> ${conf_vfs}; \
echo 'userlist_deny=NO' >> ${conf_vfs}; \
echo 'tcp_wrappers=YES' >> ${conf_vfs}"

pass=$(perl -e 'print crypt($ARGV[0], "password")' $vfsPWD);

kubectl exec -it ${VFS_PODNAME} --namespace $namespace -- bash -c " \
useradd -m -c 'VFS USER' -s /bin/bash -p $pass $vfsUser; \
echo $vfsUser >> /etc/vsftpd.userlist"
