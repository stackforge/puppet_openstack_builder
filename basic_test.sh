#!/bin/bash
ret=0
datestamp=`date "+%Y%m%d%H%M%S"`
vagrant destroy build -f
vagrant destroy control_basevm -f
vagrant destroy compute_basevm -f
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
    ret=1
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
    ret=0
fi
exit $ret
