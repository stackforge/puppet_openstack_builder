#!/usr/bin/env python
"""
    stack-builder.hiera_config
    ~~~~~~~~~~~~~~~~~~~~~~~~~~

    This module will read metadata set during instance
    launch and override any yaml under the /etc/puppet/data
    directory (except data_mappings) that has a key matching
    the metadata
"""

import yaml
import os

hiera_dir = '/etc/puppet/data'
metadata_path = '/root/config.yaml'

#debug
#metadata_path = './sample.json'
#hiera_dir = './openstack-installer/data/'

# Child processes cannot set environment variables, so
# create a bash file to set some exports for facter
def facter_config():
    with open(metadata_path, 'r') as metadata:
        meta = yaml.load(metadata.read())
        print meta
        with open('/root/fact_exports', 'w') as facts:
            for key,value in meta.items():
                # Things with spaces can't be exported
                if ' ' not in str(value):
                    facts.write('FACTER_' + str(key) + '=' + str(value) + '\n')

#TODO
def hostname_config():
    with open(metadata_path, 'r') as metadata:
        meta = yaml.load(metadata.read())
        with open('/root/openstack-installer/manifests/setup.pp', 'a') as facts:
            for key,value in meta.items():
                pass

facter_config()
