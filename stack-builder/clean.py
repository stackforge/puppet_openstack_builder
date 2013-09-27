#!/bin/python
from novaclient.v1_1 import client as nclient
from quantumclient.quantum import client as qclient
from time import sleep
import os

def kill(n, q, args):
    instances = n.servers.list()
  
    for instance in instances:
        if 'ci_test_id' in instance.metadata or instance.name[-3:] == '-ci':
             n.servers.delete(instance)

    sleep(3)

    nets = q.list_networks()
    subnets = q.list_subnets()
    routers = q.list_routers()
    ports = q.list_ports()

    for p in ports['ports']:
        if p['name'][0:3] == 'ci-':
           try:
               q.delete_port(p['id'])
               print 'deleted port ' + p['id']
           except:
               pass

    for r in routers['routers']:
        if r['name'][0:3] == 'ci-':
            try:
                q.remove_gateway_router(r['id'])
                for subnet in subnets['subnets']:
                    if subnet['name'] == r['name']:
                        q.remove_interface_router(r['id'], { 'subnet_id' : subnet['id'] })
          
                q.delete_router(r['id'])
                print 'deleted router' + r['name']
            except:
                pass

    for net in subnets['subnets']:
        if net['name'][0:3] == 'ci-':
            try:
                q.delete_subnet(net['id'])
                print 'deleted subnet' + net['name']
            except:
                pass

    for net in nets['networks']:
        if net['name'][0:3] == 'ci-':
            try:
                q.delete_network(net['id'])
                print 'deleted network' + net['name']
            except:
                pass

