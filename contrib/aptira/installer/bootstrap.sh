#!/usr/bin/env bash

# Parameters can be set via env vars or passed as
# arguments. Arguments take priority over
# env vars.

proxy="${proxy:-}"
desired_ruby="${desired_ruby:-2.0.0p353}"
desired_puppet="${desired_puppet:-3.4.3}"
network="${network:-eth1}"
dest="${destination:-$HOME}"
environment="${environment:-}"
role="${role:-}"
tarball_source="${tarball_source:-https://bitbucket.org/michaeltchapman/puppet_openstack_builder/downloads/stacktira.tar}"

while getopts "h?p:r:o:t:u:n:e:d:" opt; do
    case "$opt" in
    h|\?)
        echo "Not helpful help message"
        exit 0
        ;;
    p)  proxy=$OPTARG
        ;;
    r)  desired_ruby=$OPTARG
        ;;
    o)  role=$OPTARG
        ;;
    t)  tarball_source=$OPTARG
        ;;
    u)  desired_puppet=$OPTARG
        ;;
    n)  network=$OPTARG
        ;;
    e)  environment=$OPTARG
        ;;
    d)  destination=$OPTARG
        ;;
    esac
done

# Set wgetrc and either yum or apt to use an http proxy.
if [ $proxy ] ; then
    echo 'setting proxy'
    export http_proxy=$proxy

    if [ -f /etc/redhat-release ] ; then
        if [ ! $(cat /etc/yum.conf | grep '^proxy=') ] ; then
            echo "proxy=$proxy" >> /etc/yum.conf
        fi
    elif [ -f /etc/debian_version ] ; then
        if [ ! -f /etc/apt/apt.conf.d/01apt-cacher-ng-proxy ] ; then
            echo "Acquire::http { Proxy \"$proxy\"; };" > /etc/apt/apt.conf.d/01apt-cacher-ng-proxy;
            apt-get update -q
        fi
    else
        echo "OS not detected! Weirdness inbound!"
    fi

    if [ ! $(cat /etc/wgetrc | grep '^http_proxy =') ] ; then
        echo "http_proxy = $proxy" >> /etc/wgetrc
    fi
else
    echo 'not setting proxy'
fi

cd $dest

# Download the data model tarball
if [ ! -d $dest/stacktira ] ; then
    echo 'downloading data model'
    wget $tarball_source
    tar -xvf stacktira.tar
    rm -rf stacktira.tar
else
    echo "data model installed in $dest/stacktira"
fi

# Ensure both puppet and ruby are
# installed, the correct version, and ready to run.
#
# It will install from $dest/stacktira/aptira/packages
# if possible, otherwise it will wget from the
# internet. If this machine is unable to run yum
# or apt install, and unable to wget, this script
# will fail.

ruby_version=$(ruby --version | cut -d ' ' -f 2)
# Ruby 1.8.7 (standard on rhel 6) can give segfaults, so
# purge and install ruby 2.0.0
if [ "${ruby_version}" != "${desired_ruby}" ] ; then
    echo "installing ruby version $desired_ruby"
    if [ -f /etc/redhat-release ] ; then
        # Purge current ruby
        yum remove ruby puppet ruby-augeas ruby-shadow -y -q

        # enable epel to get libyaml, which is required by ruby
        wget http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
        rpm -Uvh epel-release-6*
        yum install -y libyaml -q
        rm epel-release-6*

        # Install ruby 2.0.0
        if [ -f $dest/stacktira/contrib/aptira/packages/ruby-2.0.0p353-1.el6.x86_64.rpm ] ; then
            yum localinstall -y $dest/stacktira/contrib/aptira/packages/ruby-2.0.0p353-1.el6.x86_64.rpm
        else
            echo 'downloading ruby 2.0.0 rpm'
            # wget_rpm_from_somewhere
            yum localinstall ruby-2.0.0p353-1.el6.x86_64.rpm -y -q
        fi

        yum install augeas-devel -y -q

    elif [ -f /etc/debian_version ] ; then
        apt-get remove puppet ruby -y
        apt-get install ruby -y
    fi
else
    echo "ruby version $desired_ruby already installed"
fi

# Install puppet from gem. This is not best practice, but avoids
# repackaging large numbers of rpms and debs for ruby 2.0.0
hash puppet 2>/dev/null || {
  puppet_version=0
}

if [ "${puppet_version}" != '0' ] ; then
    puppet_version=$(puppet --version)
fi

if [ "${puppet_version}" != "${desired_puppet}" ] ; then
    echo "installing puppet version $desired_puppet"
    if [ -f $dest/stacktira/contrib/aptira/gemcache/puppet-$desired_puppet.gem ] ; then
        echo "installing from local gem cache"
        cd $dest/stacktira/contrib/aptira/gemcache
        gem install --force --local *.gem
        cd -
    else
        echo "no local gem cache found, installing puppet gem from internet"
        gem install puppet ruby-augeas --no-ri --no-rdoc
    fi
else
    echo "puppet version $desired_puppet already installed"
fi

# Ensure puppet user and group are configured
if ! grep puppet /etc/group; then
    echo 'adding puppet group'
    groupadd puppet
fi
if ! grep puppet /etc/passwd; then
    echo 'adding puppet user'
    useradd puppet -g puppet -d /var/lib/puppet -s /sbin/nologin
fi

# Set up minimal puppet directory structure
if [ ! -d /etc/puppet ]; then
    echo 'creating /etc/puppet'
    mkdir /etc/puppet
fi

if [ ! -d /etc/puppet/manifests ]; then
    echo 'creating /etc/puppet/manifests'
    mkdir /etc/puppet/manifests
fi

if [ ! -d /etc/puppet/modules ]; then
    echo 'creating /etc/puppet/modules'
    mkdir /etc/puppet/modules
fi

# Don't overwrite the one vagrant places there
if [ ! -f /etc/puppet/manifests/site.pp ]; then
    echo 'copying site.pp'
    cp $dest/stacktira/contrib/aptira/puppet/site.pp /etc/puppet/manifests
fi

# Create links for all modules, but if a dir is already there,
# ignore it (for dev envs)
for i in $(cat $dest/stacktira/contrib/aptira/build/modules.list); do
    if [ ! -L /etc/puppet/modules/$i ] && [ ! -d /etc/puppet/modules/$i ] ; then
        echo "Installing module $i"
        ln -s $dest/stacktira/modules/$i /etc/puppet/modules/$i
    fi
done

echo 'all modules installed'

if [ ! -d /etc/puppet/data ]; then
    echo 'creating /etc/puppet/data'
    mkdir /etc/puppet/data
fi

if [ ! -d /etc/puppet/data/hiera_data ]; then
    echo 'linking /etc/puppet/data/hiera_data'
    ln -s $dest/stacktira/data/hiera_data /etc/puppet/data/hiera_data
fi

echo 'hiera data ready'

# copy hiera.yaml to etc, so that we can query without
# running puppet just yet
if [ ! -f /etc/hiera.yaml ] ; then
    echo 'setting /etc/hiera.yaml'
    cp $dest/stacktira/contrib/aptira/puppet/hiera.yaml /etc/hiera.yaml
fi

# copy hiera.yaml to puppet
if [ ! -f /etc/puppet/hiera.yaml ] ; then
    echo 'setting /etc/puppet/hiera.yaml'
    cp $dest/stacktira/contrib/aptira/puppet/hiera.yaml /etc/puppet/hiera.yaml
fi

# Copy site data if any. This will not be overwritten by sample configs
if [ -d $dest/stacktira/contrib/aptira/site ] ; then
    echo "Installing user config"
    cp -r $dest/stacktira/contrib/aptira/site/* /etc/puppet/data/hiera_data
fi

mkdir -p /etc/facter/facts.d
# set environment external fact
# Requires facter > 1.7
if [ -n $environment ] ; then
    if [ ! -f /etc/facter/facts.d/environment.yaml ] ; then
        echo "environment: $environment" > /etc/facter/facts.d/environment.yaml
    elif ! grep -q "environment" /etc/facter/facts.d/environment.yaml ; then
        echo "environment: $environment" >> /etc/facter/facts.d/environment.yaml
    fi
    if [ ! -d $dest/stacktira/contrib/aptira/site ] ; then
        if [ ! -f /etc/puppet/data/hiera_data/user.$environment.yaml ] ; then
            if [ -f $dest/stacktira/contrib/aptira/puppet/user.$environment.yaml ] ; then
                cp $dest/stacktira/contrib/aptira/puppet/user.$environment.yaml /etc/puppet/data/hiera_data/user.$environment.yaml
            fi
        fi
    fi
fi

# set role external fact
# Requires facter > 1.7
if [ -n $role ] ; then
    if [ ! -f /etc/facter/facts.d/role.yaml ] ; then
        echo "role: $role" > /etc/facter/facts.d/role.yaml
    elif ! grep -q "role" /etc/facter/facts.d/role.yaml ; then
        echo "role: $role" >> /etc/facter/facts.d/role.yaml
    fi
fi

# Ensure puppet isn't going to sign a cert with the wrong time or
# name
ipaddress=$(facter ipaddress_$network)
fqdn=$(hostname).$(hiera domain_name)
# If it doesn't match what puppet will be setting for fqdn, just redo
# to the point where we can see the master and have fqdn
if ! grep -q "$ipaddress\s$fqdn" /etc/hosts ; then
    echo 'configuring /etc/hosts for fqdn'
    if [ -f /etc/redhat-release ] ; then
        echo "$ipaddress $fqdn $(hostname)" > /etc/hosts
        echo "127.0.0.1       localhost       localhost.localdomain localhost4 localhost4.localdomain4" >> /etc/hosts
        echo "::1     localhost       localhost.localdomain localhost6 localhost6.localdomain6" >> /etc/hosts
        echo "$(hiera build_server_ip) $(hiera build_server_name) $(hiera build_server_name).$(hiera domain_name)" >> /etc/hosts
    elif [ -f /etc/debian_version ] ; then
        echo "$ipaddress $fqdn $(hostname)" > /etc/hosts
        echo "127.0.0.1       localhost       localhost.localdomain localhost4 localhost4.localdomain4" >> /etc/hosts
        echo "::1     localhost       localhost.localdomain localhost6 localhost6.localdomain6" >> /etc/hosts
        echo "$(hiera build_server_ip) $(hiera build_server_name) $(hiera build_server_name).$(hiera domain_name)" >> /etc/hosts
    fi
fi

# install ntpdate if necessary
hash ntpdate 2>/dev/null || {
    echo 'installing ntpdate'
    if [ -f /etc/redhat-release ] ; then
        yum install -y ntpdate -q
    elif [ -f /etc/debian_version] ; then
        apt-get install ntpdate -y
    fi
}

# this may be a list, so just take the first one
ntpdate $(hiera ntp_servers | cut -d '"' -f 2)

if [ ! -d $dest/stacktira/contrib/aptira/site ] ; then
    if [ ! -f /etc/puppet/data/hiera_data/user.yaml ] ; then
        echo 'No user.yaml found: installing sample'
        cp $dest/stacktira/contrib/aptira/puppet/user.yaml /etc/puppet/data/hiera_data/user.yaml
    fi
fi

echo 'This server has been successfully prepared to run puppet using'
echo 'the Openstack data model. Please take a moment to review your'
echo 'configuration in /etc/puppet/data/hiera_data/user.yaml'
echo
echo "When you\'re ready, run puppet apply /etc/puppet/manifests/site.pp"
