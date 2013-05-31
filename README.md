Grizzly-manifests
================

Project for building out OpenStack COE.

## Installing dependencies

This setup requires that a few additional dependencies are installed:

* virtualbox
* vagrant

## User instructions

	git clone https://github.com/CiscoSystems/grizzly-manifests
	cp grizzly-manifests/* /etc/puppet/manifests

## Developer instructions

Developers should be started by installing the following simple utility:
(I will eventually just have it bundled as a gem)

    mkdir vendor
    export GEM_HOME=`pwd`/vendor
    gem install thor --no-ri --no-rdoc
    git clone git://github.com/bodepd/librarian-puppet-simple vendor/librarian-puppet-simple
    export PATH=`pwd`/vendor/librarian-puppet-simple/bin/:$PATH

Once this library is installed, you can run the following command from this project's
root directory:

    librarian-puppet install --verbose

Add the basebox

    vagrant box add blank blank.box

This command will clone all required modules into the modules directory.

## Spinning up virtual machines with vagrant

Now that you have set up the puppet content, the next step is to build
out your multi-node environment using vagrant.

First, deploy the apt-ng-cacher instance:

    vagrant up cache

Next, bring up the build server:

    vagrant up build

Now, bring up the blank boxes so that they can PXE boot against the master

    vagrant up control

    vagrant up compute


Now, you have created a fully functional openstack environment, now have a look at some services:

  * service dashboard: http://192.168.242.100/
  * horizon:           http://192.168.242.10/ (username: admin, password: Cisco123)

Log into your controller at: ssh localadmin@192.168.242.10 (password ubuntu)

and run through the 'Deploy Your First VM' section of this document:

  http://docwiki.cisco.com/wiki/OpenStack:Folsom-Multinode#Creating_a_build_server
