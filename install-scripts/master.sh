#!/bin/bash
#
# this script converts the node
# it runs on into a puppetmaster/build-server
#

export build_server_ip="${build_server_ip:-127.0.0.1}"
export puppet_run_mode="apply"

# scenarios will map to /etc/puppet/data/scenarios/*.yaml
export scenario="${scenario:-2_role}"
# if you change your build_server name, or if you want 
# to run all_in_one, you will likely want to set this
export build_server="${build_server:-build-server}"

export openstack_version="${openstack_scenario:-havana}"

bash <(curl -fsS https://raw.github.com/CiscoSystems/openstack-installer/master/install-scripts/setup.sh)

cp -R /root/openstack-installer/modules /etc/puppet/
cp -R /root/openstack-installer/data /etc/puppet/
cp -R /root/openstack-installer/manifests /etc/puppet/

if [ ${scenario} != "2_role" ] ; then
 sed -i "s/2_role/$scenario/" /etc/puppet/data/config.yaml
fi
if [ ${scenario} == "all_in_one" ] ; then
  echo `hostname`: all_in_one >> /etc/puppet/data/role_mappings.yaml
  export FACTER_build_server_ip=`ip addr show eth0 | grep "inet " | tr "/" " " | awk -F' ' '{print $2}'`
fi


puppet apply /etc/puppet/manifests/site.pp --certname ${build_server} --debug
puppet plugin download --server `hostname -f`; service apache2 restart
