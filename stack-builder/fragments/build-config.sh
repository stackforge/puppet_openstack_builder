#!/bin/bash
#Password is "test"
usermod --password p1fhTXKKhbc0M root

# Rstarmer's precise mirror
sed -i 's/archive.ubuntu.com/172.29.74.100/g' /etc/apt/sources.list

# Naively bring up whatever ethernet devices seem to be attached
for i in 1 2 3 4
do
  ifconfig -a | grep eth$i
  if [ $? -eq 0 ];
    then
      ifconfig eth$i up
      dhclient eth$i
  fi
done

# mount config drive to populate hiera
# overrides from metadata
mkdir -p /mnt/config
mount /dev/disk/by-label/config-2 /mnt/config

apt-get update
apt-get install -y puppet git rubygems python-yaml

# Facter fqdn will come from DNS unless we do this
echo "127.0.1.1 $(hostname).domain.name $(hostname)" >> /etc/hosts

# Install puppet librarian and all COI modules
git clone https://github.com/michaeltchapman/openstack-installer.git /root/openstack-installer
cd /root/openstack-installer
mkdir -p vendor
export GEM_HOME=`pwd`/vendor
gem install thor --no-ri --no-rdoc
git clone https://github.com/bodepd/librarian-puppet-simple.git vendor/librarian-puppet-simple
export PATH=`pwd`/vendor/librarian-puppet-simple/bin/:$PATH
export git_protocol='https'
librarian-puppet install --verbose --path /etc/puppet/modules

# TODO unhardcode this from setup. it's ugly.
sed -i "s/'192.168.242.100'/\"\$\{\:\:ipaddress_eth0\}\"/g" /root/openstack-installer/manifests/setup.pp

cp -r /root/openstack-installer/data /etc/puppet
cp -r /root/openstack-installer/manifests /etc/puppet

# Override hiera values that have been passed in
# through metadata
python /root/hiera_config.py

# Install the latest puppet and purge the old puppet
puppet apply manifests/setup.pp

# Install build server
puppet apply manifests/site.pp

puppet plugin download --server build-server.domain.name

# Notify other nodes that the puppet-master is ready
echo "up" > /var/www/status
