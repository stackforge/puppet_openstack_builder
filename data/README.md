# Deployment modeling data

This folder contains data that is used to express openstack
deployment as data.

Technically, it is implemented as a custom [hiera](http://docs.puppetlabs.com/hiera/1/index.html) [backend](http://docs.puppetlabs.com/hiera/1/custom_backends.html),
and an [external node classifier](http://docs.puppetlabs.com/guides/external_nodes.html) (more specfically, as a custom node terminus, but for our purposes here, they can be considered as the same thing)

It is critical to understand the following in order to understand this model:

+ how hiera works (and how data-bindings work)
+ the fact this uses a custom hiera backend (so it is not quite the same
  as standard hiera)
+ what an ENC is

This solution ONLY works with Puppet 3.x or greater and relies on the data-bindings
system.

Below are the links to the custom ENC and custom hiera backend:

* https://github.com/bodepd/scenario_node_terminus
* https://github.com/bodepd/hiera_data_mapper

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

Reuse of components was difficult in the old model because of it's use of
parameterized classes. When classes are declared with the following syntax,
they cannot be redeclared. This means that components that use class
declarations like this cannot be re-used by other components that want to
configure them in a different manner.:

    class { 'class_name':
      parameter => value,
    }

This issue is most visible if you look at the amount of duplicated code
between the openstack::all class and the openstack::controller class.

### Data forwarding was too much work

Explicit parameter-forwarding through nested class declarations
(ie: openstack::controller -> openstack::nova::controller -> nova)
has proved too difficult to maintain and too easy to mess up.

Adding a single parameter to an OpenStack role in the current model can
require that same parameter be explicitly forwarded through 2 or 3 different
class interfaces.

In fact, a large percent of all of the pull requests for all module are to
add parameters to the Openstack classes.

### Puppet manifests are not introspectable enough

As we move towards the creation of user interfaces that drive the
configuration of multiple different reference architectures, we need
a way to inspect the current state of our deployment model to understand
what input needs to be provided by the end user.

For example:

  The data that a user need to provide to deploy a 3 role model:
  (compute/controller/network controller) is different from the data used to
  deploy a 2 role model (compute/controller)

To make matters even a bit more complicated:

  Each of those models also supports a large number of configurable backends
  that each require their own specific configurations. Even with a 2 role scenario,
  you could select ceph, or swift, or file as the glance backend. Each of these
  selections require their own sets of data that needs to be provided by the end
  user.

This need to programatically compile a model into a consumable user interface is
the requirement that led to the adoption of a data model, as opposed to something
more like [roles/profiles](http://www.craigdunn.org/2012/05/239/).

Puppet provides a great way to express interfaces for encapsulating system resources,
but that content is only designed to be consumed by Puppet's internal lexer and parser,
it is not designed to be introspectable by other tools. In order to support the selection
of both multiple reference architectures as well as multiple backends, we need to
be able to programatically understand the selected classes to provide the user with the
correct interface.

## what is used to express the data

All of the data used to express the various reference architectures can be found
in this projects data directory. The sections explains the various configuration
files and directories that can be found in that directory..

### Data driven by the custom ENC

When a node checks in with Puppet, the master invokes the scenario node terminus.
This call is made to provide Puppet with two pieces of information that it needs
to compile a catalog for that node:

+ what classes should be included for that node
+ what top scope parameters should be set that can effect the hiera lookups

In order for this to work with the data model, you need to install the following
module:

    https://github.com/bodepd/scenario_node_terminus

This module is automatically installed if you use the Puppetfile that comes
with this project. And add the following configuration to your puppet.conf file:

    node_terminus=scenario

This is already configured if you bootstrap with setup.pp.

The following list of data is used to drive that classification process

#### config.yaml

For the general use case, most of the information in config.yaml
can be ignored. Most of it is used for provisioning of virtual machine
instances for the CD part of this work.

There is one very important setting in config.yaml called scenario.

+  *scenario* is used to select the specific references architecture
   that you wish to deploy. Its value is used to select the roles for
   that specific deployment model from the file: scenarios/<scenario>.yaml.
   If you are using this project for CD, scenario is also used to select
   the set of nodes that will be provisioned for your deployment.
   Scenario is also passed to Puppet as a global variable and used to drive
   both interpolation as well as category selection in hiera.

#### global\_hiera\_params

This directory is used to specify the global variables that can be used
to effect the hierarchical overrides that will be used to determine both
the classes contained in a scenario roles as well as the hiera overrides
for both data mappings and the regular yaml hierarchy.

The selection of the global\_hiera\_params is driven by hiera using the following
hierarchy:

  - global\_hiera\_params/user.yaml - users can provide their own global
  overrides in this file.
  - global\_hiera\_params/scenario/%{scenario}.yaml - Default values specific to a
  scenario are loaded from here (they override values from common.yaml)
  - global\_hiera\_params/common.yaml - Default values for globals are located here.

These variables are used by hiera to determine both what classes are included as a
part of the role lookup, and are also used to drive the hierarchical lookups of
data both by effecting the configuration files that are consulted (like the scenario
specific config file from above)).

The current supported variables are:

  + *db_type* selects the database to use (defaults to mysql)

  + *rpc_type* Selects the rpc type to use (defaults to rabbitmq)

  + *cinder_backend* Selects the backend to be used with cinder. Defaults to iscsi.
    (currently supports iscsi and ceph)

  + *glance_backend* Selects the backend that should be used by glance
    (currently supports swift, ceph, and file)

  + *compute_type* The backend to use for compute (defaults to libvirt)

  + *network_service* Network service to use. This hack is used to select between
    quantum and neutron and will hopefully be deprecated once grizzly support is
    dropped.

  + *network_plugin* Network plugin to use
    Support ovs and linuxbridge. Defaults to ovs in common.yaml.

  + *network_type* The type of network (defaults to per-tenant-router)

  + *tenant_network_type* Type of tenant network to use. (defaults to gre).

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
and class\_groups should be assigned to nodes of that role.

### class groups

Class groups are simply a set of classes that can be referenced
by a  single name. Class groups are used to store combinations
of classes for reuse.

For example, the class group nova\_compute contains the following data:

    classes:
      - nova
      - nova::compute
      - "nova::compute::%{compute_type}"
      - "nova::network::%{network_service}"
      - "nova::compute::%{network_service}"
      - "%{network_service}"
      - "%{network_service}::agents::%{network_plugin}"

Two things to note here:

1. It contains a list of classes that comprise nova compute
2. Some of the classes use the hiera syntax for variable interpolation to
   set the names of classes used to the values provided from the
   hiera\_global\_params.

## role\_mappings

role\_mappings are used to map a Puppet certificate name to a specific roles
from your selected scenario.

The following example shows how to map a certname of controller-server to
a role of controller:

    controller-serer: controller

The certificate name in Puppet defaults to a systems hostname, but can be
overridden from the command line using the --certname option. The following
command could be used to convert a node into a controller.

    puppet agent --certname controller-server

**TODO: the role mappings do not currently support regex, but probably need to**

### Binding values to class parameters

After Puppet gets a list of classes and top scope parameters from the node
terminus it begins to compile the catalog. During this process,
every single class parameter is resolved through Puppet's data-binding system
that came into existence in Puppet 3.x. Basically:

    for every class
      let's say foo
    for every parameter
      let's say param1
    the fully qualified variable is lookedup in hiera automatically:
      hiera('foo::param') for our example

When this lookup is performed, for the data model, our default
hiera backend is used:

    https://github.com/bodepd/hiera_data_mapper

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

It is worth noting that both the scenario name as well the global\_heira\_params
are used to determine which files are resolved as a part of a node's lookup
hierarchy.

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
multiple class parameters. The problem is, that it uses the parameterized
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
    calls hiera to determine the value of keystone::verbose"
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

## scenario command line tools

The scenario node terminus project comes with a set of command lines tools
that were created to make it easier to understand and debug issues with the
data model.

These tools use the following system data:

* /etc/puppet/hiera.yaml
* /etc/puppet/data/config.yaml - to determine scenario
* /etc/puppet/data/global\_hiera\_params
* /etc/puppet/data/data\_mappings
* /etc/puppet/hiera\_data

+ *get_classes*

    puppet scenario get_classes <role_name>

This command is used to retrieve the list of classes assigned to a specific role.

+ *compile_role*

    puppet scenario compile_role <role_name>

This command is used to retrieve the list of classes along with all data that will
be set for those classes via hiera and puppet-data-bindings. It takes all available
data and precalculates the values for all data.

In order for this to be 100% accurate, it also needs fact values.

By default, it will run facter as a part of the command to retrieve these
values.

This can also be configured to get facts for any server provided that:
- you are on the puppetmaster
- that node has already checked its facts into puppetdb

    puppet scenario compile_role <role_name> --certname_for_facts <certname> \
    --facts_terminus puppetdb

+ *get_hiera_data*

    puppet scenario get_hiera_data <namespace::parameter> [--verbose] [--debug]

This command looks up an individual class parameter and returns the retrieved value.
