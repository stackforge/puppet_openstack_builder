# what do all of these folders mean?

## config.yaml

config.yaml is full of global variables that are used
to determine what 'type' of reference architecture you wish
to deploy.

These variables are used by hiera to determine both what
classes are included, and are also used to drive the hierarchical
lookup.

The variables are:

  *scenario* scenario is used to select the specific references architecture
  that you wish to deploy. It is used to select the roles for that scenario
  from the scenarios/<scenario>.yaml file, as well as the nodes to use from
  nodes/<scenario>/yaml (for deployment of CI). It is also used as a hiera
  lookup and data mapping hierarchy.

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

  *password_management* selects the type of password management you wish to use.
  This is used by the data\_mapper to determine how password values map to services.
  Default to individual, which means that individual password are used for everything.

  *enabled_services* Used to select all of the services that are enabled. This is
  used to determine what endpoints and databases should be configured.

## scenarios

Scenarios are used to describe the reference architecture that you wish to
deploy.

The scenario to be selected is driven by the scenario
key in config.yaml.

Each of the roles for a specific scenario is specified in its scenario
file:

  data/scenario/<scenario>.yaml

This file defines what roles exists for a specific scenario, and which classes
should be assigned to those roles.

## class groups

Class groups are simply a list of classes that can be referred
to as a single name. Class groups are used to store combinations
of classes for reuse.

## data mappings

Data mappings are used to express the way in which
global variables from hiera map to individual class parameters.

Previous, this was done with parameter forwarding in parameterized
classes.

## hiera data

hiera data is used to express what values are going to be used to
configure your openstack services.

hiera data is used to either express global keys (that were mapped to
class parameters in the data mappings), or fully qualified class parameter
namespaces.

## nodes

Nodes are currently used to express the nodes that can be built
in order to test deployments of various scenarios. This is currently
used for deployments for CI.

We are currently performing research to see if this part of the data
should be replaces by a HEAT template.

## role\_mappings

role\_mappings is used to map Puppet certnames to roles.

## discovered modeling issues (please ignore, unless you are Dan :) )

### Issue 1

some data values map to multiple combined values:

   ex: mysql\_connection => db\_name, password, host, user, type

##### solutions

1. accept sql\_connection from hiera for each service

This is problematic b/c it will lead to data suplication, and not take advantage of
reasonable defaults

2. patch the components to accept the parts of the password and not the whole thing

That may not be the only occurrence.

It will have to be done in a backwards compat way

3. allow the value of the lookup to be resolvable as multiple lookups (and not a single one)

### Issue number 2

Some data effects the static values of what needs to be passed to other services

Ex: depending on the rpc\_type, the actual rpc\_backend passed to cinder is differnet.

#### solutions

1. add an extra parameter called rpc\_type to the class interfaces

2. add rpc\_type to the global data that drives configuration, and make it a variable
that drives the hierarchical configuration

### Issue 3

There is no way to have hiera drive whether or not individual components need to be installed

For now, this will need to be stored as global data that contains a list of the services that
you want to install

### Issue 4

where do we set assumed defaults?

examples:
  - cinder simple scheduler
  - charset for database (can we just set this as a default for the database?)
