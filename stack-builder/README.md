# stack-builder

## Overview

Stack-builder is a set of scripts that are intended to be used with openstack-installer. Given openstack credentials, stack-builder will create the appropriate resources on the given cloud to test a scenario described by openstack-installer, and will install openstack using the specified scenario.

## Installation

First, clone openstack-installer

    git clone https://github.com/CiscoSystems/openstack-installer.git
    cd openstack-installer

Clone the stack-builder repository 

    git clone https://github.com/michaeltchapman/stack-builder.git

Then, add bin to the path, and stack-builder to the python path

    export PATH=`pwd`/stack-builder/bin:$PATH
    export PYTHONPATH=`pwd`/stack-builder:$PYTHONPATH

## Usage

The command line tool is called sb. It can be used to create test runs, inspect test runs, and clean up test runs.

To run a basic test:

    sb make [-i image] [-c ci_subnet_index] [-s scenario] [-p path]

To list test VMs:

    sb get [-t test_id]

To clean up test VMs:

    sb kill [-t test_id]

