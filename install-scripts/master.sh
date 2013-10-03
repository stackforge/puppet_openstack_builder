#!/bin/bash
#
# this script converts the node
# it runs on into a puppetmaster/build-server
# It assumes that setup.sh has already been run.
#
cp -Rv /root/openstack-installer/modules /etc/puppet/
cp -Rv /root/openstack-installer/data /etc/puppet/
cp -Rv /root/openstack-installer/manifests /etc/puppet/

puppet apply /etc/puppet/manifests/site.pp --certname build-server --debug
