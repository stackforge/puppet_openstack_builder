#
# this script is responsible for performing initial setup
# configurations that are only necessary for our virtual
# box based installations.
#


# setup up puppetlabs repos and install Puppet 3.2
#
# it makes my life easier if I can assume Puppet 3.2
# b/c then the other manifests can utilize hiera!
# this is not required for bare-metal b/c we can assume
# that Puppet will be installed on the bare-metal nodes
# with the correct version
include puppet::repo::puppetlabs
package { 'puppet':
  # I really wish this could be a
  ensure => '3.2.1-1puppetlabs1',
}

# dns resolution should be setup correctly
host {
  'build-server': ip => '192.168.242.100', host_aliases => 'build-server.domain.name';
}

# set up our hiera-store!
file { "${settings::confdir}/hiera.yaml":
  content =>
'
---
:backends:
  - yaml
:hierarchy:
  - "%{hostname}"
  - jenkins
  - common
:yaml:
   :datadir: /etc/puppet/hiera_data'
}

# lay down a file that you run run for testing
file { '/root/run_puppet.sh':
  content =>
  "#!/bin/bash
  puppet apply --modulepath /etc/puppet/modules-0/ --certname ${clientcert} /etc/puppet/manifests/site.pp $*"
}
