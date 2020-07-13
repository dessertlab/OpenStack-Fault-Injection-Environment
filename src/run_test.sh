#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit
fi


SRC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ROOT_DIR=$SRC_DIR"/../"
TESTS_DIR=$SRC_DIR"/tests/"
WORKLOAD_DIR=$SRC_DIR"/workload/"
RESULTS_DIR=$SRC_DIR"/../results/"

function echo_time() {
	date +"%Y-%m-%d %H:%M:%S.%6N  $*"
}

function echo_error(){
	date +"%Y-%m-%d %H:%M:%S.%6N ERROR  $*"
}


function choose_component {
	echo_time "Select a sub-system: " | tee -a $RESULTS_DIR/run_test.log;
	echo "---> Type 1 for Nova, 2 for Cinder, 3 for Neutron:" 
	read choice_component

	if [ $choice_component == 1 ]; then
		component="Nova";
	elif [ $choice_component == 2 ]; then
		component="Cinder";
	elif [ $choice_component == 3 ]; then
		component="Neutron";
	fi
}


function check_component {
	if [ "$component" == "Nova" ] || [ "$component" == "Cinder" ] || [ "$component" == "Neutron" ]; then
		echo_time "You selected $component sub-system" | tee -a $RESULTS_DIR/run_test.log;
	else
		echo_error "Possible choices: Nova, Cinder, Neutron" | tee -a $RESULTS_DIR/run_test.log;
		exit
	fi

}


function choose_test {
	N=$(find $TESTS_DIR/$component/Test_* -maxdepth 0 -type d | wc -l);
	echo_time "Select a test" | tee -a $RESULTS_DIR/run_test.log;
	echo "Type the id of the test you want to reproduce (an integer from 1 to $N):"
	read id;
	test=Test_$id;
}

function check_test {
	ls $TESTS_DIR/$component/$test > /dev/null 2>&1;
	if [ $? -eq 0 ]; then
		echo_time "You selected $test of $component sub-system" | tee -a $RESULTS_DIR/run_test.log;
		echo_time "Info Test:" | tee -a $RESULTS_DIR/run_test.log;
		echo | tee -a $RESULTS_DIR/run_test.log;
		cat $TESTS_DIR/$component/$test/fip_info.data | tee -a $RESULTS_DIR/run_test.log;
		echo | tee -a $RESULTS_DIR/run_test.log;
	else
		N=$(find $TESTS_DIR/$component/Test_* -maxdepth 0 -type d | wc -l)
		echo_error "Does not exist $test of $component sub-system" | tee -a $RESULTS_DIR/run_test.log;
		echo_error "The id for $component sub-system are between 1 and $N." | tee -a $RESULTS_DIR/run_test.log;
		exit
	fi

}

function restore {
	echo_time "Restoring original file..." | tee -a $RESULTS_DIR/run_test.log;
	rm -rf $target
	mv $backup $target
	ls ${target_pyo}".old" > /dev/null 2>&1;
	if [ $? -eq 0 ]; then
		mv ${target_pyo}".old" ${target_pyo};	
	fi
	python -m compileall $target
	echo_time "Restarting system..." | tee -a $RESULTS_DIR/run_test.log;
	$WORKLOAD_DIR/restart_system.sh 2>&1 >> $RESULTS_DIR/run_test.log;
}

function stop_handler {
	trap "kill -9 $PID" SIGINT SIGTERM SIGTSTP
	wait $PID
	ret=$?
	trap "" SIGINT SIGTERM SIGTSTP
	if [ $ret -ne 0 ]; then
		echo_time "Execution interrupted." | tee -a $RESULTS_DIR/run_test.log;
		restore
		exit
	fi

}

rm -rf $RESULTS_DIR/run_test.log > /dev/null 2>&1;
echo
echo_time "This is a script for reproducing fault injection tests in OpenStack!" | tee $RESULTS_DIR/run_test.log;

if [ "$#" -eq 0 ]; then
	choose_component;
	check_component;
	choose_test;
	check_test;
fi


if [ "$#" -eq 1 ]; then
	component=$1
	check_component;
	choose_test;
	check_test;
fi


if [ "$#" -ge 2 ]; then
	component=$1
	check_component;
	test=Test_$2;
	check_test;
fi





path="/usr/lib/python2.7/site-packages/"

echo_time "Default OpenStack installation path is: $path" | tee -a $RESULTS_DIR/run_test.log;

read -r -p "Is OpenStack installed in a different path (press enter for default option) [y/N]:" response
case "$response" in
    [yY][eE][sS]|[yY]) 
        echo "Type the  absolute path where you installed OpenStack: ";
	read path;
	echo_time "You selected the following path: $path" | tee -a $RESULTS_DIR/run_test.log 
        ;;
    *)
        echo_time "You selected the default path!"| tee -a $RESULTS_DIR/run_test.log 
        ;;
esac

#check openstack services in the selected path
echo_time "Checking if the selected path contains the OpenStack sub-systems..." |  tee -a $RESULTS_DIR/run_test.log;

declare -a Services=("nova" "cinder" "neutron" "glance" "heat" "keystone")
for service in ${Services[@]}; do
	ls $path/$service/* > /dev/null 2>&1;
	if [ $? -ne 0 ]; then
		echo_error "The selected path does not contain $service sub-system." |  tee -a $RESULTS_DIR/run_test.log;
		exit
	fi;
done


target="${path}$(cat $TESTS_DIR/$component/$test/fip_info.data | grep "COMPONENT:" | awk -F ": " '{print $2}')"
target_pyo="${target%.*}"
target_pyo="${target_pyo}.pyo"


ls $target  > /dev/null 2>&1;
if [ $? -ne 0 ]; then
	echo_error "$target file does not exist. The current test can not be performed." |  tee -a $RESULTS_DIR/run_test.log;
	exit
fi

ls $TESTS_DIR/$component/$test/mutated_file  > /dev/null 2>&1;
if [ $? -ne 0 ]; then
	echo_error "Mutated file does not exist. The current test can not be performed." |  tee -a $RESULTS_DIR/run_test.log;
	exit
fi

#configure br-ex 
ifconfig br-ex 172.24.4.1 up

#Test folder
echo_time "Creating test folder" | tee -a $RESULTS_DIR/run_test.log

ls $RESULTS_DIR/$component/$test/logs/* > /dev/null 2>&1;
if [ $? -eq 0 ]; then #test already performed
	read -r -p "Test already performed. Are you sure you want to re-exececute it? [y/N]:" response
	case "$response" in
		[yY][eE][sS]|[yY])
		echo_time "Deleting old test..." | tee -a $RESULTS_DIR/run_test.log;;
		*)
		echo_time "Test already performed! Check the test in the directory $RESULTS_DIR/$component/$test" | tee -a $RESULTS_DIR/run_test.log;
		exit;;
	esac
fi

	
rm -rf $RESULTS_DIR/$component/$test > /dev/null 2>&1;
mkdir -p $RESULTS_DIR/$component/$test/logs > /dev/null 2>&1;
if [ $? -ne 0 ]; then
	echo_time "Error during test folder creation!" | tee -a $RESULTS_DIR/run_test.log;
	exit
fi


trap "" SIGINT SIGTERM SIGTSTP

#backup
echo_time "Backup of the target file" |  tee -a $RESULTS_DIR/run_test.log;
backup=$target".old" 
ls $backup > /dev/null 2>&1;
if [ $? -ne 0 ]; then
	mv $target $backup
fi

ls ${target_pyo} > /dev/null 2>&1;
if [ $? -eq 0 ]; then
	mv $target_pyo ${target_pyo}".old"
fi

#cleanup
echo_time "Cleaning up system..." | tee -a $RESULTS_DIR/run_test.log;
$WORKLOAD_DIR/cleanup.sh  2>&1 >> $RESULTS_DIR/run_test.log &
PID=$!
stop_handler
rm -rf $WORKLOAD_DIR/.admin_keystonrc_tempest*
rm -rf $WORKLOAD_DIR/.keystonerc_tempest*
rm -rf $WORKLOAD_DIR/tempest-keypair*


#fault injection
echo_time "Fault injection!" | tee -a $RESULTS_DIR/run_test.log;
cp $TESTS_DIR/$component/$test/mutated_file $target;
python -m compileall $target 2>&1 | tee -a $RESULTS_DIR/run_test.log;

#restart
echo_time "Restarting system..." | tee -a $RESULTS_DIR/run_test.log;
$WORKLOAD_DIR/restart_system.sh 2>&1  >> $RESULTS_DIR/run_test.log &
PID=$!
stop_handler




#flush OpenStack logs
truncate -s 0  /var/log/nova/*.log
truncate -s 0 /var/log/cinder/*.log
truncate -s 0 /var/log/neutron/*.log
truncate -s 0 /var/log/heat/*.log
truncate -s 0 /var/log/keystone/*.log
truncate -s 0 /var/log/glance/*.log



#Workload execution
echo_time "Workload execution..." | tee -a $RESULTS_DIR/run_test.log;
echo_time "The workload execution can last tens of minutes. Please, do not terminate the execution until the completion ..." | tee -a $RESULTS_DIR/run_test.log;
IMAGE_FILE=$WORKLOAD_DIR/"cirros-0.4.0-x86_64-disk.img"; #the image file used during the workload execution
$WORKLOAD_DIR/start_workload.sh $IMAGE_FILE 2>&1 >> $RESULTS_DIR/run_test.log &
PID=$!
stop_handler

echo_time "Workload is completed!" | tee -a $RESULTS_DIR/run_test.log;

#Save OpenStack logs
echo_time "Saving OpenStack logs..." | tee -a $RESULTS_DIR/run_test.log;
for service in ${Services[@]}; do
	mkdir $RESULTS_DIR/$component/$test/logs/$service
	cp -r /var/log/$service/*.log $RESULTS_DIR/$component/$test/logs/$service/
done

unset Services

#Save workload logs
echo_time "Saving workload logs..." | tee -a $RESULTS_DIR/run_test.log;
cp $WORKLOAD_DIR/.workload.out $RESULTS_DIR/$component/$test/logs/workload.out
cp $WORKLOAD_DIR/.workload.err $RESULTS_DIR/$component/$test/logs/workload.err


#Save fip_info.data
cp $TESTS_DIR/$component/$test/fip_info.data $RESULTS_DIR/$component/$test/


echo_time "Restoring original file..." | tee -a $RESULTS_DIR/run_test.log;
rm -rf $target
mv $backup $target
ls ${target_pyo}".old" > /dev/null 2>&1;
if [ $? -eq 0 ]; then
        mv ${target_pyo}".old" ${target_pyo};
fi
python -m compileall $target

# restore

# Second round of execution

echo_time "Second round execution (after fault-removal)" | tee -a $RESULTS_DIR/run_test.log;
mkdir -p $RESULTS_DIR/$component/$test/round_2/logs/

#flush OpenStack logs
truncate -s 0  /var/log/nova/*.log
truncate -s 0 /var/log/cinder/*.log
truncate -s 0 /var/log/neutron/*.log
truncate -s 0 /var/log/heat/*.log
truncate -s 0 /var/log/keystone/*.log
truncate -s 0 /var/log/glance/*.log



#Workload execution
echo_time "Workload execution..." | tee -a $RESULTS_DIR/run_test.log;
echo_time "The workload execution can last tens of minutes. Please, do not terminate the execution until the completion ..." | tee -a $RESULTS_DIR/run_test.log;
#IMAGE_FILE=$WORKLOAD_DIR/"cirros-0.4.0-x86_64-disk.img"; #the image file used during the workload execution
$WORKLOAD_DIR/start_workload.sh $IMAGE_FILE 2>&1 >> $RESULTS_DIR/run_test.log &
PID=$!
stop_handler

echo_time "Workload is completed!" | tee -a $RESULTS_DIR/run_test.log;

#Save OpenStack logs
echo_time "Saving OpenStack logs..." | tee -a $RESULTS_DIR/run_test.log;
for service in ${Services[@]}; do
        mkdir $RESULTS_DIR/$component/$test/round_2/logs/$service
        cp -r /var/log/$service/*.log $RESULTS_DIR/$component/$test/round_2/logs/$service/
done

unset Services


#Save workload logs
echo_time "Saving workload logs..." | tee -a $RESULTS_DIR/run_test.log;
cp $WORKLOAD_DIR/.workload.out $RESULTS_DIR/$component/$test/round_2/logs/workload.out
cp $WORKLOAD_DIR/.workload.err $RESULTS_DIR/$component/$test/round_2/logs/workload.err


#restart
echo_time "Restarting system..." | tee -a $RESULTS_DIR/run_test.log;
$WORKLOAD_DIR/restart_system.sh 2>&1  >> $RESULTS_DIR/run_test.log &
PID=$!
stop_handler


echo_time "Test completed!" | tee -a $RESULTS_DIR/run_test.log;
