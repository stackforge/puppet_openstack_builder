#!/bin/bash
#
# this script converts the node
# it runs on into a puppetmaster/build-server
#
set -u
set -x
set -e
set -e

# Install type to use to get the puppet modules
# Options: git(default) or deb
export install_type= "${install_type:-git}"

# Vendors can optionally include customisations
# leaving this blank will use the community packages
# and stackforge repositories
export vendor_name="${vendor:-}"

# Master node or client (i.e., install puppet master or not)
# defaults to true
export master="${master:-true}"

if [ -n "${vendor_name}" ]; then
  source ./$vendor_name.install.sh
fi

apt-get update
apt-get install -y git apt rubygems puppet

# use the domain name if one exists
if [ "`hostname -d`" != '' ]; then
  domain=`hostname -d`
else
  # otherwise use the domain
  domain='domain.name'
fi
# puppet's fqdn fact explodes if the domain is not setup
if grep 127.0.1.1 /etc/hosts ; then
  sed -i -e "s/127.0.1.1.*/127.0.1.1 $(hostname).$domain $(hostname)/" /etc/hosts
else
  echo "127.0.1.1 $(hostname).$domain $(hostname)" >> /etc/hosts
fi;

export vendor_repo="${vendor_repo:-stackforge}"
export vendor_branch="${vendor_branch:-master}"

# Install puppet_openstack_builder
cd /root/
if ! [ -d puppet_openstack_builder ]; then
  git clone -b $vendor_branch https://github.com/$vendor_repo/puppet_openstack_builder.git /root/puppet_openstack_builder
fi


if ${master}; then
  # All in one defaults to the local host name for pupet master
  export build_server="${build_server:-`hostname`}"
  # We need to know the IP address as well, so either tell me
  # or I will assume it's the address associated with eth0
  export default_interface="${default_interface:-eth0}"
  # So let's grab that address
  export build_server_ip="${build_server_ip:-`ip addr show ${default_interface} | grep 'inet ' | tr '/' ' ' | awk -F' ' '{print $2}'`}"
  # Our default mode also assumes at least one other interface for OpenStack network
  export external_interface="${external_interface:-eth1}"

  # For good puppet hygene, we'll want NTP setup.  Let's borrow one from Cisco
  export ntp_server="${ntp_server:-ntp.esl.cisco.com}"

  # Since this is the master script, we'll run in apply mode
  export puppet_run_mode="apply"

  # scenarios will map to /etc/puppet/data/scenarios/*.yaml
  export scenario="${scenario:-all_in_one}"

  sed -e "s/scenario: .*/scenario: ${scenario}/" -i /root/puppet_openstack_builder/data/config.yaml

  if [ "${scenario}" == "all_in_one" ] ; then
    echo `hostname`: all_in_one >> /root/puppet_openstack_builder/data/role_mappings.yaml
    cat > /root/puppet_openstack_builder/data/hiera_data/user.yaml<<EOF
domain_name: "${domain}"
ntp_servers:
  - ${ntp_server}

# node addresses
build_node_name: ${build_server}
controller_internal_address: "${build_server_ip}"
controller_public_address: "${build_server_ip}"
controller_admin_address: "${build_server_ip}"
swift_internal_address: "${build_server_ip}"
swift_public_address: "${build_server_ip}"
swift_admin_address: "${build_server_ip}"

# physical interface definitions
external_interface: ${external_interface}
public_interface: ${default_interface}
private_interface: ${default_interface}

internal_ip: "%{ipaddress}"
swift_local_net_ip: "%{ipaddress}"
nova::compute::vncserver_proxyclient_address: "0.0.0.0"

quantum::agents::ovs::local_ip: "%{ipaddress}"
neutron::agents::ovs::local_ip: "%{ipaddress}"
EOF
  fi
  cd puppet_openstack_builder

  if [ "${install_type}" == "deb" ] ; then
    # install puppet module packages
    apt-get update
    awk '{ printf "puppet-%s ", $0 }' modules.list  | xargs apt-get install
  else
    # using librarian puppet to fetch git modules based on Puppetfile
    gem install librarian-puppet-simple --no-ri --no-rdoc
    export git_protocol='https'
    librarian-puppet install --verbose

    cp -R /root/puppet_openstack_builder/modules /etc/puppet/
  fi

  cp -R /root/puppet_openstack_builder/data /etc/puppet/
  cp -R /root/puppet_openstack_builder/manifests /etc/puppet/
  cp -R /root/puppet_openstack_builder/templates /etc/puppet/

  export FACTER_build_server=${build_server}

fi

export FACTER_build_server_domain_name=${domain}
export FACTER_build_server_ip=${build_server_ip}
export FACTER_puppet_run_mode="${puppet_run_mode:-agent}"

puppet apply -v -d /etc/puppet/manifests/setup.pp --modulepath /etc/puppet/modules --templatedir /etc/puppet/templates --certname `hostname -f`

if  $master ; then
  puppet apply /etc/puppet/manifests/site.pp --certname ${build_server} --debug
  puppet plugin download --server `hostname -f`; service apache2 restart
fi
