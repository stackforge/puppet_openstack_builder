#!/bin/bash
#
# assumes that openstack credentails are set in this file
source /root/openrc

# Grab an image.  Cirros is a nice small Linux that's easy to deploy
wget --quiet http://download.cirros-cloud.net/0.3.2/cirros-0.3.2-x86_64-disk.img

# Add it to glance so that we can use it in Openstack
glance add name='cirros' is_public=true container_format=bare disk_format=qcow2 < cirros-0.3.2-x86_64-disk.img

# Capture the Image ID so that we can call the right UUID for this image
IMAGE_ID=`glance index | grep 'cirros' | head -1 |  awk -F' ' '{print $1}'`

# Flat provider network.
neutron net-create --provider:physical_network=default --shared --provider:network_type=flat public
neutron subnet-create --name publicsub --allocation-pool start=10.2.3.100,end=10.2.3.200 --router:external=True public 10.2.3.0/24

neutron_net=`neutron net-list | grep net1 | awk -F' ' '{print $2}'`

# For access to the instance
nova keypair-add test > /tmp/test.private
chmod 0600 /tmp/test.private

# Allow ping and ssh
neutron security-group-rule-create --protocol icmp --direction ingress default
neutron security-group-rule-create --protocol tcp --port-range-min 22 --port-range-max 22 --direction ingress default

# Boot instance
nova boot --flavor 1 --image cirros --key-name test --nic net-id=$neutron_net providervm

sleep 15

address=$(nova show providervm | grep public | cut -d '|' -f '3')

ip netns exec qdhcp-$neutron_net ssh -i /tmp/test.private $address -lcirros -o StrictHostKeyChecking=no hostname
