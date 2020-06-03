## 1. Install and run OpenStack on CentOS Linux

We tested this artifact on OpenStack release Pike (version 3.12.1) running on CentOS Linux release 7.6.1810 (Core).
You can run it on an all-in-one OpenStack installation on a CentOS virtual machine.

Since the OpenStack platform includes several services (e.g., Identity, Image service, Compute, Networking, Dashboard, Object storage, etc.), the OpenStack all-in-one installation has high hardware requirements.
Moreover, the experiments produce a large amount of data (logs of the systems, files of the workload execution, etc.). 

Therefore, the **following hardware specifications are recommended**:

- at least 4 physical or virtual CPUs
- at least 16GBs of RAM
- at least 100GBs of HDD

We recommend using a RedHat-based OS, such as CentOS Linux since the Packstack tool has been developed and tested on these systems. 


#### 1.1 Install CentOS Linux

You can download the CentOS Linux release 7.6.1810 [here](http://isoredirect.centos.org/centos/7/isos/x86_64/).
You can install CentOS by following the wizard and by setting the default parameters. For any issues, you can refer to the official installation guide at https://docs.centos.org/en-US/centos/install-guide/.

Alternatively, you can download a virtual disk with a pre-configured CentOS 7.6.1810 installation for VMware or Virtualbox, from: 

**VMware**: https://sourceforge.net/projects/osboxes/files/v/vm/10-Cn-t/7/7-18.10/18-1064.7z/download

**VirtualBox**: https://sourceforge.net/projects/osboxes/files/v/vb/10-C-nt/7/7-18.10/181064.7z/download

To use these pre-configured images, you need to uncompress the 7z archive, create a new virtual machine, set the virtual disk to use the downloaded image, and set the virtual CPUs and RAM (see the hardware requirements). The pre-configured image includes a **root** account with password **osboxes.org**, and a user **osboxes** with password **osboxes.org**.


#### 1.2 Install OpenStack Packstack

In order to install an OpenStack environment in an easy way, you can use **Packstack** (https://www.rdoproject.org/install/packstack/), which is a set of facilities and tools for creating an all-in-one installation.


The Packstack installation guide recommends to disable the *NetworkManager* and *firewalld* services in order not to generate conflicts with OpenStack networking.

```
[user@domain ]$ sudo systemctl disable firewalld
[user@domain ]$ sudo systemctl stop firewalld
[user@domain ]$ sudo systemctl disable NetworkManager
[user@domain ]$ sudo systemctl stop NetworkManager
[user@domain ]$ sudo systemctl enable network
[user@domain ]$ sudo systemctl start network
````


Our script ``install_openstack.sh`` contains commands for automatically installing all dependencies, and for preparing a Packstack configuration file according to the local network configuration.
Assuming that `ARTIFACT_PATH` is the directory in which you unzip the artifact sources, run the following command to create an all-in-one OpenStack environment:

```
[user@domain ]$ cd ARTIFACT_PATH
[user@domain ARTIFACT_PATH]$ sudo ./src/install/install_openstack.sh
```

The OpenStack deployment will take around 20-30 mins, depending on the hardware configuration.
After the installation is complete, the script checks whether the OpenStack environment was successfully deployed.

> **** Installation completed successfully ****** 
>
> Additional information:
>
> 2019-06-04 06:36:12,991.991 412 INFO OpenStack is properly installed!




## 2. Run fault injection test cases

### 2.1 [Optional] Run fault-free execution

Before performing the fault-injection experiments, you can check if the system is able the execute the workload without errors. Thus, you can execute the ``run_ff.sh`` by running the following:

```
[user@domain ARTIFACT_PATH]$ sudo ./src/run_ff.sh
```

This script executes the workload without any injected fault (**fault-free execution**). The logs of the workload during the fault-free execution will be saved in the directory `ARTIFACT_PATH/results/FF` at the end of the script execution.

### 2.2 Run fault-injection experiments

In order to run a single test case, you need to choose both the sub-system name (i.e., Nova, Cinder, Neutron) and the **id** of the test you want to execute. 

You can execute the ``run_test.sh`` script in interactive mode by running the following:

```
[user@domain ARTIFACT_PATH]$ sudo ./src/run_test.sh
```

Otherwise, you can also directly specify the name of sub-system target (`SUBSYSTEM_NAME`) as the first input parameter, and the id of the test being run (`ID`) as the second parameter.

`SUBSYSTEM_NAME` is a string that can assume the following values: "Nova", "Cinder", or "Neutron", while `ID` is an integer that can assume only the values associated with the test cases saved in the CSV file. 

For example, for executing the test 18 against Nova sub-system, run the following:

```
[user@domain ARTIFACT_PATH]$ sudo ./src/run_test.sh Nova 18
```

The ``run_test.sh`` script performs the following steps:

1.  Backup of the target component (see `Target_Component`);
2.  Fault injection (mutation) of the target component by replacing the original file with the **mutated_file** of the selected test;
3.  Restarting the OpenStack services;
4.  Cleaning up the OpenStack resources of any previously executed test;
5.  Execution of the workload (as described in the paper);
6.  Saving the logs of the workload and the OpenStack services;
7.  Restoring the original target component;
8.  Restarting the OpenStack services.

Information about the last execution of the script is saved in the file `ARTIFACT_PATH/results/run_test.log`.

The sub-directory `ARTIFACT_PATH/src/workload/` contains all files and scripts needed by ``run_test.sh`` script to execute the test. 

## 3. Results

The output of a test is saved into `ARTIFACT_PATH/results/SUBSYSTEM_NAME/Test_ID` directory. Such a directory contains:

*   The file `fp_info.data`, which contains information about the fault injected in the experiment.

*   The `logs` subdirectory, which contains the raw logs of the execution of the test case.

In the `logs` subdirectory, there are more subfolders representing all the sub-systems of OpenStack (e.g., "nova", "cinder", "neutron", "glance", etc.) containing the log messages generated during the tests.

For example, the directory `ARTIFACT_PATH/results/Nova/Test_18/logs/cinder` contains the log messages from the Cinder sub-system during the execution of "Test 18", from the fault injection test against the Nova sub-system. 

Furthermore, the `logs` subdirectory contains the log file related to the workload execution, i.e., the `workload.out` and `workload.err` files.
In particular,  `workload.out` contains the log messages of the workload execution, while `workload.err`  contains the error messages during the workload execution, including both API Errors and Assertion Failures, as described in the paper.


The `workload.err` file can be used to understand the effects of the fault-injected during the workload execution.  
An example of the content of such a file is the following: 


> 2019-06-06 06:35:06.461312  Assertion results: FAILURE_INSTANCE_ACTIVE
>
> 2019-06-06 06:37:48.956846  Assertion results: FAILURE_VOLUME_CREATED
>
> 2019-06-06 06:38:06.283922  API ERROR:  openstack server add volume tempest-INSTANCE_SAMPLE-1559816724 tempest-VOLUME_SAMPLE-1559816724 --device /dev/vdb ;
>
>  Cannot 'attach_volume' instance 814d0713-8e68-4229-b5f2-946ca969f52c while it is in vm_state error (HTTP 409) (Request-ID: req-57f567d4-10c5-4e11-a636-56e117ea0f71)

The assertions state that there was a failure during the creations of the instance (`FAILURE_INSTANCE_ACTIVE`) and volume (`FAILURE_VOLUME_CREATED`), however the system raised an error only during the attach 
of the volume (`API ERROR:  openstack server add volume`), about three minutes later the first assertion failure. 

#### 3.1 Statistics of the test cases

After executing the fault injection experiments, you can analyze the experiments by running the script `ARTIFACT_PATH/src/statistic.sh`. 
The script computes the number of experiments in which there is at least one failure occurred during the execution of the workload.
Moreover, the script classifies the failures of the failed experiments into "API Error Only", "Assertion Failure Only" and 
"Assertion failure followed by API Error" (as described in the paper).

To run the script, you need to specify the name of sub-system target ("Nova", "Cinder", or "Neutron") as input parameter. 
For example, in order to analyze all the fault-injection experiments against Nova sub-system, run the following:

```
[user@domain ARTIFACT_PATH]$ sudo ./src/statistic.sh Nova
```


The output of the script is saved in `ARTIFACT_PATH/results/Nova/statistic.txt`.

For example, the output of the script after executing the previous test (i.e., Test_18 against Nova sub-system) is the following:

>  *************** General campaign statistics ***************
>
> Total number of experiments analyzed: 1
>
> Number of experiments without any failure: 0
>
> Number of experiments that experienced at least a failure: 1
>
> --> Number of experiments with assertion and API error: 1
>
> --> Number of experiments with only assertions: 0
>
> --> Number of experiments with only API Error: 0
>
> Assertion failures:
>
>      1 FAILURE_INSTANCE_ACTIVE
>
>      1 FAILURE_VOLUME_CREATED
>
> API Error:
>
>      1  openstack server add volume


Please note that some of the analyses that we performed in the paper (e.g., temporal and spatial propagation, etc.) could not be automated in this artifact since this capability has been implemented in the tool that we transferred to our industry partner. 
Nevertheless, the data produced by this artifact can be used to perform the same analysis.




