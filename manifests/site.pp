node /control-tempest-server/ {

  $role           = 'openstack'
  $openstack_role = 'controller'
  include coi::roles::controller::tempest

}

node default {

  notice("Host: ${::clientcert} matched default group")

}
