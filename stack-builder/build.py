#!/usr/bin/env python
"""
    stack-builder.build
    ~~~~~~~~~~~~~~~~~~~
    
    This module is reponsible for creating VMs on the target cloud,
    and pushing the appropriate metadata and init scripts to them

"""
import debug
import subprocess
import os
import uuid
import quantumclient
import fragment
import yaml

from metadata import build_metadata
from debug import dprint

def build_server_deploy():
    with open ('./stack-builder/fragments/build-config.sh', 'r') as b:
        return b.read()

def build_server_hiera_config():
    with open('./stack-builder/hiera_config.py', 'r') as b:
        return b.read()

def stack_server_deploy(build_node_ip):
    with open ('./stack-builder/fragments/openstack-config.sh', 'r') as b:
      return b.read().replace('%build_server_ip%', build_node_ip)

def build_nic_net_list(networks):
    return [{'net-id': network['id'], 'port-id': '', 'v4-fixed-ip': ''} for network in networks]

def build_nic_port_list(ports):
    return [{'net-id': '', 'port-id': port, 'v4-fixed-ip': ''} for port in ports]
      
def make_network(q, ci_network_name, index=0):
    networks = q.list_networks()

    # the shared CI network 
    if ci_network_name != 'ci':
        ci_network_name = ci_network_name + str(index)

    if ci_network_name not in [network['name'] for network in networks['networks']]:
        dprint("q.create_network({'network': {'name':" + ci_network_name + ", 'admin_state_up': True}})['network']")
        test_net = q.create_network({'network': {'name': ci_network_name, 'admin_state_up': True}})['network']

    else:
       for net in networks['networks']:
          if net['name'] == ci_network_name:
              test_net = net
    return test_net

def make_subnet(q, ci_network_name, test_net, index=1, dhcp=True, gateway=False):
    subnets = q.list_subnets()

    # the shared CI network 
    if ci_network_name != 'ci':
        ci_network_name = ci_network_name + str(index)

    if ci_network_name not in [subnet['name'] for subnet in subnets['subnets']]:
        print "CI subnet " + str(index) + " doesn't exist. Creating ..."
        try:
            # internal networks
            if not gateway:
                dprint("create_subnet({'subnet': { 'name':" + ci_network_name + str(index) + ",\n" +
                       "            'network_id': " + test_net['id'] + ",\n" +
                       "            'ip_version': 4,\n" +
                       "            'cidr': '10.2." + str(index) + ".0/24',\n" +
                       "            'enable_dhcp': dhcp,\n" +
                       "            'gateway_ip': None}})['subnet']\n")

                test_subnet = q.create_subnet({'subnet': { 'name': ci_network_name + str(index), 
                                         'network_id': test_net['id'],
                                         'ip_version': 4,
                                         'cidr': '10.2.'+ str(index) + '.0/24',
                                         'enable_dhcp': dhcp,
                                     'gateway_ip': None
                                     }})['subnet']

            # the external network
            else:
                if ci_network_name == 'ci':
                    dprint("create_subnet({'subnet': { 'name':" + ci_network_name + ",\n" +
                           "            'network_id': " + test_net['id'] + ",\n" +
                           "            'ip_version': 4,\n" +
                           "            'cidr': '10." + str(index) + ".0.0/16',\n" +
                           "            'enable_dhcp':" + dhcp + ",\n" +
                           "            'gateway_ip': '10.'" + str(index) + ".0.1\n" +
                           "            'dns_nameservers': ['171.70.168.183']\n")

                    test_subnet = q.create_subnet({'subnet': { 'name': ci_network_name, 
                                         'network_id': test_net['id'],
                                         'ip_version': 4,
                                         'cidr': '10.' + str(index) + '.0.0/16',
                                         'enable_dhcp': dhcp,
                                         'gateway_ip' : '10.' + str(index) + '.0.1',
                                         'dns_nameservers': ['171.70.168.183']
	                                 }})['subnet']

        except quantumclient.common.exceptions.QuantumClientException:
            print "Couldn't create subnet!"
    else:
       for net in subnets['subnets']:
           if net['name'] == ci_network_name:
               test_subnet = net
    return test_subnet

def boot_puppetised_instance(n, name, image_name, nic_list, key='test2', os_flavor=u'm1.medium',deploy="",files=None, meta={}):
   images = n.images.list()
   for i,image in enumerate([image.name for image in images]):
     if image == image_name:
       boot_image = images[i]

   flavors = n.flavors.list()
   for i,flavor in enumerate([flavor.name for flavor in flavors]):
     if flavor == os_flavor:
       boot_flavor = flavors[i]

   print("Booting " + name)
   dprint("Boot image: " + str(boot_image))
   dprint("Boot flavor: " + str(boot_flavor))
   dprint("Boot nics: " + str(nic_list))
   dprint("Boot key: " + str(key))
   dprint("Boot deploy: " + str(deploy))
   dprint("Boot files: " + str(files))
   dprint("Boot meta: " + str(meta))

   return n.servers.create(name, image=boot_image, flavor=boot_flavor, userdata=deploy, files=files, key_name=key, nics=nic_list, meta=meta)

# Cisco internal network
def get_external_network(q):
    for network in q.list_networks()['networks']:
        if network['name'] == 'external':
            return network

# Used only for setting router gateway, VMs
# belong on external network
def get_public_network(q):
    for network in q.list_networks()['networks']:
        if network['name'] == 'public':
            return network

def get_external_router(q):
    for router in q.list_routers()['routers']:
        if router['name'] == 'ci':
            return router

def get_ci_network(q):
    for network in q.list_networks()['networks']:
        if network['name'] == 'ci':
            return network

def get_ci_subnet(q):
    for subnet in q.list_subnets()['subnets']:
        if subnet['name'] == 'ci':
            return subnet 

def set_external_routing(q, subnet):
    routers = q.list_routers()
    ci_router = [router for router in routers['routers'] if router['name'] == 'ci']
    if len(ci_router) == 0:
        ci_router = q.create_router( { 'router': { 'name': 'ci',
                                                   'admin_state_up': 'true'} })['router']
        q.add_gateway_router(ci_router['id'], {'network_id': get_public_network(q)['id']})    
        q.add_interface_router(ci_router['id'], {'subnet_id': subnet['id']})
    else:
        ci_router = ci_router[0]
    
def allocate_ports(q, network_id, test_id="", count=1):
    # Bulk port creation
    request_body = { "ports": [] }
    for port in range(count):
        request_body['ports'].append({ "network_id" : network_id, "name" : "ci-" + str(port) + '-' + test_id })
    return q.create_port(request_body)['ports']

# Not used atm
def make_key(n, test_id):
    command = 'ssh-keygen -t rsa -q -N "" -f keys/'+test_id
    process = subprocess.Popen(command)
    n.keypairs.create(test_id, 'keys/'+test_id)

def make(n, q, args):
    image           = args.image
    ci_subnet_index = args.ci_subnet_index
    scenario        = args.scenario
    data_path       = args.data_path
    fragment_path   = args.fragment_path

    if args.debug:
        print 'Debugging is on!'
        debug.debug = True

    test_id = uuid.uuid4().hex
    print "Running test: " + test_id 

    ci_network_name = u'ci-' + unicode(test_id)

    # Ci network with external route
    # There can be only one of these per tenant
    # because overlapping subnets + router doesn't work
    make_network(q, 'ci')
    make_subnet(q, 'ci', get_ci_network(q), ci_subnet_index, gateway=True)
    set_external_routing(q, get_ci_subnet(q))

    # The build server IP on the 'build' (ci) network must be known
    # so we preallocate it here, as well as the control node ip
    ci_ports = allocate_ports(q, get_ci_network(q)['id'], test_id, 2)

    # the openstack management network ('public interface')
    test_net1 = make_network(q, ci_network_name, 1)
    subnet1 = make_subnet(q, ci_network_name, test_net1, 1)
    # This is needed for tunnel_ip unless we use %eth2 or similar
    net1_ports = allocate_ports(q, test_net1['id'], test_id, 1)

    # Pretend external network for the controller to simulate l3
    test_net2 = make_network(q, ci_network_name, 2)
    subnet2 = make_subnet(q, ci_network_name, test_net2, 2)

    # To be put into the test run config
    build_node_ip = ci_ports[0]['fixed_ips'][0]['ip_address']
    control_node_ip = ci_ports[1]['fixed_ips'][0]['ip_address']
    # Not sure if we need this
    control_node_internal = net1_ports[0]['fixed_ips'][0]['ip_address']

    # config is a dictionary updated from env vars and user supplied
    # yaml files to serve as input to hiera
    hiera_config_meta =  build_metadata(data_path, scenario, 'user')

    hiera_config_meta.update({'controller_public_address'   : str(control_node_ip),
                      'controller_internal_address' : str(control_node_ip),
                      'controller_admin_address'    : str(control_node_ip),
                      'cobbler_node_ip'             : str(build_node_ip),
                    })

    initial_config_meta = build_metadata(data_path, scenario, 'config')
    initial_config_meta.update({'controller_public_address'   : str(control_node_ip),
                      'controller_internal_address' : str(control_node_ip),
                      'controller_admin_address'    : str(control_node_ip),
                      'cobbler_node_ip'             : str(build_node_ip),
                    })

    build_deploy = fragment.compose('build-server', data_path, fragment_path, scenario, initial_config_meta)
    control_deploy = fragment.compose('control-server', data_path, fragment_path, scenario, initial_config_meta)
    compute_deploy = fragment.compose('compute-server02', data_path, fragment_path, scenario, initial_config_meta)

    dprint('build_deploy: ' + str(build_deploy))
    dprint('control_deploy: ' + str(control_deploy))
    dprint('compute_deploy: ' + str(compute_deploy))

    user_config_yaml = yaml.dump(hiera_config_meta, default_flow_style=False)
    initial_config_yaml = yaml.dump(initial_config_meta, default_flow_style=False)

    dprint('Config Yaml: \n' + str(initial_config_yaml))
    dprint('User Yaml: \n' + str(user_config_yaml))

    build_node = boot_puppetised_instance(n, 
                    'build-server',
                    image,
                    build_nic_port_list([ci_ports[0]['id']]),
                    deploy=build_deploy,
                    files={u'/root/hiera_config.py': build_server_hiera_config(),
                           u'/root/user.yaml' : user_config_yaml,
                           u'/root/config.yaml' : initial_config_yaml},
                    meta={'ci_test_id' : test_id}
                    )

    # eth0, eth1 preallocated, eth2 dhcp
    control_nics = (build_nic_port_list([ci_ports[1]['id']]) + 
                   build_nic_port_list([net1_ports[0]['id']]) + 
                   build_nic_net_list([test_net2]))

    control_node = boot_puppetised_instance(n, 
                      'control-server', 
                       image, 
                       control_nics,
                       deploy=control_deploy,
                       #files={u'/root/meta_data.yaml' : config_yaml},
                       meta={'ci_test_id' : test_id})

    compute_node = boot_puppetised_instance(n, 
                      'compute-server02', 
                       image, 
                       build_nic_net_list([get_ci_network(q), test_net1]),
                       deploy=compute_deploy,
                       #files={u'/root/meta_data.yaml' : config_yaml},
                       meta={'ci_test_id' : test_id})

def get(n, q, args):
    run_instances = {}
    instances = n.servers.list()
    for instance in instances:
        if 'ci_test_id' in instance.metadata:
            if ((args.test_id and instance.metadata['ci_test_id'] == unicode(args.test_id)) or not args.test_id):
                if instance.metadata['ci_test_id'] not in run_instances:
                    run_instances[instance.metadata['ci_test_id']] = [instance]
                else:
                    run_instances[instance.metadata['ci_test_id']].append(instance)
    for test_id, servers in run_instances.items():
        print "Test ID: " + test_id
        for server in servers:
            print "%-8.8s %16.16s" % (server.id, server.name)
