# README 

This repository contains a project related to the paper "`How Bad Can a Bug Get? An Empirical Analysis of Software Failures in the OpenStack Cloud Computing Platform`" accepted for presentation at the ESEC-FSE 2019 conference (doi>` 10.1145/3338906.3338916`). 
The project includes tools to repeat the fault-injection experiments presented in the paper.

Please, **cite the following paper** if you use the tools for your research:

```
@inproceedings{cotroneo2019bad,
  title={How bad can a bug get? an empirical analysis of software failures in the OpenStack cloud computing platform},
  author={Cotroneo, Domenico and De Simone, Luigi and Liguori, Pietro and Natella, Roberto and Bidokhti, Nematollah},
  booktitle={Proceedings of the 2019 27th ACM Joint Meeting on European Software Engineering Conference and Symposium on the Foundations of Software Engineering},
  pages={200--211},
  year={2019}
}
```



Please, note that this artifact does not include a fault injection tool since we transferred the ownership of the tool to our industry partners. Therefore, the artifact includes pre-injected source-code files. Before every fault injection test, an original source-code file is replaced with a pre-injected file, and it is restored after the test.



# Project Organization

The diagram below provides the organization of the project:

```
|-- INSTALL.md
|-- LICENSE.md
|-- README.md
|-- data
|   -- Cinder.csv
|   -- Neutron.csv
|   -- Nova.csv
|-- results
|-- src
|   -- install
|       -- check_openstack.py
|       -- install_openstack.sh
|       -- prepare_packstack_config_file.sh
|       -- packstack_configuration_template.txt
|   -- run_test.sh
|   -- statistic.sh
|   -- tests
|       -- Cinder
|       -- Neutron
|       -- Nova
|   -- workload
|       -- cleanup.sh
|       -- restart_system.sh
|       -- start_workload.sh
```

The `data` directory contains the CSV files related to each OpenStack sub-system (i.e., Nova.csv, Cinder.csv, Neutron.csv). Each CSV file describes the all the information about each test case.
Specifically, the CSV files have the following fields:

*  **Test_id**: It is the name of the folder that contains the specific test, where **id** is an increasing number used to differentiate the tests;
*  **Fault_Type**: It is the type of the injected fault from the list described in the paper;
*  **Target_Component**: It is the name of the source code file to be mutated;
*  **Target_Class**: It is the name of the class which contains the mutated statement;
*  **Target_Function**: It is the name of the function which contains the mutated statement;
*  **Fault_Location**: It is the target statement;
*  **Line**: It is the line of the **Fault_Location** in the **Target_Component**.


The `results` directory contains data generated during analysis. 

The `src` directory contains all of the code written for the project, including the scripts needed
for the installation of OpenStack (`src/install` sub-directory; see `INSTALL.md` file), the scripts used to execute the workload (`src/workload` sub-directory) and for analyzing 
the experiments.

The provided fault injection test suite is under `src/tests` directory. The test directory contains every test case sub-directory for each OpenStack sub-system 
(Nova, Cinder, Neutron) targeted during the experimentation provided in the paper. 
Every test case sub-directory contains the following files:
*  **fip_info.data**: It stores information about the fault injected for the specific test;
*  **mutated_file**: It contains the **Target_Component** after the mutation.

