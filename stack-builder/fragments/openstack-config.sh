#!/bin/bash

usermod --password p1fhTXKKhbc0M root

# Rstarmer's precise mirror
sed -i 's/archive.ubuntu.com/172.29.74.100/g' /etc/apt/sources.list

for i in 0 1 2 3
do
  ifconfig -a | grep eth$i
  if [ $? -eq 0 ];
    then
      ifconfig eth$i up
      dhclient eth$i -v
  fi
done


# Facter fqdn will come from DNS unless we do this
echo "127.0.1.1 $(hostname).domain.name $(hostname)" >> /etc/hosts

#mount config drive
mkdir -p /mnt/config
mount /dev/disk/by-label/config-2 /mnt/config

apt-get update
apt-get install -y puppet git rubygems curl python-yaml

git clone https://github.com/michaeltchapman/openstack-installer.git /root/openstack-installer
cd /root/openstack-installer
mkdir -p vendor
export GEM_HOME=`pwd`/vendor
gem install thor --no-ri --no-rdoc
git clone https://github.com/bodepd/librarian-puppet-simple.git vendor/librarian-puppet-simple
export PATH=`pwd`/vendor/librarian-puppet-simple/bin/:$PATH
export git_protocol='https'
librarian-puppet install --verbose --path /etc/puppet/modules

sed -i 's/192.168.242.100/%build_server_ip%/g' /root/openstack-installer/manifests/setup.pp

cp -r /root/openstack-installer/data /etc/puppet
cp -r /root/openstack-installer/manifests /etc/puppet

puppet apply manifests/setup.pp

until [ $(curl http://%build_server_ip%/status | grep up) ]; do
  echo "waited for build" >> /root/waiting
  sleep 1
done

puppet agent -t --server build-server.domain.name


