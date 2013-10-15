#!/usr/bin/env python
"""
    stack-builder.rebuild
    ~~~~~~~~~~~~~~~~~~~
    This module will rebuild any unbuilt nodes
    in a currently running test

"""
import debug
import subprocess
import os
import quantumclient
import fragment
import yaml
import json
import time
import build

from metadata import build_metadata
from debug import dprint

# Assumes the networks hasn't been killed
def rebuild(n,q,k,args):
    image           = args.image
    ci_subnet_index = 123 # TODO fix inital setup stuff
    scenario        = args.scenario
    data_path       = args.data_path
    fragment_path   = args.fragment_path
    test_id         = args.test_id

    if args.debug:
        debug.debug = True

    with open(data_path + '/nodes/' + scenario + '.yaml') as scenario_yaml_file:
        scenario_yaml = yaml.load(scenario_yaml_file.read())

    current_instances = build.get(n,q,k,args)[unicode(test_id)]
    print current_instances
    # determine which instances are missing
    current_instance_names = [instance.name for instance in current_instances]
    missing_instance_names = []
    for instance in scenario_yaml['nodes'].keys():
        if instance not in current_instance_names:
            missing_instance_names.append(instance)

    dprint("present instances: " + str(current_instance_names))
    dprint("missing instances: " + str(missing_instance_names))
    networks = {}
    subnets = {}
    ports = {}

    networks['ci'] = build.get_ci_network(q,k)

    all_nets = q.list_networks()

    # build networks list, assume they're all there
    for node, props in scenario_yaml['nodes'].items():
        for network in props['networks']:
            if network != 'ci':
                networks[network] = get_network(all_nets, network, test_id)

    dprint('networks ' + str(networks))
    # New ports for the missing instances
    for node, props in scenario_yaml['nodes'].items():
        if node in missing_instance_names:
            for network in props['networks']:
                if node not in ports:
                    ports[node] = {}
                    dprint('creating port for node' + str(node) + ' on network ' + network)
                    ports[node][network] = build.allocate_ports(q, networks[network]['id'], test_id)
                else:
                    dprint('creating port for node' + str(node) + ' on network ' + network)
                    ports[node][network] = build.allocate_ports(q, networks[network]['id'], test_id)

    # Recreate port dictionary for existing instances
    for node in current_instances:
        nodename = str(node.name)
        for network, ips in node.networks.items():
             if nodename not in ports:
                ports[nodename] = {}
                ports[nodename][network] = [{'fixed_ips' : [{'ip_address' : ips[0]}]}]
             else:
                ports[nodename][network] = [{'fixed_ips' : [{'ip_address' : ips[0]}]}]

    dprint("Ports"  + str(ports))
    # Re-create metadata and deploy
    initial_config_meta = build_metadata(data_path, scenario, 'config')
    hiera_config_meta =  build_metadata(data_path, scenario, 'user')

    meta_update = build.metadata_update(scenario_yaml, ports)
    dprint('runtime metadata: ' + str(meta_update))
    hiera_config_meta.update(meta_update)
    initial_config_meta.update(meta_update)

    # fragment composition
    deploy_files = {}
    for node, props in scenario_yaml['nodes'].items():
        deploy_files[node] = fragment.compose(node, data_path, fragment_path, scenario, initial_config_meta)
        dprint(node + 'deploy:\n' + deploy_files[node])

    user_config_yaml = yaml.dump(hiera_config_meta, default_flow_style=False)
    initial_config_yaml = yaml.dump(initial_config_meta, default_flow_style=False)

    # Create missing instances
    port_list = {}
    for node, props in scenario_yaml['nodes'].items():
        if node in missing_instance_names:
            nics = []
            for network in props['networks']:
                nics.append(ports[node][network][0]['id'])
            port_list[node] = build.build_nic_port_list(nics)

    for node, props in scenario_yaml['nodes'].items():
        if node in missing_instance_names:
            dprint("booting " + str(node))
            build.boot_puppetised_instance(n,
                        node,
                        image,
                        port_list[node],
                        deploy=build.cloud_init,
                        files={
                               u'/root/deploy'      : deploy_files[node],
                               u'/root/user.yaml'   : user_config_yaml,
                               u'/root/config.yaml' : initial_config_yaml},
                        meta={'ci_test_id' : test_id}
                        )            

def get_network(all_nets, network, test_id):
    for n in all_nets['networks']:
        if n['name'] == unicode('ci-'+network+'-'+test_id):
            return n
