#!/bin/bash
#cd "$(dirname "$0")"

################ START CONFIGURATION PARAMETERS ######################

IMAGE_FILE=$1
ls $IMAGE_FILE > /dev/null 2>&1;
if [ $? -ne 0 ]; then
	echo "Image file used in the workload not found."
	echo "Exit workload execution."
	exit
fi 


WL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"


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

admin_keystonrc_file_name=".admin_keystonrc_tempest-"$timestamp

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

echo "${admin_keystonrc_file_content}" > $WL_DIR/${admin_keystonrc_file_name}


#assume that admin credential are in /root dir
#source ${KEYSTONE_ADMIN_FILE_path}"/"${KEYSTONE_ADMIN_FILE}
source $WL_DIR/${admin_keystonrc_file_name}

#out and err files
STD_ERR_FILE=$WL_DIR"/.workload.err"
STD_OUT_FILE=$WL_DIR"/.workload.out"


function echo_time() {
    date +"%Y-%m-%d %H:%M:%S.%6N  $*"
}

function predate(){
	while read line ; do
    		echo_time "${line}"
	done
}

# LAUNCH AND CHECK CONFIGURATION 
function launch_and_check_pipe(){
  echo "[START] ${@}" | predate >> ${STD_OUT_FILE}
  $@ 1>$WL_DIR/.stdout 2>$WL_DIR/.stderr
  cat $WL_DIR/.stdout | tee >> ${STD_OUT_FILE} | echo "$(cat $WL_DIR/.stdout)"
  cat $WL_DIR/.stderr | predate >> ${STD_OUT_FILE}
  if [ $(cat $WL_DIR/.stderr | wc -l) -ne 0 ]; then
	cat $WL_DIR/.stderr | grep "deprecated" >/dev/null 2>&1
	if [ $? -ne 0 ]; then
	        echo "API ERROR: " ${@} ";" $(cat $WL_DIR/.stderr) | predate >> ${STD_ERR_FILE}
        	exit
	fi
  fi
  echo "[END] ${@}" | predate >> ${STD_OUT_FILE}
}

function launch_and_check(){
  echo "[START] ${@}" | predate >> ${STD_OUT_FILE}
  $@ 1>$WL_DIR/.stdout 2>$WL_DIR/.stderr
  cat $WL_DIR/.stdout >> ${STD_OUT_FILE}
  cat $WL_DIR/.stderr | predate >> ${STD_OUT_FILE}
  if [  $(cat $WL_DIR/.stderr | wc -l) -ne 0 ]; then
	cat $WL_DIR/.stderr | grep "deprecated" >/dev/null 2>&1
	if [ $? -ne 0 ]; then  		
        	echo "API ERROR: " ${@} ";" $(cat $WL_DIR/.stderr) | predate >> ${STD_ERR_FILE}
        	exit 
	fi
  fi
  echo "[END] ${@}" | predate >> ${STD_OUT_FILE}
}

# Config parameters
IMAGE_NAME="tempest-cirros-0.4.0-x86_64-"$timestamp

KEY_NAME="tempest-keypair-"$timestamp
SECURITY_GROUP_NAME="tempest-SECURITY_GROUP_SAMPLE-"$timestamp

INSTANCE_NAME="tempest-INSTANCE_SAMPLE-"$timestamp

VOLUME_NAME="tempest-VOLUME_SAMPLE-"$timestamp
VOLUME_SIZE=1
AVAILABILITY_ZONE="nova"

#by default 'public' is the name of external network
PUBLIC_NETWORK_NAME="public"

PRIVATE_NETWORK_NAME="tempest-private-"$timestamp

#create new domain, project, user, role about that workload
DOMAIN_NAME="tempest-domain-"$timestamp
PROJECT_NAME="tempest-project-"$timestamp
USER_NAME="tempest-user-"$timestamp
USER_PWD=${USER_NAME}
ROLE_NAME="tempest-role-"$timestamp

launch_and_check "openstack domain create ${DOMAIN_NAME}"
launch_and_check "openstack project create --domain ${DOMAIN_NAME} ${PROJECT_NAME}"
launch_and_check "openstack user create --domain ${DOMAIN_NAME} --password ${USER_PWD} ${USER_NAME}"
launch_and_check "openstack role add --project ${PROJECT_NAME} --user ${USER_NAME} admin"

#create keystonrc file to be used

keystonrc_file_name=".keystonerc_tempest-"$timestamp

IFS='' read -r -d '' keystonrc_file_content <<EOF
unset OS_SERVICE_TOKEN
export OS_USERNAME=${USER_NAME}
export OS_PASSWORD='${USER_PWD}'
export OS_AUTH_URL=http://localhost:5000/v3
export PS1='[\u@\h \W(keystone_${USER_NAME})]\$ '
export OS_PROJECT_NAME=${PROJECT_NAME}
export OS_USER_DOMAIN_NAME=${DOMAIN_NAME}
export OS_PROJECT_DOMAIN_NAME=${DOMAIN_NAME}
export OS_IDENTITY_API_VERSION=3
EOF

echo "${keystonrc_file_content}" > $WL_DIR/${keystonrc_file_name}

source $WL_DIR/${keystonrc_file_name}

existent_subnet_ip=$(launch_and_check_pipe "openstack subnet list" |grep -v tempest |sed 's/|//g'|awk '$0 !~ "+" && NR>3{print $4}'|awk -F. '{print $1}'|while read ip; do echo -n $ip" "; done)
#echo "existent_subnet_ip ${existent_subnet_ip}"
array=($existent_subnet_ip)

#check if generate subnet already exists
ip_1_digit=10
for ip in ${!array[*]}; do
    cur_ip=${array[$ip]}
    #echo "cur_ip= $cur_ip"
    if [ $cur_ip -eq $ip_1_digit ]; then
            let "ip_1_digit=ip_1_digit+1"
    fi
done

ip_2_digit=$(perl -le '$,=".";print map int rand 253,1..1')

header_subnet=${ip_1_digit}"."${ip_2_digit}

PRIVATE_SUBNET_RANGE=${header_subnet}".1.0/24"
PRIVATE_SUBNET_NAME="tempest-private-subnet-"$timestamp
PRIVATE_SUBNET_GATEWAY=${header_subnet}".1.1"

ROUTER_NAME="tempest-router-"$timestamp


################ END CONFIGURATION PARAMETERS ######################

assert(){

    E_ASSERT_FAILED=99

    if [ -z "$1" ]; then
        return $E_PARAM_ERR   #  No damage done.
    fi
    
    if [ $1 -ne 0 ]; then

            if [ "$2" == "image_active" ]; then
                    echo_time "Assertion results: FAILURE_IMAGE_ACTIVE" >> ${STD_ERR_FILE}

            elif [ "$2" == "instance_active" ]; then
                    echo_time "Assertion results: FAILURE_INSTANCE_ACTIVE" >> ${STD_ERR_FILE}

            elif [ "$2" == "ssh" ]; then
                    echo_time "Assertion results: FAILURE_SSH" >> ${STD_ERR_FILE}

            elif [ "$2" == "keypair" ]; then
                    echo_time "Assertion results: FAILURE_KEYPAIR" >> ${STD_ERR_FILE}

            elif [ "$2" == "security_group" ]; then
                    echo_time "Assertion results: FAILURE_SECURITY_GROUP" >> ${STD_ERR_FILE}

            elif [ "$2" == "volume_created" ]; then
                    echo_time "Assertion results: FAILURE_VOLUME_CREATED" >> ${STD_ERR_FILE}

            elif [ "$2" == "volume_attached" ]; then
                    echo_time "Assertion results: FAILURE_VOLUME_ATTACHED" >> ${STD_ERR_FILE}

            elif [ "$2" == "floating_ip_created" ]; then
                    echo_time "Assertion results: FAILURE_FLOATING_IP_CREATED" >> ${STD_ERR_FILE}
	    
            elif [ "$2" == "net_active" ]; then
                    echo_time "Assertion results: FAILURE_PRIVATE_NETWORK_ACTIVE" >> ${STD_ERR_FILE}

            elif [ "$2" == "subnet_created" ]; then
                    echo_time "Assertion results: FAILURE_PRIVATE_SUBNET_CREATED" >> ${STD_ERR_FILE}

            elif [ "$2" == "router_active" ]; then
                    echo_time "Assertion results: FAILURE_ROUTER_ACTIVE" >> ${STD_ERR_FILE}

            elif [ "$2" == "router_interface_created" ]; then
                    echo_time "Assertion results: FAILURE_ROUTER_INTERFACE_CREATED" >> ${STD_ERR_FILE}

            elif [ "$2" == "floating_ip_added" ]; then
                    echo_time "Assertion results: FAILURE_FLOATING_IP_ADDED" >> ${STD_ERR_FILE}

            fi

            echo_time "Failure!!!" >> ${STD_OUT_FILE}
            echo "1"
            #exit $E_ASSERT_FAILED
    else
  
            echo "0"
    fi
}



check_image_creation(){

        status=1
	wait_time=60


        sleep ${wait_time}
	openstack image list | grep ${IMAGE_NAME} | sed 's/|//g'|awk '{print $NF}'|grep "active" > /dev/null 2>&1
	status=$?

        ret_assert=$(assert $status "image_active")
        if [ ${ret_assert} -eq 0 ]; then
            echo_time "${IMAGE_NAME} image is ACTIVE...great!" >> $STD_OUT_FILE
        fi

}

check_keypair_creation(){

        status=1
	wait_time=60

        sleep ${wait_time}
	openstack keypair list | grep ${KEY_NAME} > /dev/null 2>&1
        status=$?

        ret_assert=$(assert $status "keypair")
        if [ ${ret_assert} -eq 0 ]; then
            echo_time "${KEY_NAME} key-pair was created successfully...great!" >> $STD_OUT_FILE
        fi

}

check_security_group(){

    	status=1
	wait_time=60

        sleep ${wait_time}
	openstack security group list | grep ${SECURITY_GROUP_NAME} > /dev/null 2>&1
	status=$?

        ret_assert=$(assert $status "security_group")
        if [ ${ret_assert} -eq 0 ]; then
            echo_time "${SECURITY_GROUP_NAME} security group was created successfully...great!" >> $STD_OUT_FILE
        fi

}

check_private_network_active(){
	status=1
	wait_time=60
	private_net_status="unknown"
        sleep ${wait_time}
	private_net_status=$(openstack network show ${PRIVATE_NETWORK_NAME}|grep "status"|sed 's/|//g'|awk '{print $2}')

	echo ${private_net_status} | grep "ACTIVE" > /dev/null 2>&1
	status=$?

        ret_assert=$(assert $status "net_active")
        if [ ${ret_assert} -eq 0 ]; then
            echo_time "${PRIVATE_NETWORK_NAME} network is ACTIVE...great!" >> $STD_OUT_FILE
        fi
}

create_and_check_private_subnet(){

	status=1

	openstack subnet list | grep ${PRIVATE_SUBNET_NAME}  >/dev/null 2>&1
	status=$?

        ret_assert=$(assert $status "subnet_created")
        if [ ${ret_assert} -eq 0 ]; then
	    echo_time "${PRIVATE_SUBNET_NAME} private subnet is created...great!" >> $STD_OUT_FILE
        fi
}

check_router_active(){
	status=1
	wait_time=60
	router_status="unknown"

   	sleep ${wait_time}

	router_status=$(openstack router show ${ROUTER_NAME} | grep "status" | sed 's/|//g' | awk '{print $2}')

	echo ${router_status} | grep "ACTIVE" > /dev/null 2>&1
	status=$?

        ret_assert=$(assert $status "router_active")
        if [ ${ret_assert} -eq 0 ]; then
            echo_time "${ROUTER_NAME} router is ACTIVE...great!" >> $STD_OUT_FILE
        fi
}

create_and_check_router_port(){
        
	status=1
	
	router_interface_cmd_result=$(launch_and_check_pipe "openstack router add subnet ${ROUTER_NAME} ${PRIVATE_SUBNET_NAME}")
	status=$?

        ret_assert=$(assert $status "router_interface_created")
        if [ ${ret_assert} -eq 0 ]; then
            echo_time "${router_port} was added to ${ROUTER_NAME}...great!" >> $STD_OUT_FILE
        fi
}



check_active_instance(){
	status=1
	wait_time=120
	instance_status="unknown"

    	sleep ${wait_time}
	instance_status=$(nova show ${INSTANCE_NAME} |grep status|awk '{print $4}')

	echo ${instance_status} | grep "ACTIVE" > /dev/null 2>&1
	status=$?


        ret_assert=$(assert $status "instance_active")
        if [ ${ret_assert} -eq 0 ]; then
            echo_time "${INSTANCE_NAME} instance is ACTIVE...great!" >> $STD_OUT_FILE
        fi
}

check_volume_creation(){

    	status=1
	wait_time=60
	volume_status="unknown"

 	sleep ${wait_time}
	volume_status=$(openstack volume list|grep "${VOLUME_NAME}" | sed 's/|//g' | awk '{print $3}')

	echo ${volume_status} | grep "available" > /dev/null 2>&1
	status=$?


        ret_assert=$(assert $status "volume_created")
        if [ ${ret_assert} -eq 0 ]; then
            echo_time "${VOLUME_NAME} volume status is 'available'...great!" >> $STD_OUT_FILE
        fi

}

check_volume_attaching(){

        status=1
	wait_time=60
        volume_attached_status="unknown"

        sleep ${wait_time}
        volume_attached_status=$(openstack volume list|grep "${VOLUME_NAME}"| sed 's/|//g' | awk '{print $5}')

	echo ${volume_attached_status} | grep "Attached" > /dev/null 2>&1
	status=$?

        ret_assert=$(assert $status "volume_attached")
        if [ ${ret_assert} -eq 0 ]; then
            echo_time "${VOLUME_NAME} volume status is 'attached'...great!" >> $STD_OUT_FILE
        fi

}

create_and_check_floating_ip_creation(){

	WORKLOAD_FLOATING_IP=""; 
	status=1;

	WORKLOAD_FLOATING_IP=$(launch_and_check_pipe "openstack floating ip create --project ${PROJECT_NAME} ${PUBLIC_NETWORK_NAME}" | grep -w "floating_ip_address"| awk -F "|" '{print $3}'|tr -d '\040\011\012\015')
	status=$?

        ret_assert=$(assert $status "floating_ip_created")
        if [ ${ret_assert} -eq 0 ]; then
            echo_time "Created floating IP ${WORKLOAD_FLOATING_IP}...great!" >> $STD_OUT_FILE
        fi
}

add_and_check_floating_ip(){

	wait_time=60
	status=1;
	
    	sleep ${wait_time}
	launch_and_check "openstack ip floating add ${WORKLOAD_FLOATING_IP} ${INSTANCE_NAME}"
	status=$?

        ret_assert=$(assert $status "floating_ip_added")
        if [ ${ret_assert} -eq 0 ]; then
            echo_time "Added floating IP ${WORKLOAD_FLOATING_IP} to instance ${INSTANCE_NAME}...great!" >> $STD_OUT_FILE
        fi
}



check_ssh(){
	status=1
	max_retry=10
	wait_time=120

	sleep ${wait_time}	
	ssh -i $WL_DIR/${KEY_NAME}.key cirros@${WORKLOAD_FLOATING_IP} -o 'UserKnownHostsFile=/dev/null' -o 'StrictHostKeyChecking=no' -o 'BatchMode=yes' -o 'ConnectionAttempts=1' true >> $STD_OUT_FILE 2>&1
	status=$?


        ret_assert=$(assert $status "ssh")
        if [ ${ret_assert} -eq 0 ]; then
            echo_time "${INSTANCE_NAME} instance ssh successfully...great!" >> $STD_OUT_FILE
        fi
}

echo_time "Remove old log file for workload..."
rm -rf $WL_DIR/workload*


echo_time "Create new log file for workload..."
#flush log file
> $STD_ERR_FILE
> $STD_OUT_FILE



#    Steps:
#    1. Create image
#    2. Create keypair
#    3. Boot instance with keypair and get list of instances
#    4. Create volume and show list of volumes
#    5. Attach volume to instance and getlist of volumes
#    6. Add IP to instance
#    7. Create and add security group to instance
#    8. Check SSH connection to instance
#    9. Reboot instance
#    10. Check SSH connection to instance after reboot

echo_time "Workload started!" >> $STD_OUT_FILE

#source /root/keystonerc_admin
#source ${KEYSTONE_ADMIN_FILE_path}"/"${KEYSTONE_ADMIN_FILE}
source $WL_DIR/${admin_keystonrc_file_name}

# Create image

echo_time "Create image ${IMAGE_NAME}..." >> $STD_OUT_FILE
launch_and_check "openstack image create --public --disk-format qcow2 --container-format bare --file ${IMAGE_FILE} $IMAGE_NAME"

####
check_image_creation
####

#source /root/keystonerc_demo
source $WL_DIR/${keystonrc_file_name}

# Create keypair

echo_time "Create keypair ${KEY_NAME}..." >> $STD_OUT_FILE

ssh-keygen -b 2048 -t rsa -f $WL_DIR/${KEY_NAME}.key -q -N ""

launch_and_check "openstack keypair create --public-key $WL_DIR/${KEY_NAME}.key.pub ${KEY_NAME}"

####
check_keypair_creation
####

# Boot instance with keypair and get list of instances and
# Create and add security group to instance

echo_time "Create security group with SSH enabled" >> $STD_OUT_FILE
launch_and_check "openstack security group create ${SECURITY_GROUP_NAME}"
launch_and_check "openstack security group rule create --proto tcp --dst-port 22 ${SECURITY_GROUP_NAME}"

####
check_security_group
####

### create private network and subnet... the instance will be created using those one.

source $WL_DIR/${admin_keystonrc_file_name}

launch_and_check "openstack network set --external public"

source $WL_DIR/${keystonrc_file_name}

launch_and_check "openstack network create ${PRIVATE_NETWORK_NAME}"

###
check_private_network_active
###

echo_time "Create subnet '${PRIVATE_SUBNET_NAME}' on network '${PRIVATE_NETWORK_NAME}' with range '${PRIVATE_SUBNET_RANGE}'..." >> $STD_OUT_FILE

launch_and_check "openstack subnet create --subnet-range ${PRIVATE_SUBNET_RANGE} --network ${PRIVATE_NETWORK_NAME} --dns-nameserver 8.8.4.4 ${PRIVATE_SUBNET_NAME}"
###
create_and_check_private_subnet
###

# Create router to test network connections

echo_time "Create router ${ROUTER_NAME} for instance ${INSTANCE_NAME}..." >> $STD_OUT_FILE

#neutron router-create ${ROUTER_NAME}
launch_and_check "openstack router create ${ROUTER_NAME}"

###
check_router_active
###

###
create_and_check_router_port
###

launch_and_check "neutron router-gateway-set ${ROUTER_NAME} ${PUBLIC_NETWORK_NAME}"

#### Create instance

echo_time "Create instance ${INSTANCE_NAME} and boot it."  >> $STD_OUT_FILE
echo_time "" >> $STD_OUT_FILE
echo_time "Details: " >> $STD_OUT_FILE
echo_time "........image name = ${IMAGE_NAME}" >> $STD_OUT_FILE
echo_time "........network = ${PRIVATE_NETWORK_NAME}" >> $STD_OUT_FILE
echo_time "........security group = ${SECURITY_GROUP_NAME}" >> $STD_OUT_FILE
echo_time "........key name = ${KEY_NAME}" >> $STD_OUT_FILE

launch_and_check "openstack server create --flavor m1.tiny --image ${IMAGE_NAME} --nic net-id=${PRIVATE_NETWORK_NAME} --security-group ${SECURITY_GROUP_NAME} --key-name ${KEY_NAME} ${INSTANCE_NAME}"

######
check_active_instance
#####

# Add IP to instance
echo_time "Create floating ip for instance ${INSTANCE_NAME}..." >> $STD_OUT_FILE

source $WL_DIR/${admin_keystonrc_file_name}

####
create_and_check_floating_ip_creation
####

source $WL_DIR/${keystonrc_file_name}

echo_time "Add floating IP ${WORKLOAD_FLOATING_IP} to instance ${INSTANCE_NAME}..." >> $STD_OUT_FILE

####
add_and_check_floating_ip
####


echo_time "List all instances on tenants..." >> $STD_OUT_FILE
launch_and_check "nova list"

# Create volume and show list of volumes

echo_time "Create volume ${VOLUME_NAME}..." >> $STD_OUT_FILE
launch_and_check "openstack volume create --image ${IMAGE_NAME} --size ${VOLUME_SIZE} --availability-zone ${AVAILABILITY_ZONE} ${VOLUME_NAME}"

####
check_volume_creation
###

echo_time "Show volume list..." >> $STD_OUT_FILE
launch_and_check "openstack volume list"

# Attach volume to instance and getlist of volumes
echo_time "Attach volume ${VOLUME_NAME} to ${INSTANCE_NAME}..." >> $STD_OUT_FILE
launch_and_check "openstack server add volume ${INSTANCE_NAME} ${VOLUME_NAME} --device /dev/vdb"

####
check_volume_attaching
###

echo_time "Show volume list..." >> $STD_OUT_FILE
launch_and_check "openstack volume list"

# Check SSH connection to instance

echo_time "Check SSH connection for instance ${INSTANCE_NAME} (before reboot)" >> $STD_OUT_FILE

#####
check_ssh
#####

# reboot instance and check again ssh connection
echo_time "Reboot instance ${INSTANCE_NAME}" >> $STD_OUT_FILE
launch_and_check "openstack server reboot --hard ${INSTANCE_NAME}"

###
check_active_instance
###

echo_time "Check SSH connection for instance ${INSTANCE_NAME} (after reboot)" >> $STD_OUT_FILE

#####
check_ssh
#####

### If there is no failed assertions 
echo_time "Assertion results: OK" >> $STD_OUT_FILE


echo_time "Start resources cleanup" >> $STD_OUT_FILE

source $WL_DIR/${keystonrc_file_name}

launch_and_check "openstack ip floating delete ${WORKLOAD_FLOATING_IP}"
echo_time "Removed floating ip ${WORKLOAD_FLOATING_IP}" >> $STD_OUT_FILE

source $WL_DIR/${admin_keystonrc_file_name}

INSTANCE_DELETE=$(launch_and_check_pipe "nova list --all-tenant" |grep -i "${INSTANCE_NAME}"|awk '{print $2}')
launch_and_check "nova delete ${INSTANCE_DELETE}"
echo_time "Cleaned tempest created instance ${INSTANCE_NAME}" >> $STD_OUT_FILE

IMAGE_DELETE=$(launch_and_check_pipe "openstack image list" |grep "${IMAGE_NAME}"|awk '{print $2}')
launch_and_check "openstack image delete ${IMAGE_DELETE}"
echo_time "Cleaned tempest created images ${IMAGE_NAME}" >> $STD_OUT_FILE

VOLUME_DELETE=$(launch_and_check_pipe "cinder list --all-tenant" |grep -i "${VOLUME_NAME}"|awk '{print $2}')
launch_and_check "cinder delete ${VOLUME_DELETE}"
echo_time "Cleaned tempest created volumes ${VOLUME_NAME}" >> $STD_OUT_FILE



echo_time "Clean tempest created routers and networks..." >> $STD_OUT_FILE
ROUTERS=${ROUTER_NAME}
NETWORKS=${PRIVATE_NETWORK_NAME}

for ROUTER in $ROUTERS; do
        launch_and_check "openstack router unset --external-gateway $ROUTER"
        for PORT in $(launch_and_check_pipe "openstack port list --router $ROUTER --format=value -c ID"); do
                launch_and_check "openstack router remove port $ROUTER $PORT"
                echo_time "Removed port $PORT on router $ROUTER" >> $STD_OUT_FILE
        done
        launch_and_check "openstack router delete $ROUTER"
        echo_time "Removed router $ROUTER" >> $STD_OUT_FILE
done

for NETWORK in $NETWORKS; do
        for PORT in $(launch_and_check_pipe "openstack port list --network $NETWORK --format=value -c ID"); do
                launch_and_check "openstack port delete $PORT"
                echo_time "Removed port $PORT" >> $STD_OUT_FILE
        done
        launch_and_check "openstack network delete $NETWORK"
        echo_time "Removed network $NETWORK" >> $STD_OUT_FILE 2>&1
done

#remove security group
launch_and_check "openstack security group delete ${SECURITY_GROUP_NAME}"
echo_time "Removed security group ${SECURITY_GROUP_NAME}" >> $STD_OUT_FILE

#delete tempest-keypair keypair
source $WL_DIR/${keystonrc_file_name}

launch_and_check "openstack keypair delete ${KEY_NAME}"

rm -rf $WL_DIR/${KEY_NAME}.key
rm -rf $WL_DIR/${KEY_NAME}.key.pub

echo_time "Removed keypair ${KEY_NAME}" >> $STD_OUT_FILE

# delete create domain, user, project, role
source $WL_DIR/${admin_keystonrc_file_name}

launch_and_check "openstack user delete ${USER_NAME}"
echo_time "Removed user ${USER_NAME}" >> $STD_OUT_FILE

launch_and_check "openstack project delete ${PROJECT_NAME}"
echo_time "Removed project ${PROJECT_NAME}" >> $STD_OUT_FILE

launch_and_check "openstack domain set --disable ${DOMAIN_NAME}"
echo_time "Disabled domain ${DOMAIN_NAME}" >> $STD_OUT_FILE

launch_and_check "openstack domain delete ${DOMAIN_NAME}"
echo_time "Removed domain ${DOMAIN_NAME}" >> $STD_OUT_FILE

#remove credential files for user and admin
rm -rf $WL_DIR/${keystonrc_file_name}
rm -rf $WL_DIR/${admin_keystonrc_file_name}

echo_time "End resources cleanup" >> $STD_OUT_FILE

echo_time "Workload terminated!" >> $STD_OUT_FILE
exit 0
