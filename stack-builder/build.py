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
import json
import time
import urllib2

from metadata import build_metadata
from debug import dprint

cloud_init="""#cloud-config
runcmd:
 - [chmod, ug+x, /root/deploy]
 - [sh, /root/deploy]
 - echo 'complete' > /var/www/deploy

output: {all: '| tee -a /var/log/cloud-init-output.log'}
"""

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
    #if ci_network_name != 'ci':
    #    ci_network_name = ci_network_name + str(index)

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
    #if ci_network_name != 'ci':
    #    ci_network_name = ci_network_name + str(index)

    if ci_network_name not in [subnet['name'] for subnet in subnets['subnets']]:
        dprint("CI subnet " + str(index) + " doesn't exist. Creating ...")
        try:
            # internal networks
            if not gateway:
                dprint("create_subnet({'subnet': { 'name':" + ci_network_name + str(index) + ",\n" +
                       "            'network_id': " + test_net['id'] + ",\n" +
                       "            'ip_version': 4,\n" +
                       "            'cidr': '10.2." + str(index) + ".0/24',\n" +
                       "            'enable_dhcp': True,\n" +
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

   dprint("Booting " + name)
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
def get_public_network(q, public_network):
    for network in q.list_networks()['networks']:
        if network['name'] == public_network:
            return network

def get_external_router(q):
    for router in q.list_routers()['routers']:
        if router['name'] == 'ci':
            return router

def get_tenant_id(k):
    tenant_name = os.environ['OS_TENANT_NAME']
    for tenant in k.tenants.list():
        if tenant.name == tenant_name:
            return str(tenant.id)

# This can easily be problematic with multiple tenants,
# So make sure we get the one for the current tenant
def get_ci_network(q, k):
    for network in q.list_networks()['networks']:
        if network['name'] == 'ci' and network['tenant_id'] == get_tenant_id(k):
            return network

def get_ci_subnet(q, k):
    for subnet in q.list_subnets()['subnets']:
        if subnet['name'] == 'ci' and subnet['tenant_id'] == get_tenant_id(k):
            return subnet 

def set_external_routing(q, subnet, public_network):
    routers = q.list_routers()
    ci_router = [router for router in routers['routers'] if router['name'] == 'ci']
    if len(ci_router) == 0:
        ci_router = q.create_router( { 'router': { 'name': 'ci',
                                                   'admin_state_up': 'true'} })['router']
        q.add_gateway_router(ci_router['id'], {'network_id': get_public_network(q, public_network)['id']})
        q.add_interface_router(ci_router['id'], {'subnet_id': subnet['id']})
    else:
        ci_router = ci_router[0]
    
def allocate_ports(q, network_id, test_id="", count=1):
    # Bulk port creation
    request_body = { "ports": [] }
    for port in range(count):
        request_body['ports'].append({ "network_id" : network_id, "name" : "ci-" + str(port) + '-' + test_id })
    return q.create_port(request_body)['ports']

def metadata_update(scenario_yaml, ports):
    # IP addresses of particular nodes mapped to specified config
    # values to go into hiera + build scripts. See data/nodes/2_role.yaml
    # all values will also be mapped to a generic key:
    # meta['hostname_networkname'] = ip
    meta_update = {}
    for node, props in scenario_yaml['nodes'].items():
        for network, mappings in props['networks'].items():
            if mappings != None:
                for mapping in mappings:
                    meta_update[mapping] = str(ports[node][network][0]['fixed_ips'][0]['ip_address'])
            # replace dashes since bash variables can't contain dashes
            # but be careful when using this since hostnames can't contain underscores
            # so they need to be converted back
            meta_update[network + '_' + node.replace('-', '_')] = str(ports[node][network][0]['fixed_ips'][0]['ip_address'])
    return meta_update

# Not used atm
def make_key(n, test_id):
    command = 'ssh-keygen -t rsa -q -N "" -f keys/'+test_id
    process = subprocess.Popen(command)
    n.keypairs.create(test_id, 'keys/'+test_id)

def make(n, q, k, args):
    image           = args.image
    ci_subnet_index = 123 # TODO fix inital setup stuff
    scenario        = args.scenario
    data_path       = args.data_path
    fragment_path   = args.fragment_path
    public_network  = args.public_network

    if args.debug:
        debug.debug = True

    test_id = uuid.uuid4().hex
    print test_id 

    networks = {}
    subnets = {}
    ports = {}

    # Ci network with external route
    # There can be only one of these per tenant
    # because overlapping subnets + router doesn't work
    networks['ci'] = make_network(q, 'ci')
    subnets['ci']  = make_subnet(q, 'ci', networks['ci'], ci_subnet_index, gateway=True)
    set_external_routing(q, get_ci_subnet(q, k), public_network)
    ci_subnet_index = ci_subnet_index + 1

    with open(data_path + '/nodes/' + scenario + '.yaml') as scenario_yaml_file:
        scenario_yaml = yaml.load(scenario_yaml_file.read())

    # Find needed internal networks
    for node, props in scenario_yaml['nodes'].items():
        for network in props['networks']:
            if network != 'ci': # build network with NAT services
                networks[network] = False

    # Create internal networks
    for network, gate in networks.items():
        if network != 'ci':
            networks[network] = make_network(q, 'ci-' + network + '-' + test_id)
            subnets[network] = make_subnet(q, 'ci-' + network + '-' + test_id,
                                        networks[network], index=ci_subnet_index, gateway=gate)
            ci_subnet_index = ci_subnet_index + 1

    # Allocate ports
    for node, props in scenario_yaml['nodes'].items():
        for network in props['networks']:
            if node not in ports:
                ports[node] = {}
                ports[node][network] = allocate_ports(q, networks[network]['id'], test_id)
            else:
                ports[node][network] = allocate_ports(q, networks[network]['id'], test_id)

    dprint("networks")
    for net, value in networks.items():
        dprint (net + str(value))
    dprint ("subnets")
    for snet, value in subnets.items():
        dprint (snet + str(value))
    dprint ("ports")
    dprint (json.dumps(ports,sort_keys=True, indent=4))

    # config is a dictionary updated from env vars and user supplied
    # yaml files to serve as input to hiera and build scripts
    initial_config_meta = build_metadata(data_path, scenario, 'config')
    hiera_config_meta =  build_metadata(data_path, scenario, 'user')

    meta_update = metadata_update(scenario_yaml, ports)

    hiera_config_meta.update(meta_update)
    initial_config_meta.update(meta_update)

    # fragment composition
    deploy_files = {}
    for node, props in scenario_yaml['nodes'].items():
        deploy_files[node] = fragment.compose(node, data_path, fragment_path, scenario, initial_config_meta)
        dprint(node + 'deploy:\n' + deploy_files[node])

    user_config_yaml = yaml.dump(hiera_config_meta, default_flow_style=False)
    initial_config_yaml = yaml.dump(initial_config_meta, default_flow_style=False)

    dprint('Config Yaml: \n' + str(initial_config_yaml))
    dprint('User Yaml: \n' + str(user_config_yaml))

    port_list = {}
    for node, props in scenario_yaml['nodes'].items():
        nics = []
        for network in props['networks']:
            nics.append(ports[node][network][0]['id'])
        port_list[node] = build_nic_port_list(nics)

    for node, props in scenario_yaml['nodes'].items():
        boot_puppetised_instance(n,
                        node,
                        image,
                        port_list[node],
                        deploy=cloud_init,
                        files={
                               u'/root/deploy'      : deploy_files[node],
                               u'/root/user.yaml'   : user_config_yaml,
                               u'/root/config.yaml' : initial_config_yaml},
                        meta={'ci_test_id' : test_id}
                        )

def cli_get(n,q,k,args):
    run_instances = get(n,q,k,args)
    for test_id, servers in run_instances.items():
        print "Test ID: " + test_id
        for server in servers:
            print "%-8.8s %16.16s %12.12s" % (server.id, server.name, str(server.networks['ci'][0]))

def get(n, q, k, args):
    run_instances = {}
    instances = n.servers.list()
    for instance in instances:
        if 'ci_test_id' in instance.metadata:
            if ((args.test_id and instance.metadata['ci_test_id'] == unicode(args.test_id)) or not args.test_id):
                if instance.metadata['ci_test_id'] not in run_instances:
                    run_instances[instance.metadata['ci_test_id']] = [instance]
                else:
                    run_instances[instance.metadata['ci_test_id']].append(instance)
    return run_instances

# Wait for deployment to finish
def wait(n, q, k, args):
    test_id = args.test_id

    servers = get(n,q,k,args)
    for server in servers[test_id]:
        response = False
        while not response:
            try:
                response = urllib2.urlopen('http://' + str(server.networks['ci'][0]) + '/deploy')
                response = True
            except:
                time.sleep(15)

# Get cloud-init logs
# TODO get all service logs
def log(n, q, k, args):
    test_id = args.test_id
    path = args.data_path
    scenario = args.scenario

    servers = get(n,q,k,args)
    for server in servers[test_id]:
        response = False
        while not response:
            try:
                response = urllib2.urlopen('http://' + str(server.networks['ci'][0]) + '/cloud-init-output.log')
                with open('./' + str(server.name) + '-cloud-init.log', 'w') as output:
                    output.write(response.read())
                response = True
            except:
                time.sleep(20)
