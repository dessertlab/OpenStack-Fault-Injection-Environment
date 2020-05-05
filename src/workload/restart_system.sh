#!/bin/bash

## openstack's services to be restarted


# NOVA
# openstack-nova-compute.service - OpenStack Nova Compute Server
# openstack-nova-conductor.service - OpenStack Nova Conductor Server
# openstack-nova-scheduler.service - OpenStack Nova Scheduler Server
# openstack-nova-novncproxy.service - OpenStack Nova NoVNC Proxy Server
# openstack-nova-consoleauth.service - OpenStack Nova VNC console auth Server
# openstack-nova-xvpvncproxy.service - OpenStack Nova XVP VncProxy Server
# openstack-nova-api.service - OpenStack Nova API Server
# openstack-nova-console.service - OpenStack Nova Console Proxy Server

# NEUTRON
# neutron-openvswitch-agent.service - OpenStack Neutron Open vSwitch Agent
# neutron-server.service - OpenStack Neutron Server
# neutron-dhcp-agent.service - OpenStack Neutron DHCP Agent
# neutron-metadata-agent.service - OpenStack Neutron Metadata Agent
# neutron-ovs-cleanup.service - OpenStack Neutron Open vSwitch Cleanup Utility
# neutron-metering-agent.service - OpenStack Neutron Metering Agent
# neutron-l3-agent.service - OpenStack Neutron Layer 3 Agent


function echo_time() {
    date +"%Y-%m-%d %H:%M:%S.%6N  $*"
}

################ START CONFIGURATION PARAMETERS ######################

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


restart_services_classic(){
     arr_name=$1[@]
     service_array=("${!arr_name}")

     for service in "${service_array[@]}"
     do
        echo_time "Check service $service... "
        status=$(systemctl status $service | grep Active| awk '{print $2" "$3}')
        i=0
        while [ "$status" != "active (running)" ]; do
            echo -n "*"
            sleep 3
            status=$(systemctl status $service | grep Active| awk '{print $2" "$3}')
            let "i=i+1"

            if [ $i -eq 10 ]; then
                echo_time "Try to restart again service $service"
                systemctl start $service
            fi
        done
        echo_time "Service $service check is done!!!"
     done
}



restart_services(){
	service=$1
	
	echo_time "Restart service ${service}..."

	echo_time "Check service $service... "
	status=$(systemctl status $service | grep Active| awk '{print $2" "$3}')
	i=0
	while [ "$status" != "active" ]; do
		echo -n "*"
		sleep 3
		status=$(systemctl status $service | grep Active| awk '{print $2}')
		let "i=i+1"
		if [ $i -eq 10 ]; then
			echo_time "Try to restart again service $service"
			systemctl start $service
		fi
	done
	echo_time "Service $service check is done!!!"
}

#check if openstack-service command exists

hash openstack-service 2> /dev/null

if [ $? -eq 0 ]; then

    echo_time "Start restarting RabbitMQ"

    rabbitmqctl stop_app
    rabbitmqctl reset

    rabbitmqctl start_app
    systemctl restart rabbitmq-server

    restart_services "rabbitmq-server"

    echo_time "End restarting RabbitMQ"

    echo_time "Start restarting all openstack services... (openstack-service utils)"

    service_list=$(openstack-service list | grep -v -E "swift|gnocchi|aodh|ceilometer")

    openstack-service list | grep -v -E "swift|gnocchi|aodh|ceilometer" | xargs systemctl restart

    for service in ${service_list[@]}; do
            restart_services $service
    done

    # restart also httpd
    systemctl restart httpd
    restart_services "httpd"


    echo_time "End restarting all openstack services... (openstack-service utils)"
else
    #normal restart

    echo_time "Start restarting RabbitMQ"

    rabbitmqctl stop_app
    rabbitmqctl reset

    rabbitmqctl start_app
    systemctl restart rabbitmq-server

    declare -a rabbitmq_services=("rabbitmq-server")

    restart_services_classic rabbitmq_services

    echo_time "End restarting RabbitMQ"

    echo_time "Start restarting all openstack services..."

    echo_time "Restart all nova services..."
    systemctl restart openstack-nova-*

    declare -a nova_services=("openstack-nova-conductor.service"
      "openstack-nova-scheduler.service"
      "openstack-nova-novncproxy.service"
      "openstack-nova-consoleauth.service"
      "openstack-nova-xvpvncproxy.service"
      "openstack-nova-api.service"
      "openstack-nova-compute.service"
      "openstack-nova-console.service"
      )

    restart_services_classic nova_services



    echo_time "Restart all neutron services..."
    systemctl restart neutron-*

    declare -a neutron_services=("neutron-openvswitch-agent.service"
        "neutron-server.service"
        "neutron-dhcp-agent.service"
        "neutron-metadata-agent.service"
         "neutron-l3-agent.service"
        )

    restart_services_classic neutron_services

    echo_time "Restart all keystone services (apache web server)..."

    systemctl restart httpd

    declare -a keystone_services=("httpd")

    restart_services_classic keystone_services

    echo_time "Restart all glance services..."

    systemctl restart openstack-glance-*

    declare -a glance_services=("openstack-glance-registry.service"
        "openstack-glance-api.service")

    restart_services_classic glance_services


    echo_time "Restart all cinder services..."

    systemctl restart openstack-cinder-*

    declare -a cinder_services=("openstack-cinder-api.service"
        "openstack-cinder-volume.service"
        "openstack-cinder-scheduler.service"
        )

    restart_services_classic cinder_services

    echo_time "End restarting all openstack services..."



fi

# Check for RabbitMQ cluster status

rabbitmq_status=$(rabbitmqctl cluster_status| grep partitions|awk -F "," '{print $2}'|cut -d "[" -f2 | cut -d "]" -f1)
if [ -n "$rabbitmq_status" ]; then 
	echo_time "RabbitMQ cluster status is not consistent" 
	exit 1
else
	echo_time "RabbitMQ cluster status is OK!"
	exit 0
fi

exit 0
