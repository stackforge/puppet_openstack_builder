node build-server {

  Exec { logoutput => on_failure }

  $role = 'openstack'

  include coi::roles::build_server
  include openstack::client
  include openstack::auth_file
  include openstack::test_file

}

node /control-tempest-server/ {

  $role           = 'openstack'
  $openstack_role = 'controller'
  include coi::roles::controller::tempest

}

node openstack-base {

  
}

node /swift-proxy\d+/ {

  $role           = 'openstack'
  $openstack_role = 'swift_proxy'
  include coi::roles::swift_proxy

}

node /swift-storage\d+/ {

  $role           = 'openstack'
  $openstack_role = 'swift_storage'
  include coi::roles::swift_storage

}

# cache node that we use for testing so that we do not have to always reinstall
# packaged for every test
# TODO - we are not sure what to do with this role. it is useful be able to boot up from scratch.
# 
#
# TODO: check hiera's enable_cache here
node /cache/ {

  include coi::roles::cache

}

node default {

  notice($db_type)

}
