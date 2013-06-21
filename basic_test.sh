#!/bin/bash
ret=0
datestamp=`date "+%Y%m%d%H%M%S"`

# install librarian-puppet-simple
mkdir vendor
export GEM_HOME=`pwd`/vendor
gem install thor --no-ri --no-rdoc
git clone git://github.com/bodepd/librarian-puppet-simple vendor/librarian-puppet-simple
export PATH=`pwd`/vendor/librarian-puppet-simple/bin/:$PATH

# install modules
export module_install_method=librarian
if [ $module_install_method = 'librarian' ]; then
  librarian-puppet install --clean --verbose
else
  echo 'librarian is the only supported install method'
  exit 1
fi

# we need to kill any existing machines on the same
# system that conflict with the ones we want to spin up
for i in build-server control_basevm compute_basevm ; do
  if VBoxManage list vms | grep $i; then
    VBoxManage controlvm $i poweroff || true
    # occassionally, the VM is not really powered off when the above
    # command executed, and I wound up with the error:
    #  Cannot unregister the machine 'build-server' while it is locked 
    sleep 1
    VBoxManage unregistervm $i --delete
  fi
done

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

# build a cache vm if one does not already exist
if ! VBoxManage list vms | grep cache ; then
  vagrant up cache 2>&1 | tee -a cache.log.$datestamp
fi

vagrant up build 2>&1 | tee -a build.log.$datestamp  
vagrant up control_basevm 2>&1 | tee -a control.log.$datestamp
vagrant up compute_basevm 2>&1 | tee -a compute.log.$datestamp
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
