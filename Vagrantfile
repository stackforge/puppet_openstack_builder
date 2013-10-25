# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'yaml'
require 'fileutils'

# Four networks:
# 0 - VM host NAT
# 1 - COE build/deploy
# 2 - COE openstack internal
# 3 - COE openstack external (public)

def parse_vagrant_config(
  config_file=File.expand_path(File.join(File.dirname(__FILE__), 'data', 'config.yaml'))
)
  config = {
    'gui_mode'        => false,
    'operatingsystem' => 'ubuntu',
    'verbose'         => false,
    'update_repos'    => true,
    'scenario'        => '2_role'
  }
  if File.exists?(config_file)
    overrides = YAML.load_file(config_file)
    config.merge!(overrides)
  end
  config
end

#
# process the node group that is used to determine the
# nodes that should be provisioned. The group of nodes
# can be set with the node_group param from config.yaml
# and maps to its corresponding file in the nodes directory.
#
def process_nodes(config)

  v_config = parse_vagrant_config

  node_group      = v_config['scenario']
  node_group_file = File.expand_path(File.join(File.dirname(__FILE__), 'data', 'nodes', "#{node_group}.yaml"))

  abort('node_group much be specific in config') unless node_group
  abort('file must exist for node group') unless File.exists?(node_group_file)

  (YAML.load_file(node_group_file)['nodes'] || {}).each do |name, options|
    config.vm.define(options['vagrant_name'] || name) do |config|
      apt_cache_proxy = ''
      unless options['apt_cache'] == false || options['apt_cache'] == 'false'
        if v_config['apt_cache'] != 'false'
          apt_cache_proxy = 'echo "Acquire::http { Proxy \"http://%s:3142\"; };" > /etc/apt/apt.conf.d/01apt-cacher-ng-proxy;' % ( options['apt_cache'] || v_config['apt_cache'] )
        end
      end
      configure_openstack_node(
        config,
        name,
        options['memory'],
        options['image_name'] || v_config['operatingsystem'],
        options['ip_number'],
        options['puppet_type'] || 'agent',
        apt_cache_proxy,
        v_config,
        options['post_config']
      )
    end
  end
end

# get the correct box based on the specidied type
# currently, this just retrieves a single box for precise64
def get_box(config, box_type)
  if box_type == 'precise64' || box_type == 'ubuntu'
    config.vm.box     = 'precise64'
    config.vm.box_url = 'http://files.vagrantup.com/precise64.box'
  elsif box_type == 'centos' || box_type == 'redhat'
    config.vm.box     = 'centos'
    config.vm.box_url = 'http://developer.nrel.gov/downloads/vagrant-boxes/CentOS-6.4-x86_64-v20130427.box'
  else
    abort("Box type: #{box_type} is no good.")
  end
end

#
# setup networks for openstack. Currently, this just sets up
# 4 virtual interfaces as follows:
#
#   * eth1 => 192.168.242.0/24
#     this is the network that the openstack services use to communicate with each other
#   * eth2 => 10.2.3.0/24
#   * eth3 => 10.2.3.0/24
#
# == Parameters
#   config - vm config object
#   number - the lowest octal in a /24 network
#   options - additional options
#     eth1_mac - mac address to set for eth1 (used for PXE booting)
#
def setup_networks(config, number, options = {})
  config.vm.network :hostonly, "192.168.242.#{number}", :mac => options[:eth1_mac]
  config.vm.network :hostonly, "10.2.3.#{number}"
  config.vm.network :hostonly, "10.3.3.#{number}"
  # set eth3 in promiscuos mode
  config.vm.customize ["modifyvm", :id, "--nicpromisc3", "allow-all"]
  # set the boot priority to use eth1
  config.vm.customize(['modifyvm', :id ,'--nicbootprio2','1'])
end

#
# setup the hostname of our box
#
def setup_hostname(config, hostname)
  config.vm.customize ['modifyvm', :id, '--name', hostname]
  config.vm.host_name = hostname
end

#
# run puppet apply on the site manifest
#
def apply_manifest(config, v_config, manifest_name='site.pp', certname=nil, puppet_type=nil)

  options = []

  if v_config['verbose']
    options = options + ['--verbose', '--trace', '--debug', '--show_diff']
  end

  if certname
    options.push("--certname #{certname}")
  else
    # I need to add a special certname here to
    # ensure it's hostname does not match the ENC
    # which could cause the node to be configured
    # from the setup manifest on the second run
    options.push('--certname setup')
  end

  # ensure that when puppet applies the site manifest, it has hiera configured
  if manifest_name == 'site.pp'
    config.vm.share_folder("data", '/etc/puppet/data', './data')
  end
  config.vm.share_folder("ssh", '/root/.ssh', './dot-ssh')

  # Explicitly mount the shared folders, so we dont break with newer versions of vagrant
  config.vm.share_folder("modules", '/etc/puppet/modules', './modules/')
  config.vm.share_folder("manifests", '/etc/puppet/manifests', './manifests/')

  config.vm.provision :shell do |shell|
    script =
      "if grep 127.0.1.1 /etc/hosts ; then \n" +
      " sed -i -e \"s/127.0.1.1.*/127.0.1.1 $(hostname).#{v_config['domain']} $(hostname)/\" /etc/hosts\n" +
      "else\n" +
      "  echo '127.0.1.1 $(hostname).#{v_config['domain']} $(hostname)' >> /etc/hosts\n" +
      "fi ;"
    shell.inline = script
  end

  config.vm.provision(:puppet, :pp_path => "/etc/puppet") do |puppet|
    puppet.manifests_path = 'manifests'
    puppet.manifest_file  = manifest_name
    puppet.module_path    = 'modules'
    puppet.options        = options
    puppet.facter = {
      "build_server_ip"          => "192.168.242.100",
      "build_server_domain_name" => v_config['domain'],
      "puppet_run_mode"          => puppet_type,
    }
  end

  # uninstall the puppet gem b/c setup.pp installs the puppet package
  if manifest_name == 'setup.pp'
    config.vm.provision :shell do |shell|
      shell.inline = "gem uninstall -x -a puppet;echo -e '#!/bin/bash\npuppet agent $@' > /sbin/puppetd;chmod a+x /sbin/puppetd"
    end
  end

end

# run the puppet agent
def run_puppet_agent(
  config,
  node_name,
  v_config = {},
  master = "build-server.#{v_config['domain']}"
)
  options = ["--certname #{node_name}", '-t', '--pluginsync']

  if v_config['verbose']
    options = options + ['--trace', '--debug', '--show_diff']
  end

  config.vm.provision(:puppet_server) do |puppet|
    puppet.puppet_server = master
    puppet.options       = options
  end
end

#
# configure apt repos with mirrors and proxies and what-not
# I really want to move this to puppet
#
def configure_apt_mirror(config, apt_mirror, apt_cache_proxy)
  # Configure apt mirror
  config.vm.provision :shell do |shell|
    shell.inline = "sed -i 's/us.archive.ubuntu.com/%s/g' /etc/apt/sources.list" % apt_mirror
  end

  config.vm.provision :shell do |shell|
    shell.inline = '%s apt-get update;apt-get install ubuntu-cloud-keyring' % apt_cache_proxy
  end
end

#
# methods that performs all openstack config
#
def configure_openstack_node(
  config,
  node_name,
  memory,
  box_name,
  net_id,
  puppet_type,
  apt_cache_proxy,
  v_config,
  post_config = false
)
  cert_name = node_name
  get_box(config, box_name)
  setup_hostname(config, node_name)
  config.vm.customize ["modifyvm", :id, "--memory", memory]
  setup_networks(config, net_id)
  if v_config['operatingsystem'] == 'ubuntu' and apt_cache_proxy
    configure_apt_mirror(config, v_config['apt_mirror'], apt_cache_proxy)
  end

  apply_manifest(config, v_config, 'setup.pp', nil, puppet_type)

  if puppet_type == 'apply'
    apply_manifest(config, v_config, 'site.pp', cert_name)
  elsif puppet_type == 'agent'
    run_puppet_agent(config, cert_name, v_config)
  else
    abort("Unexpected puppet_type #{puppet_type}")
  end

  if post_config
    Array(post_config).each do |shell_command|
      config.vm.provision :shell do |shell|
        shell.inline  = shell_command
      end
    end
  end

end

Vagrant::Config.run do |config|

  process_nodes(config)

end
