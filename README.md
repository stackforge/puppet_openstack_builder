Openstack Installer
================

Project for building out OpenStack COE.

## Spinning up VMs with Vagrant

This project historically supported spinning up VMs to test OpenStack with Vagrant.

This approach is recommended for development environment or for users who want
to get up and going in the simplest way possible.

### requirements

This setup requires that a few additional dependencies are installed:

* virtualbox
* vagrant

### Developer instructions

Developers should be started by installing the following simple utility:

    gem install librarian-puppet-simple

or, if you want to build from scratch, or keep these gems separate:

    mkdir vendor
    export GEM_HOME=`pwd`/vendor
    gem install thor --no-ri --no-rdoc
    git clone git://github.com/bodepd/librarian-puppet-simple vendor/librarian-puppet-simple
    export PATH=`pwd`/vendor/librarian-puppet-simple/bin/:$PATH

Once this library is installed, you can run the following command from this project's
root directory. This will use the Puppetfile to clone the openstack modules and the COE manifests, into the modules directory, and can be easily configured to pull from your own repo instead of the Cisco or Stackforge repos. The default is to use the stackforge modules

To use the CiscoSystems releases of the puppet modules:

    export repos_to_use=downstream

To download modules

    librarian-puppet install --verbose

### Configuration

There is a config.yaml file that can be edited to suit the environment.
The apt-cache server can be any server running apt-cacher-ng - it doesn't have to be the cache instance mentioned below if you already have one handy. It can be set to false to disable use of apt-cacher altogether.
The apt-mirror will be used to set sources.list on each machine, and on the build server it will be used to import the 30MB ubuntu netboot image used during the PXE deploy process.
Make sure the domain matches the domain specified in the site.pp in the manifests you intend to use.

### Spinning up virtual machines with vagrant

Now that you have set up the puppet content, the next step is to build
out your multi-node environment using vagrant.

First, deploy the apt-ng-cacher instance:

    vagrant up cache

Next, bring up the build server:

    vagrant up build

Now, bring up the blank boxes so that they can PXE boot against the master

    vagrant up control_basevm

    vagrant up compute_basevm

Now, you have created a fully functional openstack environment, now have a look at some services:

  * service dashboard: http://192.168.242.100/
  * horizon:           http://192.168.242.10/ (username: admin, password: Cisco123)

Log into your controller:

    vagrant ssh control_basevm

and run through the 'Deploy Your First VM' section of this document:

    http://docwiki.cisco.com/wiki/OpenStack:Folsom-Multinode#Creating_a_build_server


## Spinning up virtual machines with Openstack

(Experimental)

The python scripts under stack-builder can be used to instantiate scenarios on an openstack cluster. To do this, clone this repository, add stackbuilder/bin to your PATH, and add stackbuilder to your PYTHONPATH. It is not necessary to install the modules or librarian to your local machine when running in this manner, but the openstack clients and the python yaml library are needed.

    curl -O https://pypi.python.org/packages/source/v/virtualenv/virtualenv-1.10.1.tar.gz
    tar xvfz virtualenv-1.10.1.tar.gz
    cd virtualenv-1.10.1
    python virtualenv.py test
    cd test
    source bin/activate
    pip install python-novaclient==2.14.1
    pip install python-quantumclient==2.2.3
    pip install python-keystoneclient==0.3.2
    pip install PyYaml
    git clone "https://github.com/CiscoSystems/openstack-installer"
    cd openstack-installer
    export PATH=`pwd`/stack-builder/bin:$PATH
    export PYTHONPATH=`pwd`/stack-builder:$PYTHONPATH

The scripts are currently limited by a quantum bug that means admin credentials are required to launch. Using standard user credentials will result in networks that have no dhcp agent scheduled to them.

    source openrc

To create a basic 2 role cluster with a build, compute and control node outside of the jenkins environment, some configuration must be set either in data/heira\_data/user.yaml or by setting environment variables prefixed with "jenkins\_"

    export osi_user_internal_ip='%{ipaddress_eth1}'
    export osi_user_tunnel_ip='%{ipaddress_eth1}'
    export osi_conf_initial_ntp=ntp.esl.cisco.com
    export osi_conf_installer_repo=CiscoSystems
    export osi_conf_installer_branch=master
    export osi_conf_build_server_domain_name=domain.name
    export osi_conf_operatingsystem=Ubuntu

    sb make
    
    e824830b269544d39a632d89e0a1902c

To destroy all resources created by the sb tool:

    sb kill

    deleted port b68c7ff8-7598-42fd-ac3c-2e2b7021d2c6
    deleted port baa3c279-2b3d-4dad-a76a-f699de96d629
    deleted port c6603b5d-cc0c-47be-a897-e667727294ae
    deleted subnetci-9cbbfa7d10b54ff0b87e5983a492e05c22
    deleted subnetci-9cbbfa7d10b54ff0b87e5983a492e05c11
    deleted networkci-9cbbfa7d10b54ff0b87e5983a492e05c1
    deleted networkci-9cbbfa7d10b54ff0b87e5983a492e05c2

To destroy a specific test run's resources:

    sb kill -t e824830b269544d39a632d89e0a1902c

    deleted port b68c7ff8-7598-42fd-ac3c-2e2b7021d2c6
    deleted port baa3c279-2b3d-4dad-a76a-f699de96d629
    deleted port c6603b5d-cc0c-47be-a897-e667727294ae
    deleted subnetci-9cbbfa7d10b54ff0b87e5983a492e05c22
    deleted subnetci-9cbbfa7d10b54ff0b87e5983a492e05c11
    deleted networkci-9cbbfa7d10b54ff0b87e5983a492e05c1
    deleted networkci-9cbbfa7d10b54ff0b87e5983a492e05c2

More information about this tool can be found under the stack-builder directory.

## basic install against already provisioned nodes:

### install your build server

first, log into your build server, and run the following script to bootstrap it as a puppet master:

    bash <(curl -fsS https://raw.github.com/CiscoSystems/openstack-installer/master/install-scripts/master.sh)

### set up your data

on your build server, all of the data you may need to override can be found in:

    /etc/puppet/data/hiera_data/user.common.yaml

at the very least, you may need to update the controller ip addresses and set the
interfaces to use.

Look at the puppet certnames that map to roles in:

    /etc/puppet/data/role_mappings.yaml

You may also find a need to change the default scenario in:

    /etc/puppet/data/config.yaml

Choices are in:

    /etc/puppet/data/scenarios

### install each of your components

first setup each node (unless you're doing all\_in\_one scenario, in which case you'll already have done this from the previous step):

    export build_server_ip=X.X.X.X ; bash <(curl -fsS https://raw.github.com/CiscoSystems/openstack-installer/master/install-scripts/setup.sh)

then log into each server, and run:

``
    puppet agent -td --server build-server.`hostname -d` --certname `hostname -f`
``

where build-server is the fully qualified name of the build server (or `` `hostname -f` `` on an all-in-one node), or its IP address that was set in user.common.yaml and ROLE\_CERT\_NAME is the fully qualified name of the local machine (or `` `hostname -f` `` which should return the same thing)

*NOTE: you'll want to run the puppet agent command on any control class nodes (or the all-in-one node) first, before running it on any compute or storage nodes.*
