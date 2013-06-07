#!/bin/bash
datestamp=`date "+%Y%m%d%H%M%S"`
vagrant destroy -f
vagrant up build 2>&1 | tee -a build.log
vagrant up control_basevm 2>&1 | tee -a control.log
vagrant up compute_basevm 2>&1 | tee -a compute.log
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
    mv build.log build.log.$datestamp.success
    mv control.log control.log.$datestamp.success
    mv compute.log compute.log.$datestamp.success
else
    echo "##########################"
    echo "Ping failed to reach VM :("
    mv build.log build.log.$datestamp.failed
    mv control.log control.log.$datestamp.failed
    mv compute.log compute.log.$datestamp.failed
fi
