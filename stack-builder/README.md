# stack-builder

## Overview

Stack-builder is a set of scripts that are intended to be used with openstack-installer. Given openstack credentials, stack-builder will create the appropriate resources on the given cloud to test a scenario described by openstack-installer, and will install openstack using the specified scenario.

## Installation

These instructions are copied almost directly from the jenkins job:

    curl -O https://pypi.python.org/packages/source/v/virtualenv/virtualenv-1.10.1.tar.gz
    tar xvfz virtualenv-1.10.1.tar.gz
    cd virtualenv-1.10.1
    python virtualenv.py test
    cd test
    source bin/activate
    pip install python-novaclient==2.14.1
    pip install python-quantumclient==2.2.3
    pip install PyYaml

    source /home/jenkins-slave/installer_credentials/openrc

    git clone "https://github.com/CiscoSystems/openstack-installer"

    cd openstack-installer

    export PATH=`pwd`/stack-builder/bin:$PATH
    export PYTHONPATH=`pwd`/stack-builder:$PYTHONPATH

    export osi_user_internal_ip='%{ipaddress_eth1}'
    export osi_user_tunnel_ip='%{ipaddress_eth1}'

    export osi_conf_initial_ntp=ntp.esl.cisco.com
    export osi_conf_installer_repo=CiscoSystems
    export osi_conf_installer_branch=master
    export osi_conf_operatingsystem=Ubuntu
    export osi_conf_build_server_domain_name=domain.name

## Commands

For all commands, the data path refers to the data directory in openstack-installer, and defaults to './data', while the fragment path refers to the location of the bash snippets used to composed cloud-init scripts, and defaults to './stack-builder/fragments'. Current the only supported image is ubuntu and defaults to 'precise-x86\_64'.

### Make

    usage: sb make [-h] [-i IMAGE] [-c CI_SUBNET_INDEX] [-s SCENARIO] [-p DATA_PATH] [-f FRAGMENT_PATH] [-d]
    optional arguments:
      -h, --help            show this help message and exit
      -i IMAGE, --image IMAGE
                            name of image to use
      -s SCENARIO, --scenario SCENARIO
                            Scenario to run
      -p DATA_PATH, --data_path DATA_PATH
                            Path to the data directory containing yaml config
      -f FRAGMENT_PATH, --fragment_path FRAGMENT_PATH
                            Path to config fragments
      -d, --debug           print debug output

Creates a cluster based on the given scenario.

example:

    >sb make
    18dbb77039754173b68d9deabbb88505

### Get

    usage: sb get [-h] [-t TEST_ID]

    optional arguments:
      -h, --help            show this help message and exit
      -t TEST_ID, --test_id TEST_ID
                            id of the test to get

Gets info on all running clusters, or if -t is used, gets info on a single cluster.

example:

    >sb get -t 18dbb77039754173b68d9deabbb88505
    Test ID: 18dbb77039754173b68d9deabbb88505
    9d8112ab compute-server02  10.123.0.24
    c9873ca9   control-server  10.123.0.23
    97c17070            cache  10.123.0.22
    b8eb5fde     build-server   10.123.0.2

### Kill

    usage: sb kill [-h] [-t TEST_ID]

    optional arguments:
      -h, --help            show this help message and exit
      -t TEST_ID, --test_id TEST_ID
                            id of the test to kill

Destroys resources created by the test tool, except the shared resources: the external router and the ci network. If -t is used it will only destroy resources associated with the specified test id.

    >sb kill -t 18dbb77039754173b68d9deabbb88505
    Deleting instance 9d8112ab-1312-427c-b9e8-9f9231c9cc0e from test 18dbb77039754173b68d9deabbb88505
    Deleting instance c9873ca9-ce70-4159-968c-9cadac3b322c from test 18dbb77039754173b68d9deabbb88505
    Deleting instance 97c17070-bec2-46b2-8fa4-11354fda28a3 from test 18dbb77039754173b68d9deabbb88505
    Deleting instance b8eb5fde-1c19-4c2e-aec8-0d446165a1cb from test 18dbb77039754173b68d9deabbb88505
    deleted network ci-internal-18dbb77039754173b68d9deabbb88505
    deleted network ci-external-18dbb77039754173b68d9deabbb88505

### Frag

    usage: sb frag [-h] [-f FRAGMENT_DIR] [-y YAML_DIR] [-s SCENARIO] node

    positional arguments:
      node                  node to build a fragment for

    optional arguments:
      -h, --help            show this help message and exit
      -f FRAGMENT_DIR, --fragment_dir FRAGMENT_DIR
                            name of image to use
      -y YAML_DIR, --yaml_dir YAML_DIR
                            name of image to use
      -s SCENARIO, --scenario SCENARIO
                            Scenario to use

Prints out the script that cloud-init will run on the specified node after fragments have been composed and substitutions have been made. This won't include substitutions that require run-time data such as build\_server\_ip.

Example:

    sb frag build-server

    sb frag build-server
    >#!/bin/bash
    > ...
    > [long series of commands]

### Meta

    usage: sb meta [-h] [-y YAML_DIR] [-s SCENARIO] [-c CONFIG] node

    positional arguments:
      node                  node to build metadata for

    optional arguments:
      -h, --help            show this help message and exit
      -y YAML_DIR, --yaml_dir YAML_DIR
                            name of image to use
      -s SCENARIO, --scenario SCENARIO
                            Scenario to use
      -c CONFIG, --config CONFIG
                            Type of config to build - user or config

Prints the yaml file that will be sent to the specified node. Can be either user or conf, for user.yaml and config.yaml respectively.

Example:

    >sb frag build-server
    [contents of config.yaml]

    >sb frag build-server -c user
    [contents of user.yaml]

### Wait

    usage: sb wait [-h] [-t TEST_ID]

    optional arguments:
      -h, --help            show this help message and exit
      -t TEST_ID, --test_id TEST_ID
                            id of the build to wait for

Waits for all VMs, or all VMs in the specified build, to signal their deployment is complete. This command requires a route to the ci network that the VMs are on. It's used by jenkins to detemine when it's ok to start running tests (tempest or otherwise)

Example:

    sb wait -t 18dbb77039754173b68d9deabbb88505

### Log

    usage: sb log [-h] [-t TEST_ID] [-s SCENARIO] [-p DATA_PATH]

    optional arguments:
      -h, --help            show this help message and exit
      -t TEST_ID, --test_id TEST_ID
                            id of the test to get logs from
      -s SCENARIO, --scenario SCENARIO
                            Scenario of test
      -p DATA_PATH, --data_path DATA_PATH
                            Path to the data directory containing yaml config

Waits for deploy status to be complete, then copies logs from all servers, or from servers in the specified test. This command requires a route to the ci network that the VMs are on. It's used by Jenkins in liu of centralised logging and will likely go away at some point.

Example:

    sb log -t 18dbb77039754173b68d9deabbb88505


