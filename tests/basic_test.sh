#!/bin/bash
#
# This script is a quick and dirty implementation
# that is able to run integration tests for coi
# on jenkins
#
set -e
set -u

ret=0
datestamp=`date "+%Y%m%d%H%M%S"`

# install librarian-puppet-simple
mkdir -p vendor
export GEM_HOME=`pwd`/vendor
gem install thor --no-ri --no-rdoc
if [ -d vendor/librarian-puppet-simple ]; then
  cd vendor/librarian-puppet-simple
  git pull
  cd ../..
else
  git clone "${git_protocol:-git}"://github.com/bodepd/librarian-puppet-simple vendor/librarian-puppet-simple
fi
export PATH=`pwd`/vendor/librarian-puppet-simple/bin/:$PATH

# puppet_repos_to_use
if [ -n "${puppet_modules_to_use:-}" ]; then
  # this only supports upstream and downstream at the moment
  export repos_to_use=$puppet_modules_to_use
fi

if [ -n "${openstack_version}" ]; then
  export  openstack_version=$openstack_version
fi

# install modules
export module_install_method=librarian
if [ $module_install_method = 'librarian' ]; then
  #librarian-puppet install --clean --verbose
  librarian-puppet install --verbose
else
  # eventually, this could do something like install packages
  echo 'librarian is the only supported install method'
  exit 1
fi

# check out a specific branch that we want to test
if [ -n "${project_name:-}" ]; then
  if [ ! "${project_name:-}" = 'puppet_openstack_builder' ]; then
    pushd "modules/$project_name"
  fi
  if [ -n "${checkout_branch_command:-}" ]; then
    eval "${checkout_branch_command}"
  fi
  if [ ! "${project_name:-}" = 'puppet_openstack_builder' ]; then
    popd
  fi
fi

case $operatingsystem in
    redhat|ubuntu)
        sed -i -e "s/operatingsystem:.*/operatingsystem: ${operatingsystem}/" data/config.yaml
        ;;
    *)
        echo "Unsupported operatingsystem ${operatingsystem}"
        exit 1
        ;;
esac

# set up jenkins specific data overrides
if [ -n "${openstack_package_repo:-}" ]; then
  if [ $openstack_package_repo = 'cisco_repo' ]; then
    echo 'coe::base::package_repo: cisco_repo' >> data/hiera_data/jenkins.yaml
    echo 'coe::base::openstack_repo_location: http://openstack-repo.cisco.com/openstack/cisco' >> data/hiera_data/jenkins.yaml
    #echo 'openstack_repo_location: ftp://ftpeng.cisco.com/openstack/cisco' >> hiera_data/jenkins.yaml
    echo 'openstack_release: grizzly-proposed' >> data/hiera_data/jenkins.yaml
  elif [ $openstack_package_repo = 'cloud_archive' ]; then
    echo 'coe::base::package_repo: cloud_archive' >> data/hiera_data/jenkins.yaml
    echo "coe::base::openstack_release: ${openstack_version}" >> data/hiera_data/jenkins.yaml
    echo "coe::base::ubuntu_repo: ${uca_repo:-updates}" >> data/hiera_data/jenkins.yaml
  else
    echo "Unsupported repo type: ${openstack_package_repo}"
  fi
fi

if [ $openstack_version = 'havana' ];then
  echo 'network_service: neutron' >> data/global_hiera_params/jenkins.yaml
elif [ $openstack_version = 'grizzly' ]; then
  echo 'network_service: quantum' >> data/global_hiera_params/jenkins.yaml
fi

if [ "${test_type:-}" = 'swift' ]; then

  source tests/swift.sh

  sed -i 's/scenario:.*/scenario: swift/g' data/config.yaml
  destroy_swift
  deploy_swift_multi

  if [ "${test_mode}" = 'basic_tests' ]; then
    vagrant ssh swift_proxy -c 'ruby /tmp/swift_test_file.rb;exit $?'
  elif [ "${test_mode}" = 'none' ]; then
    echo 'building an environment without running tests'
  else
    echo "Unsupported swift test type ${test_mode}"
  fi

elif [ "${test_type:-}" = 'openstack_multi' ]; then

  if [[ "${test_mode}" == tempest* ]]; then
    # pull in functions to install controller with tempest
    sed -i 's/scenario:.*/scenario: multi_node_tempest/g' data/config.yaml
    source tests/multi_node_tempest.sh
  else
    sed -i 's/scenario:.*/scenario: 2_role/g' data/config.yaml
    # pull in functions that test multi-node
    source tests/2_role.sh
  fi

  # perform a multi-node openstack installation test by default
  # clean up old vms from previous tests
  destroy_multi_node_vms

  # deploy the vms for a multi-node deployment
  deploy_multi_node_vms

  if [ "${test_mode}" = 'basic_tests' ]; then
    vagrant ssh build -c 'sudo /tmp/test_nova.sh;exit $?'
    vagrant ssh build -c 'ping -c 2 172.16.2.129;exit $?'
  elif [[ "${test_mode}" == tempest* ]]; then
    if [ "${test_mode}" = 'tempest_smoke' ]; then
     tempest_args='--smoke'
    else
     tempest_args=''
    fi
    vagrant ssh control_tempest_basevm -c "sudo bash -c 'pushd /var/lib/tempest;pip install virtualenv;virtualenv test_env --system-site-packages;source test_env/bin/activate; pip install -I anyjson nose httplib2 pika unittest2 lxml testtools testresources paramiko boto netaddr keyring testrepository sqlalchemy;pip install -I d2to1==0.2.10;pip install -I 'pbr>0.5';/var/lib/tempest/run_tests.sh -N -- --exclude=object_storage ${tempest_args}';exit $?"
    popd
  elif [ "${test_mode}" = 'none' ]; then
    echo 'building an environment without running tests'
  else
    echo "Unsupported multi_node test type ${test_mode}"
  fi

else
  echo "Unsupported test_type ${test_type}"
  exit 1
fi

exit $ret
