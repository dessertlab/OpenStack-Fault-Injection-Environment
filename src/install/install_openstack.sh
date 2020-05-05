#!/bin/bash

SRC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
openstack_env_ok_file=${SRC_DIR}/".openstack_env_ok"

echo_time() {
      date +"%Y-%m-%d %H:%M:%S.%3N $*"
}

function check_openstack_installation {

  echo_time "Check if OpenStack env is deployed..."

  python ${SRC_DIR}/check_openstack.py

  if [ $? -ne 0 ]; then
      echo_time "WARNING OpenStack is not properly installed!"

  elif [ ! -f "${openstack_env_ok_file}" ]; then

      touch ${openstack_env_ok_file}
      exit 0

  fi

}


if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit
fi

export LANG=en_US.utf-8
export LC_ALL=en_US.utf-8

rm -rf ${openstack_env_ok_file}

check_openstack_installation

#cleanup older files for installation

echo_time "Remove old packstack_configuration.txt"
rm -rf ${SRC_DIR}/packstack_configuration.txt

#install packstack and openstack related tools

echo_time "Install packstack and openstack related tools"

yum install -y centos-release-openstack-pike > /dev/null
sleep 1
yum install -y openstack-packstack > /dev/null
sleep 1
yum install -y openstack-utils > /dev/null
sleep 1

#prepare packsta config file

echo_time "Prepare packstack configuration file"
${SRC_DIR}/prepare_packstack_config_file.sh

# call packstack utility

echo_time "Start packstack deployment"
packstack --debug --answer-file=${SRC_DIR}/packstack_configuration.txt

check_openstack_installation
