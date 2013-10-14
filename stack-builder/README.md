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


## Data Flow

There are broadly two data categories of concern: data that controls the build environment, such as how many virtual machines to build and which networks to put them on, and data that controls the openstack cluster that is build using puppet. Stack-builder defines the former as conf data and the latter as user data. 

### User data

Since user data is really just serving as an input to puppet, it config is quite simple to deal with: there are four yaml files in data/hiera\_data - user.yaml, jenkins.yaml, user.common and user.[scenario].yaml that are loaded into a single dictionary in python, along with any environment variables with the prefix osi\_user\_. The order or precedence is env. vars > user.yaml > jenkins.yaml > user.common > user.[scenario].yaml. After these have all been loaded and the dictionary has been created, this is written to a string and sent to every virtual machine as /root/user.yaml. This is then copied to /etc/puppet/data/hiera\_data/user.yaml by the deploy script. Because user.yaml has the highest precedence in hiera, this can be used to override any settings in the openstack puppet modules.

The sb meta command can be used with the flag '-c user' to inspect the data that will be loaded.

### Conf data + build configuration

Config data is slightly more complex, since it effectively deals with preparing the cluster to run puppet. First, depending on which scenario has been selected, the script will load data/nodes/[scenario].yaml. This will define which VMs to create and which networks to create. The script will use the quantum API to create the appropriate networks along with ports for each VM. In the network section of the yaml file, some of the networks are also mappings themselves, such as build-server: networks: ci: cobbler\_node\_ip. A dictionary of runtime-config is created, with each of these mappings set as a key, and the value set as the IP address obtained for the appropriate port from quantum. So we end up with a dictionary that might look like this in a 2\_role scenario: 

    runtime\_config = {'cobbler\_node\_ip' : '10.123.0.22',
                       'control_node_ip'   : '10.123.0.23'}

This is the runtime config, and any data set here will override data from either environment variables or config files.

Environment variables with the prefix osi\_conf\_ are put into the dictionary along with everything from data/config.yaml. Environment variables take precedence over config.yaml.

This leaves us with a dictionary of all the config values we care about.

This is written to a string and pushed to each node as /root/config.yaml

The sb meta command can be used with the flag '-c conf' to inspect what will be loaded.

Now that networks have been created and runtime+static config has been loaded, data/nodes/[scenario].yaml is examined again, this time to look at which fragments are specified for each node. Fragments are small snippets of bash in the stack-builder/fragments directory, and the list for each node will determine which ones are needed for each node. For example, the puppet master will need to run puppet apply, while the puppet agents will need to run puppet agent. Templating is in use in these fragments, and after they have been composed into a single string for each node, substitution occurs for each value in the runtime-config. This lets the agent nodes know where the master is, and lets compute nodes know where the controller is (from runtime data); lets nodes know which domain they are a part of, and which ntp server to sync with (needed to run puppet, from config.yaml), and any user specified overrides to change per run, such as a particular repository or branch to use for a puppet module (from environment variables). After templating has been handled, the final scripts are written to /root/deploy on each node. Cloud init will blindly execute whatever it finds there on each node.

The sb frag command can be used to inspect what these build scripts will look like on each node

One of the fragments will load /root/config.yaml and export all its values as environment variables with the prefix FACTER\_, making them available to the initial puppet setup. Be very careful when changing config.yaml, since for example, changing 'Ubuntu' to 'ubuntu' will prevent puppet from running, and in general system facts can be overridden causing strange behavior.

