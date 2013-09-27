Openstack Installer
================

Project for building out OpenStack COE.

## Installing dependencies

This setup requires that a few additional dependencies are installed:

* virtualbox
* vagrant

## Developer instructions

Developers should be started by installing the following simple utility:
(I will eventually just have it bundled as a gem)

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

Now, if you are using the Cisco modules:

    cp site.pp.downstream modules/manifests/manifests

If you are using the stackforge modules:

    cp site.pp modules/manifests/manifests

If you want to test the PXE deployment system, add the basebox

    vagrant box add blank blank.box

## Configuration ##

There is a config.yaml file that can be edited to suit the environment. 
The apt_cache server can be any server running apt-cacher-ng - it doesn't have to be the cache instance mentioned below if you already have one handy. It can be set to false to disable use of apt-cacher altogether.
The apt_mirror will be used to set sources.list on each machine, and on the build server it will be used to import the 30MB ubuntu netboot image used during the PXE deploy process.
Make sure the domain matches the domain specified in the site.pp in the manifests you intend to use. 

The puppet modules used are taken from stackforge. To use the CiscoSystems releases of the puppet modules:

    export repos_to_use=downstream

## Spinning up virtual machines with vagrant

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

Log into your controller at: ssh localadmin@192.168.242.10 (password ubuntu)

and run through the 'Deploy Your First VM' section of this document:

  http://docwiki.cisco.com/wiki/OpenStack:Folsom-Multinode#Creating_a_build_server


## Spinning up virtual machines with Openstack

(Experimental)

The python scripts under stack-builder can be used to instantiate scenarios on an openstack cluster. To do this, clone this repository, add stackbuilder/bin to your PATH, and add stackbuilder to your PYTHONPATH. It is not necessary to install the modules or librarian to your local machine when running in this manner.

    git clone https://github.com/CiscoSystems/openstack-installer.git
    cd openstack-installer
    export PATH=`pwd`/stackbuilder/bin:$PATH
    export PYTHONPATH=`pwd`/stackbuilder:$PYTHONPATH

This will provide access to the sb command, which after sourcing openstack credentials, can be used like so:

    . openrc

To create a scenario:

    sb make

    Running test: e824830b269544d39a632d89e0a1902c
    CI network 1 doesn't exist. Creating ...
    CI subnet 1 doesn't exist. Creating ...
    CI network 2 doesn't exist. Creating ...
    CI subnet 2 doesn't exist. Creating ...
    Booting build-server
    Booting control-server
    Booting compute-server02

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
