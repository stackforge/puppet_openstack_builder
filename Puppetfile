# the account where the Openstack modules should come from
#
# this file also accepts a few environment variables
#
git_protocol=ENV['git_protocol'] || 'git'
openstack_version=ENV['openstack_version'] || 'grizzly'

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

if ENV['repos_to_use']  == 'downstream'
  if openstack_version != 'grizzly'
    abort('Cisco packages only support grizzly')
  end
  # this assumes downstream which is the Cisco branches
  branch_name               = 'origin/grizzly'
  openstack_module_branch   = branch_name
  openstack_module_account  = 'CiscoSystems'
  neutron_name              = 'quantum'
  puppetlabs_module_prefix = 'CiscoSystems/puppet-'
  # manifests
  user_name = 'CiscoSystems'
  release         = 'grizzly'
  manifest_branch = 'origin/multi-node'
  mysql_ref       = ''
  apache_branch   = 'origin/grizzly'
  mysql_branch    = 'origin/grizzly'
  rabbitmq_branch = 'origin/grizzly'
else
  if openstack_version == 'grizzly'
    openstack_module_branch   = 'origin/stable/grizzly'
    neutron_name              = 'quantum'
  elsif openstack_version == 'havana'
    openstack_module_branch   = 'master'
    neutron_name              = 'neutron'
  else
    abort('only grizzly and havana are supported atm')
  end
  # use the upstream modules where they exist
  branch_name               = 'master'
  openstack_module_account  = 'stackforge'
  puppetlabs_module_prefix  = 'puppetlabs/puppetlabs-'
  # manifests
  user_name = 'bodepd'
  release = 'grizzly'
  manifest_branch = 'origin/master'
  apache_branch   = 'origin/0.x'
  mysql_branch    = 'origin/0.x'
  rabbitmq_branch = 'origin/2.x'
end

base_url = "#{git_protocol}://github.com"

###### Installer Manifests ##############
mod 'manifests', :git => "#{base_url}/#{user_name}/#{release}-manifests", :ref => "#{manifest_branch}"

###### module under development #####

# this following modules are still undergoing their initial development
# and have not yet been ported to CiscoSystems.

# This top level module contains the roles that are used to deploy openstack
mod 'bodepd/hiera_data_mapper',  :git => 'https://github.com/bodepd/hiera_data_mapper'
mod 'bodepd/scenario_node_terminus', :git => 'https://github.com/bodepd/scenario_node_terminus'

mod 'CiscoSystems/coi', :git => "#{base_url}/CiscoSystems/puppet-COI", :ref => 'master'
# no existing downstream module
mod 'puppetlabs/postgresql', :git => "#{base_url}/puppetlabs/puppetlabs-postgresql", :ref => '2.5.0'
mod 'puppetlabs/puppetdb', :git => "#{base_url}/puppetlabs/puppetlabs-puppetdb", :ref => 'master'
mod 'puppetlabs/vcsrepo', :git => "#{base_url}/puppetlabs/puppetlabs-vcsrepo", :ref => 'master'
mod 'ripienaar/ruby-puppetdb', :git => "#{base_url}/ripienaar/ruby-puppetdb"
mod 'ripienaar/catalog-diff', :git => "#{base_url}/ripienaar/puppet-catalog-diff", :ref => 'master'
# do I really need this firewall module?
mod 'puppetlabs/firewall', :git => "#{base_url}/puppetlabs/puppetlabs-firewall", :ref => 'master'
# stephenrjohnson
# this what I am testing Puppet 3.2 deploys with
# I am pointing it at me until my patch is accepted
mod 'stephenjohrnson/puppet', :git => "#{base_url}/stephenrjohnson/puppetlabs-puppet", :ref => 'master'
# stephen johnson's puppet module does not work with the older ciscosystems version of apache
mod 'CiscoSystems/apache', :git => "#{base_url}/#{puppetlabs_module_prefix}apache", :ref => apache_branch

###### stackforge openstack modules #####

openstack_repo_prefix = "#{base_url}/#{openstack_module_account}/puppet"

mod 'stackforge/openstack', :git => "#{openstack_repo_prefix}-openstack", :ref => openstack_module_branch
mod 'stackforge/cinder',    :git => "#{openstack_repo_prefix}-cinder",    :ref => openstack_module_branch
mod 'stackforge/glance',    :git => "#{openstack_repo_prefix}-glance",    :ref => openstack_module_branch
mod 'stackforge/keystone',  :git => "#{openstack_repo_prefix}-keystone",  :ref => openstack_module_branch
mod 'stackforge/horizon',   :git => "#{openstack_repo_prefix}-horizon",   :ref => openstack_module_branch
mod 'stackforge/nova',
  :git => "#{openstack_repo_prefix}-nova",
  :ref => openstack_module_branch
mod "stackforge/#{neutron_name}",
  :git => "#{openstack_repo_prefix}-neutron",
  :ref => openstack_module_branch
mod 'stackforge/swift',     :git => "#{openstack_repo_prefix}-swift",     :ref => openstack_module_branch
mod 'stackforge/ceilometer',:git => "#{openstack_repo_prefix}-ceilometer",:ref => openstack_module_branch
mod 'stackforge/tempest',:git => "#{openstack_repo_prefix}-tempest",:ref => openstack_module_branch

##### Puppet Labs modules #####

openstack_repo_prefix = "#{base_url}/#{openstack_module_account}/puppet"

mod 'CiscoSystems/apt', :git => "#{base_url}/CiscoSystems/puppet-apt", :ref => 'origin/grizzly'
mod 'CiscoSystems/stdlib', :git => "#{base_url}/#{puppetlabs_module_prefix}stdlib", :ref => branch_name
mod 'CiscoSystems/xinetd', :git => "#{base_url}/#{puppetlabs_module_prefix}xinetd", :ref => branch_name
mod 'CiscoSystems/ntp', :git => "#{base_url}/#{puppetlabs_module_prefix}ntp", :ref => branch_name
mod 'CiscoSystems/rsync', :git => "#{base_url}/#{puppetlabs_module_prefix}rsync", :ref => branch_name
mod 'CiscoSystems/mysql', :git => "#{base_url}/#{puppetlabs_module_prefix}mysql", :ref => mysql_branch
mod 'CiscoSystems/rabbitmq', :git => "#{base_url}/#{puppetlabs_module_prefix}rabbitmq", :ref => rabbitmq_branch


##### modules with other upstreams #####

# upstream is ripienaar
mod 'ripienaar/concat', :git => "#{base_url}/CiscoSystems/puppet-concat", :ref => 'origin/grizzly'

# upstream is cprice-puppet/puppetlabs-inifile
mod 'CiscoSystems/inifile', :git => "#{base_url}/CiscoSystems/puppet-inifile", :ref => 'origin/grizzly'

# upstream is saz
mod 'CiscoSystems/memcached', :git => "#{base_url}/CiscoSystems/puppet-memcached", :ref => 'origin/grizzly'
# this uses master b/c the grizzly branch does not exist
mod 'CiscoSystems/ssh',  :git => "#{base_url}/bodepd/puppet-ssh", :ref => 'master'

# upstream is duritong
mod 'CiscoSystems/sysctl', :git => "#{base_url}/CiscoSystems/puppet-sysctl", :ref => 'origin/grizzly'

# unclear who the upstream is
mod 'CiscoSystems/vswitch', :git => "#{base_url}/CiscoSystems/puppet-vswitch", :ref => 'origin/grizzly'


##### Modules without upstreams #####

# TODO - this is still pointing at my fork
mod 'CiscoSystems/coe', :git => "#{base_url}/CiscoSystems/puppet-coe", :ref => 'origin/grizzly'
mod 'CiscoSystems/cobbler', :git => "#{base_url}/CiscoSystems/puppet-cobbler", :ref => 'origin/grizzly'
mod 'CiscoSystems/apt-cacher-ng', :git => "#{base_url}/CiscoSystems/puppet-apt-cacher-ng", :ref => 'origin/grizzly'
mod 'CiscoSystems/collectd', :git => "#{base_url}/pkilambi/puppet-module-collectd", :ref => 'master'
# based on pradeep's fork
# this is forked and needs to be updated
mod 'CiscoSystems/graphite', :git => "#{base_url}/bodepd/puppet-graphite/", :ref => 'master'
#mod 'CiscoSystems/monit', :git => "#{base_url}/CiscoSystems/puppet-monit", :ref => 'origin/grizzly'
mod 'CiscoSystems/pip', :git => "#{base_url}/CiscoSystems/puppet-pip", :ref => 'origin/grizzly'

mod 'CiscoSystems/dnsmasq', :git => "#{base_url}/CiscoSystems/puppet-dnsmasq", :ref => 'origin/grizzly'
mod 'CiscoSystems/naginator', :git => "#{base_url}/CiscoSystems/puppet-naginator", :ref => 'origin/grizzly'
