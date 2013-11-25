# configuring openstack as data

####Table of Contents

1. [Why Data?](#why-data)
2. [Users - getting started](#getting-started-as-a-user)
    * [Scenario Selcetion](#selecting-a-scenario)
    * [Configuring Globals](#configuring-globals)
    * [Scenarios](#scenarios)
    * [User Data](#user-data)
    * [Role Mappings](#role-mappings)

## Why Data

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

## Setup

Applying [setup.pp](https://github.com/stackforge/puppet_openstack_builder/blob/master/manifests/setup.pp)
will configure your nodes to use the data model. It does the following:

1. Installs a version of Puppet greater than 3.0.
2. [Sets the node\_terminus as scenario.](https://github.com/stackforge/puppet_openstack_builder/blob/master/manifests/setup.pp#L97)
3. [Configures hiera](https://github.com/stackforge/puppet_openstack_builder/blob/master/manifests/setup.pp#L63)

## Getting Started as a User

This section is intended to provider users with what they need to know in order
to use the data model to deploy a customized openstack deployment.

However, it is recommended that users understand the internals so that they
can debug things. Full documentation of the implementation can be found here:

[scenario node terminus](https://github.com/bodepd/scenario_node_terminus/blob/master/README.md).

The data model should be configured before you install any of your openstack
components. It is responsible for building a deployment model that is used
to assign both classes as well as data to each node that needs to be configured.

### Selecting a Scenario

The first step as an end user is to select a scenario. Scenarios are defined
in data/config.yaml as:

    scenario: all_in_one

The scenarios represents the currently deployment model, and are used to
determine the roles available as a part of that model.

Currently, the following scenarios are supported:

* *all\_in\_one* - installs everything on one node
* *2\_role* -splits compute/controller
* *full\_ha* - splits out an HA install that requires 13 nodes

The following command returns your current scenario:

    puppet scenario get_scenario

Once you have selected a scenario, you can see how it effects your deployment model:

    puppet scenario get_roles

### Configuring Globals

This directory contains sets of global variables that can be used to determine
what roles should be deployed as a part of your deployment model as well a how
data should be assigned to those roles.

In general, the following types of things can be configured:

* Pluggable backend selection for components (ie: what backend should cinder use)
* Selections that augment roles (ie: should tempest be installed, should a ceph
role exist)

As a user, you should specify any of these variables that you wish to override in:

    global_hiera_params/user.yaml

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

### Scenarios

Once you have selected your globals and scenario, you can now query the system to see
what the scenarios looks like for your current deployment model:

    puppet scenario get_roles

The output here shows 2 things:

* what roles can be assigned to nodes
* what classes are included as a part of those roles

### User Data

Once you have know your roles, you will want to customize the data used
to configure your deployment model.

You can get a list of the default data a user should consider setting with:

    puppet scenario get_user_inputs

This command shows a list of data that a user may want to provide along with
it's current default value.

> NOTE: The current view of user data is not perfect. It still needs some
> refinement.

Each of these values can be overridden by setting a key value pair in ``data/hiera_data/user.yaml``.

Values can either receive static values:

    controller_admin_address: 192.168.242.10

Or values that are set with facts (or hiera global params):

    internal_ip: "%{ipaddress_eth3}"

Once you have supplied all of your data, you can see how that data is applied to
your roles by invoking:

    puppet scenario compile_role <role_name>

Alternatively, as long as the node terminus is set in your main stanza of
puppet.conf,you can run:

    puppet node find --certname controller

To see the exact data that is returned to Puppet for a specific node.

### Role Mappings

You can map roles to nodes (via puppet cert names) in the file: ``data/role_mappings.yaml``

For example, if the I run the following puppet command

    puppet agent --certname controller

Then I can map that certname to a role in this file:

    controller: controller

> NOTE: certname defaults to hostname when not provided


## Getting started as a developer

If you intend to expand the data model, you should be familiar with
how it work.

[Data model Documentation](https://github.com/bodepd/scenario_node_terminus/blob/master/README.md)

There are may ways that you may wish to extend the data model.

- adding new scenarios
- addition new backends for openstack components
- updating default data
- Adding new data mappings

### Adjusting Scenarios

New scenarios should be added here:

    data/scenario/<new_scenario>.yaml

When you add a new scenario, you also need to consider what data mappings
and hiera data defaults should be supplied with that scenario.

### Adding new global config

When you add new global config, you should consider the following:

* are there additional roles that should be added when this data is set?
* should classes be added to any existing roles?
* are there specific data mappings that should be added?
* are there defaults that should be set for this data?

You will also need to add this data to you hierarchy.

### Setting data defaults

The default value to the provided for a class parameter should be supplied
in the hier\_data directory.

First, identify when the default value should be set.

1. If it should be set by default, it belongs in common.yaml
2. If this default is specific to a scenario, it should be set in scenarios/<scenario\_name>.yaml
3. If it is based on a global parameter, it should be supplied in the hiera data file for that
parameter.

### Setting user specific data

All data that a user should supply should be set as a data mapping.


## CI/CD specific constructs:

### nodes

Nodes are currently used to express the nodes that can be built
in order to test deployments of various scenarios. This is currently
used for deployments for CI.

Casual users should be able to ignore this.

We are currently performing research to see if this part of the data
should be replaces by a HEAT template.

## scenario command line tools

For a full list of debugging tools, run:

    puppet help scenario

More in-depth documentation be be found [here](https://github.com/bodepd/scenario_node_terminus#command-line-debugging-tools).
