# -*- mode: ruby -*-
# vi: set ft=ruby :

# Four networks:
# 0 - VM host NAT
# 1 - COE build/deploy
# 2 - COE openstack internal
# 3 - COE openstack external (public)


def parse_vagrant_config(
  config_file=File.expand_path(File.join(File.dirname(__FILE__), 'config.yaml'))
)
  require 'yaml'
  config = {
    'gui_mode' => false,
    'operatingsystem' => 'ubuntu',
    'verbose' => false,
    'update_repos' => true
  }
  if File.exists?(config_file)
    overrides = YAML.load_file(config_file)
    config.merge!(overrides)
  end
  config
end

Vagrant::Config.run do |config|
  require 'fileutils'
  
  if !File.symlink?("templates")
    File.symlink("./modules/manifests/templates", "./templates")
  end
    
  if !File.symlink?("manifests")
    File.symlink("./modules/manifests/manifests", "./manifests")
  end

  if !File.file?("./manifests/site.pp") && File.file?("./manifests/site.pp.example")
    FileUtils.mv("./manifests/site.pp.example", "./manifests/site.pp")
  end
  
  v_config = parse_vagrant_config

  apt_cache_proxy = 'Acquire::http { Proxy \"http://%s:3142\"; };' % v_config['apt_cache']

  config.vm.define :cache do |cache_config|
    cache_config.vm.box = "precise64"
    cache_config.vm.box_url = 'http://files.vagrantup.com/precise64.box'
    cache_config.vm.network :hostonly, "192.168.242.99"
    cache_config.vm.network :hostonly, "10.2.3.99"
    cache_config.vm.network :hostonly, "10.3.3.99"
    cache_config.vm.customize ['modifyvm', :id, '--name', 'cache']
    cache_config.vm.host_name = 'cache'
    cache_config.vm.provision :shell do |shell|
      shell.inline = "apt-get update; apt-get install apt-cacher-ng -y; cp /vagrant/01apt-cacher-ng-proxy /etc/apt/apt.conf.d; apt-get update;sysctl -w net.ipv4.ip_forward=1;"#iptables –A FORWARD –i eth0 –o eth2 –j ACCEPT;iptables –A FORWARD –i eth2 –o eth0 –j ACCEPT;iptables –t nat –A POSTROUTING –o eth0 –j MASQUERADE"
    end
  end

  # Cobbler based "build" server
  config.vm.define :build do |build_config|
    build_config.vm.box = "precise64"
    build_config.vm.box_url = 'http://files.vagrantup.com/precise64.box'
    build_config.vm.customize ["modifyvm", :id, "--name", 'build-server']
    build_config.vm.host_name = 'build-server'
    build_config.vm.network :hostonly, "192.168.242.100"
    build_config.vm.network :hostonly, "10.2.3.100"
    build_config.vm.customize ["modifyvm", :id, "--nicpromisc3", "allow-all"]
    build_config.vm.network :hostonly, "10.3.3.100"

    # Configure apt mirror
    build_config.vm.provision :shell do |shell|
      shell.inline = "sed -i 's/us.archive.ubuntu.com/%s/g' /etc/apt/sources.list" % v_config['apt_mirror']
    end

    # Ensure DHCP isn't going to join us to a domain other than domain.name
    # since puppet has to sign its cert against the domain it makes when it runs.
    build_config.vm.provision :shell do |shell|
      shell.inline = "sed -i 's/\#supersede/supersede/g' /etc/dhcp/dhclient.conf; sed -i 's/fugue.com home.vix.com/%s/g' /etc/dhcp/dhclient.conf; sed -i 's/domain-name,//g' /etc/dhcp/dhclient.conf" % v_config['domain']
    end


    # configure apt and basic packages needed for install
    build_config.vm.provision :shell do |shell|
      shell.inline = "echo \"%s\" > /etc/apt/apt.conf.d/01apt-cacher-ng-proxy; apt-get update; dhclient -r eth0 && dhclient eth0; apt-get install -y git vim puppet curl; ln -s /vagrant/templates /etc/puppet/templates" % apt_cache_proxy
    end

    # pre-import the ubuntu image from an appropriate mirror
    build_config.vm.provision :shell do |shell|
      shell.inline = "apt-get install -y cobbler; cobbler-ubuntu-import -m http://%s/ubuntu precise-x86_64;" % v_config['apt_mirror']
    end

    # now run puppet to install the build server
    build_config.vm.provision(:puppet, :pp_path => "/etc/puppet") do |puppet|
      puppet.manifests_path = 'manifests'
      puppet.manifest_file  = "site.pp"
      puppet.module_path    = 'modules'
      puppet.options        = ['--verbose', '--trace', '--debug']
    end

    # Configure puppet
    build_config.vm.provision :shell do |shell|
      shell.inline = 'if [ ! -h /etc/puppet/modules ]; then rmdir /etc/puppet/modules;ln -s /etc/puppet/modules-0 /etc/puppet/modules; fi;puppet plugin download --server build-server.domain.name;service apache2 restart'
    end

    # enable ip forwarding and NAT so that the build server can act
    # as an external gateway for the quantum router.
    build_config.vm.provision :shell do |shell|
        shell.inline = "ip addr add 172.16.2.1/24 dev eth2; sysctl -w net.ipv4.ip_forward=1; iptables -A FORWARD -o eth0 -i eth1 -s 172.16.2.0/24 -m conntrack --ctstate NEW -j ACCEPT; iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT; iptables -t nat -F POSTROUTING; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE"
    end
  end

  # Openstack control server
  config.vm.define :control_pxe do |control_config|
    control_config.vm.customize(['modifyvm', :id ,'--nicbootprio2','1'])
    control_config.vm.box = 'blank'
    control_config.vm.boot_mode = 'gui'
    control_config.ssh.port = 2727
    control_config.vm.network :hostonly, "192.168.242.10", :mac => "001122334455"
    control_config.vm.network :hostonly, "10.2.3.10"
    control_config.vm.network :hostonly, "10.3.3.10"
  end

  config.vm.define :control_basevm do |control_config|
    node_name = "control-server-#{Time.now.strftime('%Y%m%d%m%s')}.domain.name"
    control_config.vm.box = "precise64"
    control_config.vm.box_url = 'http://files.vagrantup.com/precise64.box'
    control_config.vm.customize ["modifyvm", :id, "--name", 'control-server']
    control_config.vm.customize ["modifyvm", :id, "--memory", 1024]
    control_config.vm.host_name = node_name
    # you cannot boot this at the same time as the control_pxe b/c they have the same ip address
    control_config.vm.network :hostonly, "192.168.242.10"
    control_config.vm.network :hostonly, "10.2.3.10"
    control_config.vm.customize ["modifyvm", :id, "--nicpromisc3", "allow-all"]
    control_config.vm.network :hostonly, "10.3.3.10"

    # Use user-provided sources.list if available
    control_config.vm.provision :shell do |shell|
      shell.inline = 'if [ -f /vagrant/sources.list ]; then cp /vagrant/sources.list /etc/apt; fi;'
    end

    control_config.vm.provision :shell do |shell|
      shell.inline = 'echo "192.168.242.100 build-server build-server.domain.name" >> /etc/hosts;echo "%s" > /etc/apt/apt.conf.d/01apt-cacher-ng-proxy; apt-get update;apt-get install ubuntu-cloud-keyring' % apt_cache_proxy
    end

    control_config.vm.provision(:puppet_server) do |puppet|
      puppet.puppet_server = 'build-server.domain.name'
      puppet.options       = ['-t', '--pluginsync', '--trace', "--certname #{node_name}"]
    end
    # TODO install from puppet
  end

  # Openstack compute server
  config.vm.define :compute_pxe do |compute_config|
    compute_config.vm.customize(['modifyvm', :id ,'--nicbootprio2','1'])
    compute_config.vm.box = 'blank'
    compute_config.vm.boot_mode = 'gui'
    compute_config.ssh.port = 2728
    compute_config.vm.network :hostonly,  "192.168.242.21", :mac => "001122334466"
    compute_config.vm.network :hostonly, "10.2.3.21"
    compute_config.vm.network :hostonly, "10.3.3.21"
  end

  config.vm.define :compute_basevm do |compute_config|
    node_name = "compute-server02-#{Time.now.strftime('%Y%m%d%m%s')}.domain.name"
    compute_config.vm.box = "precise64"
    compute_config.vm.box_url = 'http://files.vagrantup.com/precise64.box'
    compute_config.vm.customize ["modifyvm", :id, "--name", 'compute-server02']
    compute_config.vm.host_name = node_name
    compute_config.vm.customize ["modifyvm", :id, "--memory", 2512]
    compute_config.vm.network :hostonly, "192.168.242.21"
    compute_config.vm.network :hostonly, "10.2.3.21"
    compute_config.vm.network :hostonly, "10.3.3.21"

    # Use user-provided sources.list if available
    compute_config.vm.provision :shell do |shell|
      shell.inline = 'if [ -f /vagrant/sources.list ]; then cp /vagrant/sources.list /etc/apt; fi;'
    end

    compute_config.vm.provision :shell do |shell|
      shell.inline = 'echo "192.168.242.100 build-server build-server.domain.name" >> /etc/hosts;echo "%s" > /etc/apt/apt.conf.d/01apt-cacher-ng-proxy; apt-get update;apt-get install ubuntu-cloud-keyring' % apt_cache_proxy
    end

    compute_config.vm.provision(:puppet_server) do |puppet|
      puppet.puppet_server = 'build-server.domain.name'
      puppet.options       = ['-t', '--pluginsync', '--trace', "--certname #{node_name}"]
    end
    # TODO install from puppet
  end

end
