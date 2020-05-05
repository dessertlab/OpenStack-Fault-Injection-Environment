#!/bin/bash

echo_time() {
        date +"%Y-%m-%d %H:%M:%S.%3N $*"
}

if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit
fi

#found local IP
SRC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

ip route get 1 > /dev/null 2>&1

#check if Local IP existis
if [ $? -ne 0 ]; then

    echo_time "No routable IP found! Can not continue with OpenStack deployment."
    exit -1
fi


LOCAL_IP=$(ip route get 1 | awk '{print $NF;exit}')


echo_time "Local IP: $LOCAL_IP"


sed "s/LOCALHOST/${LOCAL_IP}/g" ${SRC_DIR}/packstack_configuration_template.txt > ${SRC_DIR}/packstack_configuration.txt
