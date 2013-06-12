#!/bin/bash
ret=0
datestamp=`date "+%Y%m%d%H%M%S"`
vagrant destroy -f
vagrant up build 2>&1 | tee -a build.log.$datestamp  
vagrant up control_basevm 2>&1 | tee -a control.log.$datestamp
vagrant up compute_basevm 2>&1 | tee -a compute.log.$datestamp
PORT=`vagrant ssh-config build | grep Port | grep -o '[0-9]\+'`
ssh -q \
    -o UserKnownHostsFile=/dev/null \
    -o StrictHostKeyChecking=no \
    -i ~/.vagrant.d/insecure_private_key \
    vagrant@localhost \
    -p $PORT \
    'sudo apt-get install -y -q python-novaclient python-glanceclient python-quantumclient python-keystoneclient'
ssh -q \
    -o UserKnownHostsFile=/dev/null \
    -o StrictHostKeyChecking=no \
    -i ~/.vagrant.d/insecure_private_key \
    vagrant@localhost \
    -p $PORT \
    'sudo /tmp/test_nova.sh'

ssh -q \
    -o UserKnownHostsFile=/dev/null \
    -o StrictHostKeyChecking=no \
    -i ~/.vagrant.d/insecure_private_key \
    vagrant@localhost \
    -p $PORT \
    'ping -c 2 172.16.2.129'

if [ $? -eq 0 ]
  then 
    echo "##########################"
    echo "      Test Passed!"
    echo "OVS ON CONTROL:" >> control.log.$datestamp
    vagrant ssh control_basevm -c 'sudo ovs-vsctl show' >> control.log.$datestamp
    echo "OVS ON COMPUTE:" >> compute.log.$datestamp
    vagrant ssh compute_basevm -c 'sudo ovs-vsctl show' >> compute.log.$datestamp
    mv build.log.$datestamp build.log.$datestamp.success
    mv control.log.$datestamp control.log.$datestamp.success
    mv compute.log.$datestamp compute.log.$datestamp.success
    ret=1
else
    echo "##########################"
    echo "Ping failed to reach VM :("
    echo "OVS ON CONTROL:" >> control.log.$datestamp
    vagrant ssh control_basevm -c 'sudo ovs-vsctl show' >> control.log.$datestamp
    echo "OVS ON COMPUTE:" >> compute.log.$datestamp
    vagrant ssh compute_basevm -c 'sudo ovs-vsctl show' >> compute.log.$datestamp
    vagrant ssh control_basevm -c 'sudo service quantum-plugin-openvswitch-agent restart'
    sleep 2
    echo "OVS ON CONTROL AFTER AGENT RESTART:" >> control.log.$datestamp
    vagrant ssh control_basevm -c 'sudo vs-vsctl show' >> control.log.$datestamp
    mv build.log.$datestamp build.log.$datestamp.failed
    mv control.log.$datestamp control.log.$datestamp.failed
    mv compute.log.$datestamp compute.log.$datestamp.failed
    ret=0
fi
exit $ret
