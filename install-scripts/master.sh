#!/bin/bash
#
# this script converts the node
# it runs on into a puppetmaster/build-server
#

export build_server_ip="${build_server_ip:-127.0.0.1}"
export puppet_run_mode="apply"
export domain_name=`hostname -d`

# scenarios will map to /etc/puppet/data/scenarios/*.yaml
export scenario="${scenario:-2_role}"
# if you change your build_server name, or if you want 
# to run all_in_one, you will likely want to set this
export build_server="${build_server:-build-server}"

if [ "${scenario}" != "2_role" ] ; then
 sed -e "s/2_role/$scenario/" -i /root/openstack-installer/data/config.yaml
fi
if [ "${scenario}" == "all_in_one" ] ; then
  echo `hostname`: all_in_one >> /root/openstack-installer/data/role_mappings.yaml
  export FACTER_build_server_ip=`ip addr show eth0 | grep "inet " | tr "/" " " | awk -F' ' '{print $2}'`
  export FACTER_build_server=${build_server}
  cat > /root/openstack-installer/data/hiera_data/user.all_in_one.yaml<<EOF
domain_name: "${domain_name}"
ntp_servers:
  - ntp.esl.cisco.com

# node addresses
build_node_name: ${build_server}
controller_internal_address: "${build_server_ip}"
controller_public_address: "${build_server_ip}"
controller_admin_address: "${build_server_ip}"
swift_internal_address: "${build_server_ip}"
swift_public_address: "${build_server_ip}"
swift_admin_address: "${build_server_ip}"

# this is not done yet
internal_ip: "%{ipaddress}"
# interfaces
# TODO are all of these even used?
external_interface: eth1
public_interface: eth0
private_interface: eth0

internal_ip: "%{ipaddress}"
nova::compute::vncserver_proxyclient_address: "%{ipaddress}"
swift_local_net_ip: "%{ipaddress}"
nova::compute::vncserver_proxyclient_address: "0.0.0.0"
EOF
fi

export openstack_version="${openstack_scenario:-havana}"

bash <(curl -fsS https://raw.github.com/CiscoSystems/openstack-installer/master/install-scripts/setup.sh)

cp -R /root/openstack-installer/modules /etc/puppet/
cp -R /root/openstack-installer/data /etc/puppet/
cp -R /root/openstack-installer/manifests /etc/puppet/


puppet apply /etc/puppet/manifests/site.pp --certname ${build_server} --debug
puppet plugin download --server `hostname -f`; service apache2 restart
