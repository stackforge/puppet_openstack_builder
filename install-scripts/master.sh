#!/bin/bash
#
# this script converts the node
# it runs on into a puppetmaster/build-server
#

set -e

# All in one defaults to the local host name for pupet master
export build_server="${build_server:-`hostname`}"
# It'd be good to konw our domain name as well
export domain_name=`hostname -d`
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
  export FACTER_build_server_ip=${build_server_ip}
  export FACTER_build_server=${build_server}
  cat > /root/puppet_openstack_builder/data/hiera_data/user.yaml<<EOF
domain_name: "${domain_name}"
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

bash <(curl -fsS https://raw.github.com/stackforge/puppet_openstack_builder/master/install-scripts/setup.sh)

cp -R /root/puppet_openstack_builder/modules /etc/puppet/
cp -R /root/puppet_openstack_builder/data /etc/puppet/
cp -R /root/puppet_openstack_builder/manifests /etc/puppet/


puppet apply /etc/puppet/manifests/site.pp --certname ${build_server} --debug
puppet plugin download --server `hostname -f`; service apache2 restart
