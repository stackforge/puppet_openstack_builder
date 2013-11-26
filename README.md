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

The data model in this repository can be consumed by the scenariobuilder tool. To install it, use pip:

    pip install scenariobuilder

The 'sb' tool can then be used with Openstack credentials to instantiate the data model in VMs on an Openstack cloud. For more information see: https://github.com/CiscoSystems/scenariobuilder

# Basic install against already provisioned nodes (Ubuntu 12.04.3 LTS):

### install your All-in-one Build, Control, Network, Compute, and Cinder node:

These instructions assume you will be building against a machine that has two interfaces:

'eth0' for management, and API access, and also to be used for GRE/VXlan tunnel via OVS
'eth1' for 'external' network access (in single provider router mode).  This interface
is expected to provide an external router, and IP address range, and will leverage the
l3_agent functionality to provide outbound overloaded NAT to the VMs and 1:1 NAT with 
Floating IPs.  The current default setup also assumes a very small "generic" Cinder 
setup, unless you create an LVM volume group called cinder-volume with free space
for persistent block volumes to be deployed against.

Log in to your all_in_one node, and bootstrap it into production:

    bash <(curl -fsS https://raw.github.com/stackforge/puppet\_openstack\_builder/master/install-scripts/install.sh)

You can over-ride the default parameters, such as ethernet interface names, or hostname, and default ip address if you choose:

scenario           : change this to a scenario defined in data/scenarios, defaults to all_in_one
build_server       : Hostname for your build-server, defaults to `` `hostname` ``
domain_name        : Domain name for your system, defaults to `` `hostname -d` ``
default_interface  : This is the interface name for your management and API interfaces (and tunnel endpoints), defautls to eth0
external_interface : This is the interface name for your "l3_agent provider router external network", defaults to eth1
build_server_ip    : This is the IP that any additional devices can reach your build server on, defaults to the default_interface IP address
ntp_server         : This is needed to keep puppet in sync across multiple nodes, defaults to ntp.esl.cisco.com
puppet_run_mode    : Defaults to apply, and for AIO there is not a puppetmaster yet.

To change these parameters, do something like:

scenario=2_role bash <(curl.....master.sh)

### add additional nodes

Adding additional nodes is fairly straight forward (for all_in_one scenarion compute nodes can be added, others require a bit of additional effort by expanding the all_in_one scenario)

1) on the All-in-one node, add a role mapping for the new node:

echo "compute_node_name: compute" >> /etc/puppet/data/role_mappings.yaml

2) Build the phyiscal or virtual compute node

3) Configure the system to point ot the all_in_one node for puppet deployment and set up the right version of puppet on the node:

    export build_server_ip=X.X.X.X ; export master=false ; bash <(curl -fsS https://raw.github.com/stackforge/puppet\_openstack\_builder/master/install-scripts/install.sh)

After which you may still have to run puppet in "agent" mode to actually deploy the openstack elements:

``
    puppet agent -td --server build-server.`hostname -d` --certname `hostname -f`
``

### If other role types are desired

At the scenario leve, choices are in:

    /etc/puppet/data/scenarios

And you can extend the all_in_one scenario, or leverage a different variant all together.

Defaults for end user data should be located in one of the following files:

    /etc/puppet/data/hiera_data/user.yaml
    /etc/puppet/data/hiera_data/user.common.yaml
    /etc/puppet/data/hiera_data/user.<scenario>.yaml

### Using a vendor modification

You can specify a vendor, which will change both the apt repository and the git repository the data defining the deployment is drawn from. Currently the only option is cisco, which can be set by:

    export vendor=cisco

###Additional information on the data model being leveraged is available in the data directory of this repository.
