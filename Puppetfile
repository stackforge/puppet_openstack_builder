# the account where the Openstack modules should come from
#
# this file also accepts a few environment variables
#
git_protocol=ENV['git_protocol'] || 'git'

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
  # this assumes downstream which is the Cisco branches
  branch_name               = 'origin/grizzly'
  openstack_module_branch   = branch_name
  openstack_module_account  = 'CiscoSystems'
  puppetlabs_module_account = 'CiscoSystems'
  # manifests
  user_name = 'CiscoSystems'
  release = 'grizzly'
  manifest_branch = 'origin/multi-node'
else
  # use the upstream modules where they exist
  branch_name               = 'origin/grizzly'
  openstack_module_branch   = 'master'
  openstack_module_account  = 'stackforge'
  puppetlabs_module_account = 'puppetlabs'
  # manifests
  user_name = 'bodepd'
  release = 'grizzly'
  manifest_branch = 'origin/master'
end

base_url = "#{git_protocol}://github.com"

###### Installer Manifests ##############
mod 'manifests', :git => "#{base_url}/#{user_name}/#{release}-manifests", :ref => "#{manifest_branch}"

###### module under development #####

# this following modules are still undergoing their initial development
# and have not yet been ported to CiscoSystems.

# This top level module contains the roles that are used to deploy openstack

mod 'CiscoSystems/coi', :git => "#{base_url}/CiscoSystems/puppet-COI", :ref => 'master'
# no existing downstream module
mod 'puppetlabs/postgresql', :git => "#{base_url}/puppetlabs/puppetlabs-postgresql", :ref => 'master'
mod 'puppetlabs/puppetdb', :git => "#{base_url}/puppetlabs/puppetlabs-puppetdb", :ref => 'master'
mod 'puppetlabs/vcsrepo', :git => "#{base_url}/puppetlabs/puppetlabs-vcsrepo", :ref => 'master'
mod 'ripienaar/ruby-puppetdb', :git => "#{base_url}/ripienaar/ruby-puppetdb"
# do I really need this firewall module?
mod 'puppetlabs/firewall', :git => "#{base_url}/puppetlabs/puppetlabs-firewall", :ref => 'master'
# stephenrjohnson
# this what I am testing Puppet 3.2 deploys with
# I am pointing it at me until my patch is accepted
mod 'stephenjohrnson/puppet', :git => "#{base_url}/stephenrjohnson/puppetlabs-puppet", :ref => 'master'

###### stackforge openstack modules #####

openstack_repo_prefix = "#{base_url}/#{openstack_module_account}/puppet"

mod 'stackforge/openstack', :git => "#{openstack_repo_prefix}-openstack", :ref => openstack_module_branch
mod 'stackforge/cinder',    :git => "#{openstack_repo_prefix}-cinder",    :ref => openstack_module_branch
mod 'stackforge/glance',    :git => "#{openstack_repo_prefix}-glance",    :ref => openstack_module_branch
mod 'stackforge/keystone',  :git => "#{openstack_repo_prefix}-keystone",  :ref => openstack_module_branch
mod 'stackforge/horizon',   :git => "#{openstack_repo_prefix}-horizon",   :ref => openstack_module_branch
mod 'stackforge/nova',      :git => "#{openstack_repo_prefix}-nova",      :ref => openstack_module_branch
mod 'stackforge/quantum',   :git => "#{openstack_repo_prefix}-quantum",   :ref => openstack_module_branch
mod 'stackforge/swift',     :git => "#{openstack_repo_prefix}-swift",     :ref => openstack_module_branch
mod 'stackforge/ceilometer',:git => "#{openstack_repo_prefix}-ceilometer",:ref => openstack_module_branch
mod 'stackforge/tempest',:git => "#{openstack_repo_prefix}-tempest",:ref => openstack_module_branch

##### Puppet Labs modules #####

openstack_repo_prefix = "#{base_url}/#{openstack_module_account}/puppet"

mod 'CiscoSystems/apt', :git => "#{base_url}/CiscoSystems/puppet-apt", :ref => branch_name
mod 'CiscoSystems/stdlib', :git => "#{base_url}/CiscoSystems/puppet-stdlib", :ref => branch_name
mod 'CiscoSystems/xinetd', :git => "#{base_url}/CiscoSystems/puppet-xinetd", :ref => branch_name
mod 'CiscoSystems/ntp', :git => "#{base_url}/CiscoSystems/puppet-ntp", :ref => branch_name
mod 'CiscoSystems/rsync', :git => "#{base_url}/CiscoSystems/puppet-rsync", :ref => branch_name
mod 'CiscoSystems/mysql', :git => "#{base_url}/CiscoSystems/puppet-mysql", :ref => branch_name
mod 'CiscoSystems/rabbitmq', :git => "#{base_url}/CiscoSystems/puppet-rabbitmq", :ref => branch_name
mod 'CiscoSystems/apache', :git => "#{base_url}/CiscoSystems/puppet-apache", :ref => branch_name


##### modules with other upstreams #####

# upstream is ripienaar
mod 'ripienaar/concat', :git => "#{base_url}/CiscoSystems/puppet-concat", :ref => 'origin/grizzly'

# upstream is cprice-puppet/puppetlabs-inifile
mod 'CiscoSystems/inifile', :git => "#{base_url}/CiscoSystems/puppet-inifile", :ref => branch_name

# upstream is saz
mod 'CiscoSystems/memcached', :git => "#{base_url}/CiscoSystems/puppet-memcached", :ref => branch_name
# this uses master b/c the grizzly branch does not exist
mod 'CiscoSystems/ssh',  :git => "#{base_url}/CiscoSystems/puppet-ssh", :ref => 'master'

# upstream is duritong
mod 'CiscoSystems/sysctl', :git => "#{base_url}/CiscoSystems/puppet-sysctl", :ref => branch_name

# unclear who the upstream is
mod 'CiscoSystems/vswitch', :git => "#{base_url}/CiscoSystems/puppet-vswitch", :ref => branch_name


##### Modules without upstreams #####

# TODO - this is still pointing at my fork
mod 'CiscoSystems/coe', :git => "#{base_url}/CiscoSystems/puppet-coe", :ref => branch_name
mod 'CiscoSystems/cobbler', :git => "#{base_url}/CiscoSystems/puppet-cobbler", :ref => branch_name
mod 'CiscoSystems/apt-cacher-ng', :git => "#{base_url}/CiscoSystems/puppet-apt-cacher-ng", :ref => branch_name
mod 'CiscoSystems/collectd', :git => "#{base_url}/pkilambi/puppet-module-collectd", :ref => 'master'
# based on pradeep's fork
# this is forked and needs to be updated
mod 'CiscoSystems/graphite', :git => "#{base_url}/bodepd/puppet-graphite/", :ref => 'master'
mod 'CiscoSystems/monit', :git => "#{base_url}/CiscoSystems/puppet-monit", :ref => branch_name
mod 'CiscoSystems/pip', :git => "#{base_url}/CiscoSystems/puppet-pip", :ref => branch_name

mod 'CiscoSystems/dnsmasq', :git => "#{base_url}/CiscoSystems/puppet-dnsmasq", :ref => branch_name
mod 'CiscoSystems/naginator', :git => "#{base_url}/CiscoSystems/puppet-naginator", :ref => branch_name
