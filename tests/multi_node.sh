#!/bin/bash
#
# specifies things that are specific to the
# vagrant multi-node deployment scenario
#

function destroy_multi_node_vms() {
  # we need to kill any existing machines on the same
  # system that conflict with the ones we want to spin up
  for i in build-server  compute-server02 control-server control-tempest-server ; do
    if VBoxManage list vms | grep $i; then
      VBoxManage controlvm    $i poweroff || true
      # this sleep statement is to fix an issue where
      # machines are still in a locked state after the
      # controlvm poweroff command should be completed
      sleep 1
      VBoxManage unregistervm $i --delete
    fi
  done
}

function deploy_multi_node_vms() {
  # build a cache vm if one does not already exist
  if ! VBoxManage list vms | grep cache ; then
    vagrant up cache 2>&1 | tee -a cache.log.$datestamp
  fi

  vagrant up build 2>&1 | tee -a build.log.$datestamp
  vagrant up control_basevm 2>&1 | tee -a control.log.$datestamp
  vagrant up compute_basevm 2>&1 | tee -a compute.log.$datestamp
}
