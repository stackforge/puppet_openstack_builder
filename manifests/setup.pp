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
package { 'puppet-common':
  ensure => '3.2.2-1puppetlabs1',
}
package { 'puppet':
  ensure  => '3.2.2-1puppetlabs1',
  require => Package['puppet-common'],
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
  - "%{openstack_role}"
  - "%{role}"
  - common
:yaml:
   :datadir: /etc/puppet/hiera_data'
}

# lay down a file that can be used for subsequent runs to puppet. Often, the
# only thing that you want to do after the initial provisioning of a box is
# to run puppet again. This command lays down a script that can be simply used for
# subsequent runs
file { '/root/run_puppet.sh':
  content =>
  "#!/bin/bash
  puppet apply --modulepath /etc/puppet/modules-0/ --certname ${clientcert} /etc/puppet/manifests/site.pp $*"
}

package { ['git', 'curl', 'vim', 'cobbler']:
  ensure => present,
}
