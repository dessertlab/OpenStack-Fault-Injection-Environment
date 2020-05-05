#!/bin/bash


export LC_NUMERIC="en_US.UTF-8"

component=$1  

if [ $# -ne 1 ]; then
    echo
    echo "Usage: ./statistic.sh sub_system_name [Nova|Cinder|Neutron]"
    echo
    exit 
fi


if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit
fi


function check_component {
        if [ "$component" == "Nova" ] || [ "$component" == "Cinder" ] || [ "$component" == "Neutron" ]; then
                echo "You selected $component sub-system"
        else
                echo "Wrong choice. Possible choices: Nova, Cinder, Neutron"
                exit
        fi

}


SRC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
RESULTS_DIR=$(dirname $SRC_DIR)"/results/"
CAMPAIGN=${RESULTS_DIR}/${component}


ls $CAMPAIGN/Test_* > /dev/null 2>&1;
if [ $? -ne 0 ]; then
	echo "There are no experiments in the directory $CAMPAIGN";
	exit
fi

function echo_time() {
        date +"%Y-%m-%d %H:%M:%S.%6N  $*"
}


echo_time "Start analysis."
echo "*************** General campaign statistics ***************" > $CAMPAIGN/statistic.txt


failed=0;
not_failed=0;

api=0;
assertion=0;
assertion_api=0;

N=$(find $CAMPAIGN/Test_* -maxdepth 0 -type d | wc -l);


for test in $CAMPAIGN/Test_*/logs/workload.err; do
	cat $test | grep "Assertion\|API ERROR" > /dev/null 2>&1;
	if [ $? -eq 0 ]; then
		(( failed++ ));
		cat $test | grep "Assertion" > /dev/null 2>&1;
		if [ $? -eq 0 ]; then
			cat $test | grep "API ERROR" > /dev/null 2>&1;
			if [ $? -eq 0 ]; then
				(( assertion_api++ ));
			else	
				(( assertion++ ));
			fi
		else
			(( api++ ));
		fi
		
	else
		(( not_failed++ ));
	fi;	
done



echo "Total number of experiments analyzed: $N " >> $CAMPAIGN/statistic.txt 
echo "Number of experiments without any failure: $not_failed" >> $CAMPAIGN/statistic.txt
echo "Number of experiments that experienced at least a failure: $failed" >> $CAMPAIGN/statistic.txt
echo "--> Number of experiments with assertion and API error: $assertion_api" >> $CAMPAIGN/statistic.txt
echo "--> Number of experiments with only assertions: $assertion" >> $CAMPAIGN/statistic.txt
echo "--> Number of experiments with only API Error: $api" >> $CAMPAIGN/statistic.txt

echo >> $CAMPAIGN/statistic.txt
echo "Assertion failures: " >> $CAMPAIGN/statistic.txt
cat $CAMPAIGN/Test_*/logs/workload.err | grep "Assertion" | awk -F ": " '{print $2}' | sort | uniq -c  >> $CAMPAIGN/statistic.txt


echo >> $CAMPAIGN/statistic.txt
echo "API Error: " >> $CAMPAIGN/statistic.txt
cat $CAMPAIGN/Test_*/logs/workload.err | grep "API ERROR" |  grep -o -P '(?<=API ERROR: ).*(?=;)' | awk -F "--|tempest" '{print $1}' | sort | uniq -c  >> $CAMPAIGN/statistic.txt
echo >> $CAMPAIGN/statistic.txt

echo_time "End analysis. Results are saved into '$CAMPAIGN/statistic.txt' file."
