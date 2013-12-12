# the account where the Openstack modules should come from
#
# this file also accepts a few environment variables
#
git_protocol=ENV['git_protocol'] || 'git'
openstack_version=ENV['openstack_version'] || 'havana'

#
# this modulefile has been configured to use two sets of repos.
# The downstream repos that Cisco has forked, or the upstream repos
# that they are derived from (and should be maintained in sync with)
#

#
# this is just targeting the upstream stackforge modules
# right now, and the logic for using downstream does not
# work yet
#

unless ['grizzly', 'havana'].include?(openstack_version)
  abort("Only grizzly and havana are currently supported")
end

if openstack_version == 'grizzly'
  neutron_name = 'quantum'
else
  neutron_name = 'neutron'
end

if ENV['repos_to_use']  == 'downstream'
  # this assumes downstream which is the Cisco branches
  branch_name               = "origin/#{openstack_version}"
  cisco_branch_name         = branch_name
  openstack_module_branch   = branch_name
  openstack_module_account  = 'CiscoSystems'
  puppetlabs_module_prefix = 'CiscoSystems/puppet-'
  apache_branch   = branch_name
  mysql_branch    = branch_name
  rabbitmq_branch = branch_name
else
  if openstack_version == 'grizzly'
    openstack_module_branch   = 'origin/stable/grizzly'
  elsif openstack_version == 'havana'
    openstack_module_branch   = 'master'
  else
    abort('only grizzly and havana are supported atm')
  end
  # use the upstream modules where they exist
  branch_name               = 'master'
  cisco_branch_name         = "origin/#{openstack_version}"
  openstack_module_account  = 'stackforge'
  puppetlabs_module_prefix  = 'puppetlabs/puppetlabs-'
  apache_branch   = 'origin/0.x'
  mysql_branch    = 'origin/0.x'
  rabbitmq_branch = 'origin/2.x'
end

base_url = "#{git_protocol}://github.com"

###### module under development #####

# this following modules are still undergoing their initial development
# and have not yet been ported to CiscoSystems.

mod 'bodepd/scenario_node_terminus',
  :git => 'https://github.com/bodepd/scenario_node_terminus'
mod 'CiscoSystems/coi',
  :git => "#{base_url}/CiscoSystems/puppet-coi",
  :ref => cisco_branch_name
mod 'puppetlabs/postgresql',
  :git => "#{base_url}/puppetlabs/puppetlabs-postgresql",
  :ref => '2.5.0'
mod 'puppetlabs/puppetdb',
  :git => "#{base_url}/puppetlabs/puppetlabs-puppetdb",
  :ref => '2.0.0'
mod 'puppetlabs/vcsrepo',
  :git => "#{base_url}/puppetlabs/puppetlabs-vcsrepo",
  :ref => '0.1.2'
mod 'ripienaar/ruby-puppetdb',
  :git => "#{base_url}/ripienaar/ruby-puppetdb"
mod 'ripienaar/catalog-diff',
  :git => "#{base_url}/ripienaar/puppet-catalog-diff",
  :ref => 'master'
mod 'puppetlabs/firewall',
  :git => "#{base_url}/puppetlabs/puppetlabs-firewall",
  :ref => '0.4.0'
mod 'stephenjohrnson/puppet',
  :git => "#{base_url}/stephenrjohnson/puppetlabs-puppet",
  :ref => '0.0.18'

###### stackforge openstack modules #####

openstack_repo_prefix = "#{base_url}/#{openstack_module_account}/puppet-"

[
  'openstack',
  'cinder',
  'glance',
  'keystone',
  'horizon',
  'nova',
  neutron_name,
  'swift',
  'tempest',
  'heat',
].each do |module_name|
  mod "stackforge/#{module_name}",
    :git => "#{openstack_repo_prefix}#{module_name}",
    :ref => openstack_module_branch
end

# stackforge module with no grizzly release
[
  'ceilometer',
  'vswitch'
].each do |module_name|
  mod "stackforge/#{module_name}",
    :git => "#{openstack_repo_prefix}#{module_name}",
    :ref => 'master'
end

##### Puppet Labs modules #####


# this module needs to be alighed with upstream
mod 'puppetlabs/apt',
  :git => "#{base_url}/CiscoSystems/puppet-apt",
  :ref => cisco_branch_name

[
  'stdlib',
  'xinetd',
  'ntp',
  'rsync',
  'inifile',
  'mongodb'
].each do |module_name|
  mod "puppetlabs/#{module_name}",
    :git => "#{base_url}/#{puppetlabs_module_prefix}#{module_name}",
    :ref => branch_name
end

## PuppetLabs modules that are too unstable to use master ##
{
  'mysql'    => mysql_branch,
  'rabbitmq' => rabbitmq_branch,
  'apache'   => apache_branch
}.each do |module_name, ref|
  mod "puppetlabs/#{module_name}",
    :git => "#{base_url}/#{puppetlabs_module_prefix}#{module_name}",
    :ref => ref
end

##### modules with other upstreams #####

mod 'saz/memcached',
  :git => "#{base_url}/CiscoSystems/puppet-memcached",
  :ref => cisco_branch_name
mod 'saz/ssh',
  :git => "#{base_url}/bodepd/puppet-ssh",
  :ref => 'master'
mod 'duritong/sysctl',
  :git => "#{base_url}/CiscoSystems/puppet-sysctl",
  :ref => cisco_branch_name

##### Modules without upstreams #####

cisco_module_prefix = "#{base_url}/CiscoSystems/puppet-"

[
  'cephdeploy',
  'coe',
  'cobbler',
  'concat',
  'apt-cacher-ng',
  'collectd',
  'graphite',
  'pip',
  'dnsmasq',
  'naginator'
].each do |module_name|
  mod "CiscoSystems/#{module_name}",
    :git => "#{cisco_module_prefix}#{module_name}",
    :ref => cisco_branch_name
end

#### HA Modules ###

[
  'augeas',
  'filemapper',
  'galera',
  'haproxy',
  'keepalived',
  'network',
  'openstack-ha',
  'boolean'
].each do |module_name|
  mod "CiscoSystems/#{module_name}",
    :git => "#{cisco_module_prefix}#{module_name}",
    :ref => cisco_branch_name
end
