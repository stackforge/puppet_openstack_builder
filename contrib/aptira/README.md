Openstack by Aptira
===================

## Overview

This is a revision of the data model with the following goals:

 - Remove dependency on the scenario_node_terminus
 - Implement data model in pure hiera
 - Support Centos/RHEL targets
 - Support masterless deployment
 - Simplify node bootstrapping
 - Make HA a core feature rather than an add-on
 - Move all modules to master branch

While providing a clean migration path from the current method.

## Requirements

Currently, this distribution assumes it has been provided with already-provisioned
Centos 6 servers each with more than one network interface. For production
deployments it is recommended to have additional interfaces, as the data model can
distinguish between the following network functions and assign an interface to each:

 - deployment network
 - public API network
 - private network
 - external floating IP network

## Installation

Before installing the distribution, review the following options which are available:

Set an http proxy to use for installation (default: not set)

    export proxy='http://my_proxy:8000'

Set the network interface to use for deployment (default: eth1)

    export network='eth0'

set install destination for the distribution (default: $HOME)

    export dest='/var/lib/stacktira'

Once you have set the appropriate customisations, to install the aptira distribution,
run the following command:

    \curl -sSL https://raw.github.com/michaeltchapman/puppet_openstack_builder/stacktira/contrib/aptira/installer/bootstrap.sh | bash

## Configuration

The distribution is most easily customised by editing the file
/etc/puppet/data/hiera_data/user.yaml. A sample will be placed there if
one doesn't exist during installation and this should be reviewed before
continuing. In particular, make sure all the IP addresses and interfaces
are correct for your deployment.

## Deployment

To deploy a control node, run the following command:

    puppet apply /etc/puppet/manifests/site.pp --certname control-`hostname`

To deploy a compute node, run the following command:

    puppet apply /etc/puppet/manifests/site.pp --certname compute-`hostname`

## Development Environment Installation

First, clone the repo and checkout the experimental stacktira branch

    git clone https://github.com/michaeltchapman/puppet_openstack_builder
    git checkout stacktira

The conversion from scenario_node_terminus yaml to pure hiera is done by
a script which require PyYaml. Install this library either via distro
package manager or using pip.
    pip install PyYaml

Run the conversion script. This will replace the Puppetfile, Vagrantfile,
manifests and data directories with the stacktira version:

    python contrib/aptira/build/convert.py

Install the modules:

    mkdir -p vendor
    export GEM_HOME=vendor
    gem install librarian-puppet
    vendor/bin/librarian-puppet install

Now you can boot using the control* and compute* vms, or using rawbox to test
out the public tarball available from Aptira.

## Authors

Michael Chapman
