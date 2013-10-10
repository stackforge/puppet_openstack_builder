#!/bin/bash
#
# this script converts the node
# it runs on into a puppetmaster/build-server
#

export build_server_ip="${build_server_ip:-127.0.0.1}"
export puppet_run_mode="apply"

bash <(curl -fsS https://raw.github.com/CiscoSystems/openstack-installer/master/install-scripts/setup.sh)

cp -Rv /root/openstack-installer/modules /etc/puppet/
cp -Rv /root/openstack-installer/data /etc/puppet/
cp -Rv /root/openstack-installer/manifests /etc/puppet/

puppet apply /etc/puppet/manifests/site.pp --certname build-server --debug
puppet plugin download --server `hostname -f`; service apache2 restart
