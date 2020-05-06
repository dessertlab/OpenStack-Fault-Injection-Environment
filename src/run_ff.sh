#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit
fi


SRC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ROOT_DIR=$SRC_DIR"/../"
WORKLOAD_DIR=$SRC_DIR"/workload/"
RESULTS_DIR=$SRC_DIR"/../results/"
FF=$RESULTS_DIR/FF


function echo_time() {
	date +"%Y-%m-%d %H:%M:%S.%6N  $*"
}

function echo_error(){
	date +"%Y-%m-%d %H:%M:%S.%6N ERROR  $*"
}



echo
echo_time "This script executes the workload without any injected fault."


#configure br-ex 
ifconfig br-ex 172.24.4.1 up


rm -rf $FF > /dev/null 2>&1;
mkdir -p $FF > /dev/null 2>&1;
if [ $? -ne 0 ]; then
	echo_time "Error during folder creation!";
	exit
fi


echo_time "Restarting system...";
$WORKLOAD_DIR/restart_system.sh


#cleanup
echo_time "Cleaning up system...";
$WORKLOAD_DIR/cleanup.sh  



#Workload execution
echo_time "Workload execution..." 
echo_time "The workload execution can last tens of minutes. Please, do not terminate the execution until the completion ..."
IMAGE_FILE=$WORKLOAD_DIR/"cirros-0.4.0-x86_64-disk.img"; #the image file used during the workload execution
$WORKLOAD_DIR/start_workload.sh $IMAGE_FILE 

echo_time "Workload is completed!" 




#Save workload logs
echo_time "Saving workload logs..." 
cp $WORKLOAD_DIR/.workload.out $FF/workload.out
cp $WORKLOAD_DIR/.workload.err $FF/workload.err