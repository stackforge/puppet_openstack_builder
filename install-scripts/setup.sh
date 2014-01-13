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

# Vendors can optionally include customisations
# leaving this blank will use the community packages
# and stackforge repositories
export vendor_name="${vendor:-}"

if [ -n "${vendor_name}" ]; then
  source ./$vendor_name.install.sh
fi

apt-get update
apt-get install -y git rubygems puppet

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

