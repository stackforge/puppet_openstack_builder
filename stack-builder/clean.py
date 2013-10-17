#!/usr/bin/env python
"""
    stack-builder.clean
    ~~~~~~~~~~~~~~~~~~~

    This module is used by the kill subcommand
    of the sb binary to destroy any virtual
    resources created by an sb make command, with
    the exception of the ci network, subnet and router
    used as the deployment network and providing NAT.

"""
from novaclient.v1_1 import client as nclient
from quantumclient.quantum import client as qclient
from time import sleep
import os

def kill(n, q, k, args):
    """
    Destroy either all virtual test resources,
    or the resources from a particular run.
    """
    test_id = None
    if args.test_id:
        test_id = args.test_id

    instances = n.servers.list()
  
    for instance in instances:
        if 'ci_test_id' in instance.metadata:
            if ((test_id and instance.metadata['ci_test_id'] == test_id) or not test_id):
                print "Deleting instance " + instance.id + " from test " + instance.metadata['ci_test_id']
                n.servers.delete(instance)

    sleep(3)

    nets = q.list_networks()
    subnets = q.list_subnets()
    routers = q.list_routers()
    ports = q.list_ports()

    for p in ports['ports']:
        if p['name'][0:3] == 'ci-':
           if ((test_id and p['name'][-32:] == test_id) or not test_id):
               try:
                   q.delete_port(p['id'])
                   print 'deleted port ' + p['id']
               except:
                   pass

    for r in routers['routers']:
        if r['name'][0:3] == 'ci-':
           if ((test_id and r['name'][-32:] == test_id) or not test_id):
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
            if ((test_id and net['name'][-32:] == test_id) or not test_id):
                try:
                    q.delete_subnet(net['id'])
                    print 'deleted subnet ' + net['name']
                except:
                    pass

    for net in nets['networks']:
        if net['name'][0:3] == 'ci-':
            if ((test_id and net['name'][-32:] == test_id) or not test_id):
                try:
                    q.delete_network(net['id'])
                    print 'deleted network ' + net['name']
                except:
                    pass

