require 'yaml'
# -*- mode: ruby -*-
# vi: set ft=ruby :

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
    'node_group'      => 'multi_node'
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
def process_nodes(config, v_config, apt_cache_proxy)

  node_group      = v_config['node_group']
  node_group_file = File.expand_path(File.join(File.dirname(__FILE__), 'data', 'nodes', "#{node_group}.yaml"))

  abort('node_group much be specific in config') unless node_group
  abort('file must exist for node group') unless File.exists?(node_group_file)

  (YAML.load_file(node_group_file)['nodes'] || {}).each do |name, options|
    config.vm.define name.intern do |config|
      configure_openstack_node(
        config,
        options['hostname'],
        options['memory'],
        options['image_name'] || v_config['operatingsystem'],
        options['ip_number'],
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
def apply_manifest(config, v_config, manifest_name='site.pp')

  options = []

  if v_config['verbose']
    options = options + ['--verbose', '--trace', '--debug', '--show_diff']
  end

  # ensure that when puppet applies the site manifest, it has hiera configured
  if manifest_name == 'site.pp'
    config.vm.share_folder("data", '/etc/puppet/data', './data')
  end

  # Explicitly mount the shared folders, so we dont break with newer versions of vagrant
  config.vm.share_folder("modules", '/etc/puppet/modules', './modules/')
  config.vm.share_folder("manifests", '/etc/puppet/manifests', './manifests/')
  

  config.vm.provision(:puppet, :pp_path => "/etc/puppet") do |puppet|
    puppet.manifests_path = 'manifests'
    puppet.manifest_file  = manifest_name
    puppet.module_path    = 'modules'
    puppet.options        = options
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
  master = 'build-server.domain.name'
)
  options = ["--certname #{node_name}", '-t', '--pluginsync']

  if v_config['verbose']
    options = options + ['--trace', '--debug', '--show_diff']
  end

  config.vm.provision(:puppet_server) do |puppet|
    puppet.puppet_server = 'build-server.domain.name'
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
  apt_cache_proxy,
  v_config,
  post_config = false
)
  cert_name = node_name
  get_box(config, box_name)
  setup_hostname(config, node_name)
  config.vm.customize ["modifyvm", :id, "--memory", memory]
  setup_networks(config, net_id)
  if v_config['operatingsystem'] == 'ubuntu'
    configure_apt_mirror(config, v_config['apt_mirror'], apt_cache_proxy)
  end
  apply_manifest(config, v_config, 'setup.pp')
  run_puppet_agent(config, cert_name, v_config)

  if post_config
    config.vm.provision :shell do |shell|
      shell.inline  = post_config
    end
  end

end

# configure ubuntu based build node
def setup_ubuntu_build_server(config, v_config, apt_cache_proxy)
  config.vm.define :build do |config|
    get_box(config, 'precise64')
    setup_networks(config, '100')
    setup_hostname(config, 'build-server')

    config.vm.customize ["modifyvm", :id, "--memory", 2525]

    # Configure apt mirror
    config.vm.provision :shell do |shell|
      shell.inline = "sed -i 's/us.archive.ubuntu.com/%s/g' /etc/apt/sources.list" % v_config['apt_mirror']
    end
    # Ensure DHCP isn't going to join us to a domain other than domain.name
    # since puppet has to sign its cert against the domain it makes when it runs.
    config.vm.provision :shell do |shell|
      shell.inline = "sed -i 's/\#supersede/supersede/g' /etc/dhcp/dhclient.conf; sed -i 's/fugue.com home.vix.com/%s/g' /etc/dhcp/dhclient.conf; sed -i 's/domain-name,//g' /etc/dhcp/dhclient.conf" % v_config['domain']
    end

    config.vm.provision :shell do |shell|
      shell.inline = "%s apt-get update; dhclient -r eth0 && dhclient eth0;" % apt_cache_proxy
    end

    apply_manifest(config, v_config, 'setup.pp')

    # pre-import the ubuntu image if we are using a custom mirror
    if v_config['apt-mirror'] != 'us.archive.ubuntu.com'
      config.vm.provision :shell do |shell|
        shell.inline = "cobbler-ubuntu-import -c precise-x86_64; if [ $? == '0' ]; then apt-get install -y cobbler; cobbler-ubuntu-import -m http://%s/ubuntu precise-x86_64; fi" % v_config['apt_mirror']
      end
    end

    apply_manifest(config, v_config)

    # Configure puppet
    config.vm.provision :shell do |shell|
      shell.inline = 'puppet plugin download --server build-server.domain.name;service apache2 restart'
    end
    # enable ip forwarding and NAT so that the build server can act
    # as an external gateway for the quantum router.
    config.vm.provision :shell do |shell|
        shell.inline = "ip addr add 172.16.2.1/24 dev eth2; sysctl -w net.ipv4.ip_forward=1; iptables -A FORWARD -o eth0 -i eth1 -s 172.16.2.0/24 -m conntrack --ctstate NEW -j ACCEPT; iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT; iptables -t nat -F POSTROUTING; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE"
    end
  end
end


# configure redhat based build node
def setup_redhat_build_server(config, v_config)
  config.vm.define :build do |config|
    get_box(config, 'centos')
    setup_networks(config, '100')
    setup_hostname(config, 'build-server')

    config.vm.customize ["modifyvm", :id, "--memory", 2525]

    # Ensure DHCP isn't going to join us to a domain other than domain.name
    # since puppet has to sign its cert against the domain it makes when it runs.
    config.vm.provision :shell do |shell|
      shell.inline = "sed -i '$ a\ supersede domain-search %s;' /etc/dhcp/dhclient-eth0.conf;" % v_config['domain']
    end

    config.vm.provision :shell do |shell|
      shell.inline = "sed -i 's/.*search.*/search %s/g' /etc/resolv.conf;" % v_config['domain']
    end

    apply_manifest(config, v_config, 'setup.pp')

    apply_manifest(config, v_config)

    # Configure puppet
    config.vm.provision :shell do |shell|
      shell.inline = 'puppet plugin download --server build-server.domain.name;service httpd restart'
    end
    
    # enable ip forwarding and NAT so that the build server can act
    # as an external gateway for the quantum router.
    config.vm.provision :shell do |shell|
        shell.inline = "ip addr add 172.16.2.1/24 dev eth2; sysctl -w net.ipv4.ip_forward=1; iptables -A FORWARD -o eth0 -i eth1 -s 172.16.2.0/24 -m conntrack --ctstate NEW -j ACCEPT; iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT; iptables -t nat -F POSTROUTING; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE"
    end
  end
end
  
Vagrant::Config.run do |config|
  require 'fileutils'

  v_config = parse_vagrant_config

  apt_cache_proxy = ''
  if v_config['apt_cache'] != 'false'
   apt_cache_proxy = 'echo "Acquire::http { Proxy \"http://%s:3142\"; };" > /etc/apt/apt.conf.d/01apt-cacher-ng-proxy;' % v_config['apt_cache'] 
  end

  config.vm.define :cache do |config|
    get_box(config, v_config['operatingsystem'])
    setup_networks(config, '99')
    setup_hostname(config, 'cache')
    apply_manifest(config, v_config, 'setup.pp')
    apply_manifest(config, v_config)
  end

  # setup "build" server
  if v_config['operatingsystem'] == 'ubuntu'
    setup_ubuntu_build_server(config, v_config, apt_cache_proxy)
  elsif v_config['operatingsystem'] == 'redhat'
    setup_redhat_build_server(config, v_config)
  end

  # Openstack control server
#  config.vm.define :control_pxe do |config|
#    config.vm.box = 'blank'
#    config.vm.boot_mode = 'gui'
#    config.ssh.port = 2727
#    setup_networks(config, '10', :eth1_mac => '001122334455')
#  end

  # Openstack compute server
#  config.vm.define :compute_pxe do |config|
#    config.vm.box = 'blank'
#    config.vm.boot_mode = 'gui'
#    config.ssh.port = 2728
#    setup_networks(config, '10', :eth1_mac => '001122334466')
#  end

  process_nodes(config, v_config, apt_cache_proxy)

end
