#!/bin/bash

function echo_time() {
    date +"%Y-%m-%d %H:%M:%S.%6N  $*"
}

#get timestamp
timestamp=$(date +"%s")


if [ -z "$ADMIN_NAME" ]; then
    ADMIN_NAME="admin"
fi

if [ -z "$ADMIN_PWD" ]; then
    ADMIN_PWD="admin"
fi

if [ -z "$ADMIN_PROJECT_NAME" ]; then
    ADMIN_PROJECT_NAME="admin"
fi

if [ -z "$ADMIN_DOMAIN_NAME" ]; then
    ADMIN_DOMAIN_NAME="Default"
fi

admin_keystonrc_file_name="admin_keystonrc_tempest-"$timestamp

IFS='' read -r -d '' admin_keystonrc_file_content <<EOF
unset OS_SERVICE_TOKEN
export OS_USERNAME=${ADMIN_NAME}
export OS_PASSWORD='${ADMIN_PWD}'
export OS_AUTH_URL=http://localhost:5000/v3
export PS1='[\u@\h \W(keystone_${ADMIN_NAME})]\$ '
export OS_PROJECT_NAME=${ADMIN_PROJECT_NAME}
export OS_USER_DOMAIN_NAME=${ADMIN_DOMAIN_NAME}
export OS_PROJECT_DOMAIN_NAME=${ADMIN_DOMAIN_NAME}
export OS_IDENTITY_API_VERSION=3
EOF

echo "${admin_keystonrc_file_content}" > /tmp/${admin_keystonrc_file_name}

source /tmp/${admin_keystonrc_file_name}


#remove generated private and public keys
rm -rf /tmp/tempest-keypair*key*

#get floating ip linked to instance

openstack server list|grep "tempest" | awk '{print $8}'|awk -F"=" '{print $2}'|sed 's/,//g'|while read float_ip; do instance_float_ip=$(openstack ip floating list|grep ${float_ip}|awk '{print $2}'); openstack ip floating delete ${instance_float_ip}; echo_time "Removed floating ip ${instance_float_ip}"; done


echo_time "Clean tempest created instance..."
nova list --all-tenant|grep -i "tempest"|awk '{print $2}'|xargs nova delete 2> /dev/null

#remove created tempest users, roles, projects, and images

openstack user list|grep tempest|awk '{print $2}'|xargs openstack user delete 2> /dev/null
echo_time "Clean tempest created users..."

openstack role list|grep tempest|awk '{print $2}'|xargs openstack role delete 2> /dev/null
echo_time "Clean tempest created roles..."

openstack project list|grep tempest|awk '{print $2}'|xargs openstack project delete 2> /dev/null
echo_time "Clean tempest created projects..."

openstack image list|grep tempest|awk '{print $2}'|xargs openstack image delete 2> /dev/null
echo_time "Clean tempest created images..."

openstack domain list|grep tempest|awk '{print $2}'|xargs openstack domain set --disable 2> /dev/null
echo_time "Disabled tempest created domains..."

openstack domain list|grep tempest|awk '{print $2}'|xargs openstack domain delete 2> /dev/null
echo_time "Deleted tempest created domains..."

cinder list --all-tenant|grep -i "tempest"|awk '{print $2}'|xargs cinder delete 2> /dev/null
echo_time "Clean tempest created volumes..."

echo_time "Clean tempest created routers and networks..."
ROUTERS=$(openstack router list --format=value -c Name | grep -i "tempest" | sort)
NETWORKS=$(openstack network list --format=value -c Name | grep -i "tempest" | sort)

for ROUTER in $ROUTERS; do
        openstack router unset --external-gateway $ROUTER
        for PORT in $(openstack port list --router $ROUTER --format=value -c ID); do
                openstack router remove port $ROUTER $PORT
		echo_time "Removed port $PORT on router $ROUTER"
        done
        openstack router delete $ROUTER
	echo_time "Removed router $ROUTER"
done

for NETWORK in $NETWORKS; do
        for PORT in $(openstack port list --network $NETWORK --format=value -c ID); do
                openstack port delete $PORT
		echo_time "Removed port $PORT"
        done
        #wait $(jobs -p)
        openstack network delete $NETWORK
	echo_time "Removed network $NETWORK"
done


#remove security group
openstack security group list | grep tempest| awk '{print $2}'| while read sec; do openstack security group delete $sec; echo_time "Removed security group $sec"; done;
echo_time "Removed security groups related to previous test"

#delete tempest-keypair keypair
#source /root/keystonerc_demo

openstack keypair list|grep tempest| awk '{print $2}'|while read keypair; do openstack keypair delete $keypair; echo_time "Removed keypair $keypair"; done;
echo_time "Removed key-pair tempest-keypair related to previous test"

#remove credential files for user and admin
rm -rf /tmp/keystonerc_tempest-*
rm -rf /tmp/admin_keystonrc_tempest-*

echo_time "Start destroying all qemu domains..."
virsh list --all --uuid|xargs virsh destroy > /dev/null 2>&1;
echo_time "End destroying all qemu domains"

echo_time "Start undefining all qemu domains..."
virsh list --inactive | grep instance |awk '{print $2}'|xargs virsh undefine > /dev/null 2>&1;
echo_time "End undefining all qemu domains"

exit 0
