node build-server {

  Exec { logoutput => on_failure }

  $role = 'openstack'

  include coi::roles::build_server::test

  # I want these nodes to eventuall be moved to
  # some data format that can just be parsed
  # right now, it does make sense to maintain them here
  coi::cobbler_node { "control-server":
    node_type      => "control",
    mac            => "00:11:22:33:44:55",
    ip             => "192.168.242.10",
    power_address  => "192.168.242.110",
    power_user     => "admin",
    power_password => "password",
    power_type     => "ipmitool"
  }

  coi::cobbler_node { "compute-server01":
    node_type     => "compute",
    mac           => "11:22:33:44:55:66",
    ip            => "192.168.242.21",
    power_address => "192.168.242.121"
  }
}

node /control-server/ {
  $role = 'openstack'
  $openstack_role = 'controller'
  include coi::roles::controller
}

node /compute-server\d+/ {
  $role           = 'openstack'
  $openstack_role = 'compute'
  include coi::roles::compute
}

# cache node that we use for testing so that we do not have to always reinstall
# packaged for every test
# TODO - we are not sure what to do with this role. it is useful be able to boot up from scratch.
# 
#
node /cache/ {
  include coi::roles::cache
}
