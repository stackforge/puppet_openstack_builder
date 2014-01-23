This folder contains a bootstrap script and heat templates for instantiating the data model on an openstack cloud.

## Heat templates

The heat templates rely on an existing network with an external route. Currently there is only 2\_role.yaml, but it shouldn't be hard to add more for other scenarios. The templates are not complete and creating them with heat without injecting metadata won't do anything useful. There is a tool called scenariobuilder that can do this for you, injecting the user.yaml, global\_hiera\_params/user.yaml, and config.yaml data into each instance, and adding the bootstrap as user data, before writing out a heat.yaml:

  cd puppet\_openstack\_builder
  pip install scenariobuilder
  . openrc
  sb heat
  heat stack-create ci --template-file=heat.yaml --parameters="ci_network_id=03584196-cb32-4465-9e89-ac6990f70e98;ci_subnet_id=f07e4b6a-e515-477f-9276-da8f193f359f"

## Bootstrap.sh

This script will prepare a node to act as either a puppet master or client in a cluster managed using this data model. Inline python is used to parse the metadata json that is passed to each node and copy data to the config directory.

## Configuration

Configuration can only be done via config.yaml, user.yaml and global\_hiera\_params/user.yaml. Although there are configuration options for a proxy, they may be incomplete as this method has not been tested extensively.

