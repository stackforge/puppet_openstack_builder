#!/bin/bash
#
# This script is a quick and dirty implementation
# that is able to run integration tests for coi
# on jenkins
#
set -e
set -u

# pull in functions that test multi-node
source tests/multi_node.sh

ret=0
datestamp=`date "+%Y%m%d%H%M%S"`

# install librarian-puppet-simple
mkdir vendor
export GEM_HOME=`pwd`/vendor
gem install thor --no-ri --no-rdoc
git clone git://github.com/bodepd/librarian-puppet-simple vendor/librarian-puppet-simple
export PATH=`pwd`/vendor/librarian-puppet-simple/bin/:$PATH

# puppet_repos_to_use
if [ -n "${puppet_modules_to_use:-}" ]; then
  # this only supports upstream and downstream at the moment
  export repos_to_use=$puppet_modules_to_use
fi

# install modules
export module_install_method=librarian
if [ $module_install_method = 'librarian' ]; then
  librarian-puppet install --clean --verbose
else
  # eventually, this could do something like install packages
  echo 'librarian is the only supported install method'
  exit 1
fi

# check out a specific branch that we want to test
if [ -n "${module_repo:-}" ]; then
  if [ ! "${module_repo:-}" = 'openstack_dev_env' ]; then
    pushd $module_repo
  fi
  if [ -n "${checkout_branch_command:-}" ]; then
    eval $checkout_branch_command
  fi
  if [ ! "${module_repo:-}" = 'openstack_dev_env' ]; then
    popd
  fi
fi

# set up jenkins specific data overrides
if [ -n "${openstack_package_repo:-}" ]; then
  if [ $openstack_package_repo = 'cisco_repo' ]; then
    echo 'package_repo: cisco_repo' >> hiera_data/jenkins.yaml
    echo 'openstack_repo_location: http://openstack-repo.cisco.com/openstack/cisco' >> hiera_data/jenkins.yaml
    #echo 'openstack_repo_location: ftp://ftpeng.cisco.com/openstack/cisco' >> hiera_data/jenkins.yaml
    echo 'openstack_release: grizzly-proposed' >> hiera_data/jenkins.yaml
  elif [ $openstack_package_repo = 'cloud_archive' ]; then
    echo 'package_repo: cloud_archive' >> hiera_data/jenkins.yaml
    echo 'openstack_release: precise-updates/grizzly' >> hiera_data/jenkins.yaml
  else
    echo "Unsupported repo type: ${openstack_package_repo}"
  fi
fi

# clean up old vms from previous tests
destroy_multi_node_vms

# deploy the vms for a multi-node deployment
deploy_multi_node_vms

vagrant ssh build -c 'sudo /tmp/test_nova.sh;exit $?'
vagrant ssh build -c 'ping -c 2 172.16.2.129;exit $?'

if [ $? -eq 0 ]
  then
    echo "##########################"
    echo "      Test Passed!"
    echo "OVS ON CONTROL:" >> control.log.$datestamp
    vagrant ssh control_basevm -c 'sudo ovs-vsctl show;exit $?' >> control.log.$datestamp
    echo "OVS ON COMPUTE:" >> compute.log.$datestamp
    vagrant ssh compute_basevm -c 'sudo ovs-vsctl show;exit $?' >> compute.log.$datestamp
    mv build.log.$datestamp build.log.$datestamp.success
    mv control.log.$datestamp control.log.$datestamp.success
    mv compute.log.$datestamp compute.log.$datestamp.success
    ret=0
else
    echo "##########################"
    echo "Ping failed to reach VM :("
    echo "OVS ON CONTROL:" >> control.log.$datestamp
    vagrant ssh control_basevm -c 'sudo ovs-vsctl show;exit $?' >> control.log.$datestamp
    echo "OVS ON COMPUTE:" >> compute.log.$datestamp
    vagrant ssh compute_basevm -c 'sudo ovs-vsctl show' >> compute.log.$datestamp
    vagrant ssh control_basevm -c 'sudo service quantum-plugin-openvswitch-agent restart'
    sleep 2
    echo "OVS ON CONTROL AFTER AGENT RESTART:" >> control.log.$datestamp
    vagrant ssh control_basevm -c 'sudo ovs-vsctl show;exit $?' >> control.log.$datestamp
    mv build.log.$datestamp build.log.$datestamp.failed
    mv control.log.$datestamp control.log.$datestamp.failed
    mv compute.log.$datestamp compute.log.$datestamp.failed
    ret=1
fi
exit $ret
