# Deployment modeling data

This folder contains data that is used to express openstack
deployment as data.

Technically, it is implemented as a custom [hiera](http://docs.puppetlabs.com/hiera/1/index.html) [backend](http://docs.puppetlabs.com/hiera/1/custom_backends.html),
and an [external node classifier](http://docs.puppetlabs.com/guides/external_nodes.html) (more specfically, as a custom node terminus, but for our purposes here, they can be considered as the same thing)

It is critical to understand the following in order to understand this model:

+ how hiera works
+ the fact this uses a custom hiera backend (so it is not quite the same
  as standard hiera)
+ what an ENC is

This solution ONLY works with Puppet 3.x or greater and relies on the data-bindings
system.

Below are the links to the custom ENC and custom hiera backend:

* https://github.com/bodepd/scenario\_node\_terminus
* https://github.com/bodepd/hiera\_data\_mapper

## why data?

This is intended to replace the stackforge/puppet-openstack class
as well as other tools that look at composing the core stackforge modules
into openstack roles.

The puppet-openstack (and other models that I looked at) suffered
from the following problems:

### The roles were not composable enough.

Multiple reference architectures for openstack (ie: all\_in\_one,
compte\_controller) should all be composed of the same building
blocks in order to reduce the total amount of code needed to express
these deployment scenarios.

For example, an all\_in\_one deployment should be expressed as a
compute + controller + network\_controller.

The previous model did not support this because of it's use of parameterized
classes and inherent issues regarding duplicate resource definitions, and
the need for all parameters to be provided in a single declaration of that
class.

### Data forwarding was too much work

Explicit data-forwarding in the class hierarchies
(ie: openstack::controller -> openstack::nova::controller -> nova)
was too much work and too easy to mess up. Adding a single parameter to the
core model sometimes required adding it to 2 or three different class interfaces.

In fact, a large percent of all of the pull requests in the project were to
add parameters for forwarding to the openstack class.

### Puppet manifests are not introspectable enough

As we move towards the creation of user interfaces that drive the
configuration of multiple different reference architectures, we need
a way to inspect the current state of our deployment model to understand
what input needs to be provided by the end user.

For example:

  The data provided to deploy a 3 role model: (compute/controller/network controller)
  is different from the data used to deploy a 2 role model (compute/controller)

To make matters even a but more complicated:

  Each of those models also supports a large number of configurable backends
  that each require their own specific configurations. Even with a 2 role scenario,
  you could select ceph, or swift, or file as the glance backend. Each of these
  selections results in different user configurations.

This issue specifically lead to the creation of the model as data (as
opposed to something more like roles/profiles: http://www.craigdunn.org/2012/05/239/).

Puppet provides a great way to express interfaces for encapsulating system resources,
but that content is only designed to be consumed by Puppet's internal lexer and parser,
it is not designed to be introspectable by other tools. In order to support the selection
of both multiple reference architectures as well as multiple backends, we need to
be able to programatically understand the selected classes to provide the user with the
correct interface.

## what is used to express the data

All of the data used to express the various reference architectures can be found
in this projects data directory. The sections explains the various configuration
files and directories that contain data.

### Data driven by the custom ENC

When a node checks in with Puppet, the master invokes the scenario node terminus.
This call is made to provide Puppet with two pieces of information that it needs
to compile a catalog for that node:

+ what classes should be included for that node
+ what top scope parameters should be set that can effect the hiera lookups

In order for this to work with the data model, you need to install the following
module:

    https://github.com/bodepd/scenario\_node\_terminus
    (this module is automatically installed if you use the Puppetfile that comes
    with this project))

And add the following configuration to your puppet.conf file:

  node\_terminus=scenario
  (this is already configured if you bootstrap with setup.pp))

The following list of data is used to drive that classification process

#### config.yaml

For the general use case, most of the information in config.yaml
can be ignored. Most of it is used for provisioning of virtual machine
instances for the CD part of this work.

The is one very important setting in config.yaml called scenario.

  *scenario* scenario is used to select the specific references architecture
  that you wish to deploy. It is used to select the roles for that scenario
  from the scenarios/<scenario>.yaml file, as well as the nodes to use from
  nodes/<scenario>/yaml (for deployment of CI). It is also used as a hiera
  lookup and data mapping hierarchy.

All data set in this file are passed on to Puppet as global variables.

#### global\_hiera\_params

This directory is used to specify the global variables that can be used
to effect the hierarchical overrides that will be used to determine both
the classes contained in a scenarios roles as well as the hiera overrides
for both data mappings and the regular yaml hierarchy.

The selection of the global\_hiera\_params is driven by hiera using the following
hierarchy:

  - global\_hiera\_params/user.yaml
  - global\_hiera\_params/scenario/%{scenario}.yaml
  - global\_hiera\_params/common.yaml

This means that default globals are stored in common.yaml, scenarios can
provide their own defaults, and users can override whatever settings they
need to.

These variables are used by hiera to determine both what
classes are included as a part of the role lookup, and are also used to drive
the hierarchical lookups of class parameters.

The current supported variables are:

  *db_type* selects the database to use (defaults to mysql)

  *rpc_type* Selects the rpc type to use (defaults to rabbitmq)

  *cinder_backend* Selects the backend to be used with cinder. Defaults to iscsi.
  (currently supports iscsi and ceph)

  *glance_backend* Selects the backend that should be used by glance (currently
  supports swift, ceph, and file)

  *compute_type* The backend to use for compute (defaults to libvirt)

  *network_service* Network service to use. This hack is used to select between
  quantum and neutron.

  *network_plugin* Network plugin to use (defaults to ovs)

  *network_type* The type of network (defaults to router-per-tenant)

  *tenant_network_type* Type of tenant network to use. (defaults to gre).

  *enabled_services* Used to select all of the services that are enabled. This is
  used to determine what endpoints and databases should be configured.

All data set in this file are passed on to Puppet as global variables.

### scenarios

Scenarios are used to describe the reference architecture that you wish to
deploy.

The scenario to be selected is driven by the scenario
key in config.yaml.

Each of the roles for a specific scenario is specified in its scenario
file:

  data/scenario/<scenario>.yaml

This file defines what roles exists for a specific scenario, and which classes
and classgroups should be assined to nodes of that role.

### class groups

Class groups are simply a list of classes that can be referred
to as a single name. Class groups are used to store combinations
of classes for reuse.

## role\_mappings

role\_mappings is used to map Puppet certnames to roles.

## data that drives the hiera configuration

After Puppet gets a list of classes and top scope parameters from the node
terminus it begins to compile the catalog. During this process,
every single class parameter is resolved through Puppet's data-binding system
that came into existence in Puppet 3.x. Basically:

  for every class
    let's say foo
  for every parameter
    let's say param1
  the fully qualified variable is lookup in hiera automatically:
    hiera('foo::param') for our example

When this lookup is performed, for the data model, our default
hiera backend is used:

  https://github.com/bodepd/hiera\_data\_mapper

This should be configured in your hiera config

  /etc/puppet/hiera.yaml

    ---
    :backends:
      - data_mapper
    :hierarchy:
      - "hostname/%{hostname}"
      - user
      - jenkins
      - user.%{scenario}
      - user.common
      - "cinder_backend/%{cinder_backend}"
      - "glance_backend/%{glance_backend}"
      - "rpc_type/%{rpc_type}"
      - "db_type/%{db_type}"
      - "tenant_network_type/%{tenant_network_type}"
      - "network_type/%{network_type}"
      - "network_plugin/%{network_plugin}"
      - "password_management/%{password_management}"
      - "scenario/%{scenario}"
      - grizzly_hack
      - common
    :yaml:
       :datadir: /etc/puppet/data/hiera_data
    :data_mapper:
       # this should be contained in a module
       :datadir: /etc/puppet/data/data_mappings

This entire hiera config is required for all of the default data to be set
correctly. As the project matures, this default hierarchy may be subject to change.

### data mappings

Data mappings are used to express the way in which
global variables from map to individual class parameters.

Previous, this was done with parameter forwarding in parameterized
classes. In fact, this style of parameter forwarding is one of the main
functions of the previous openstack module.

For example, in the openstack::controller class, we implemented the
parameter verbose which is used to set verbose for all services.

    class openstack::controller(
      $verbose = false
    ) {

      class { 'nova': verbose => $verbose }
      class { 'glance': verbose => $verbose }
      class { 'keystone': verbose => $verbose }
      class { 'cinder': verbose => $verbose }
      class { 'quantum': verbose => $verbose }

    }

This is pretty concise way to express how a single data value assigns
multiple class parameters. The problem, is that is uses the parameterized
class declaration syntax to forward this data, meaning that it is hard to
reuse this code if you want to provider different settings.

The same configuration above can be expressed with the data\_mappings as
follows:

    verbose:
      - nova::verbose
      - glance::verbose
      - keystone::verbose
      - cinder::verbose
      - quantum::verbose

For each of those variables, the data-binding will call out to hiera when
the classes are processed (if they are included)

Example:

  Puppet
    calls hiera to determine the value of keystone::verbose?"
  Hiera
    * consults data mappings (via the hierarchical lookup defined in hiera.yaml)
    * determines that value maps to verbose
    * performs a regular YAML lookup in the hiera\_data directory of 'verbose'

### hiera data

hiera data is used to express what values are going to be used to
configure your openstack services.

hiera data is used to either express global keys (that were mapped to
class parameters in the data mappings), or fully qualified class parameter
namespaces.

NOTE: at the moment, fully qualified variables are ignored from hiera\_data
if they were defined in the data\_mappings. This is probably a bug (b/c they should
probably override), but this is how it works at the moment.

## CI/CD specific constructs:

### nodes

Nodes are currently used to express the nodes that can be built
in order to test deployments of various scenarios. This is currently
used for deployments for CI.

Casual users should be able to ignore this.

We are currently performing research to see if this part of the data
should be replaces by a HEAT template.
