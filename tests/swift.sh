#!/bin/bash
#
# specifies things that are specific to the
# vagrant multi-node deployment scenario
#

function destroy_swift() {
  for i in build-server control-server swift-proxy01 swift-storage01 swift-storage02 swift-storage03 ; do
    if VBoxManage list vms | grep $i; then
      VBoxManage controlvm    $i poweroff || true
      # this sleep statement is to fix an issue where
      # machines are still in a locked state after the
      # controlvm poweroff command should be completed
      sleep 1
      VBoxManage unregistervm $i --delete
    fi
  done
  clean_swift_certs
}

function clean_swift_certs() {
  if VBoxManage list vms | grep build-server ; then
    vagrant ssh build -c 'sudo bash -c "export RUBYLIB=/etc/puppet/modules-0/ruby-puppetdb/lib/; puppet query node --only-active --deactivate --puppetdb_host=build-server.domain.name --puppetdb_port=8081 --config=/etc/puppet/puppet.conf --ssldir=/var/lib/puppet/ssl --certname=build-server.domain.name || true"'

    vagrant ssh build -c 'sudo bash -c "rm /var/lib/puppet/ssl/*/swift*;rm /var/lib/puppet/ssl/ca/signed/swift* || true"'
  fi
}

function deploy_swift_multi() {
  # build a cache vm if one does not already exist
  for i in cache build control_basevm; do
    if ! VBoxManage list vms | grep $i ; then
      vagrant up $i 2>&1 | tee -a $i.log.$datestamp
    fi
  done

  for i in swift_storage_1 swift_storage_2 swift_storage_3 ; do
    # this first pass does not succeed
    vagrant up $i 2>&1 | tee -a $i.log.$datestamp || true
  done

  vagrant up swift_proxy 2>&1 | tee -a swift_proxy.log.$datestamp

  for i in swift_storage_1 swift_storage_2 swift_storage_3 ; do
    vagrant provision $i 2>&1 | tee -a $i.log.$datestamp
  done

}
