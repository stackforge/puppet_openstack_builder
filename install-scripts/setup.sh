#!/bin/bash
#
# This script sets up the base config for all nodes
# It requires that you provide it with the ip address
# of your build server
# export build_server_ip=10.0.0.1
# bash setup.sh
#
set -u
set -x
set -e

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

# Install puppet_openstack_builder
cd /root/
if ! [ -d puppet_openstack_builder ]; then
  git clone https://github.com/stackforge/puppet_openstack_builder.git /root/puppet_openstack_builder
fi

cd puppet_openstack_builder
gem install librarian-puppet-simple --no-ri --no-rdoc
export git_protocol='https'
librarian-puppet install --verbose

export FACTER_build_server_domain_name=$domain
export FACTER_build_server_ip=$build_server_ip
export FACTER_puppet_run_mode="${puppet_run_mode:-agent}"

puppet apply manifests/setup.pp --modulepath modules --certname setup_cert
