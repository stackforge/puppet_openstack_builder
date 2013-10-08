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

def config_builder():
    # load metadata from config-drive
    with open(metadata_path, 'r') as metadata:
       meta = yaml.load(metadata.read())
       print meta

    # Set values specified in config_drive
    for path, dirs, files in os.walk(hiera_dir):
        if '.git' in dirs:
            dirs.remove('.git')
        if 'data_mappings' in dirs:
            dirs.remove('data_mappings')
        for yaml_file in files:
            if yaml_file[-5:] == '.yaml':
                with open(path + '/' + yaml_file, 'r') as hiera_file:
                    y = yaml.load(hiera_file.read())
                    for key, value in meta.items():
                        if (y != None and key in y):
                            print "Setting : " + key + " with " + str(value)
                            y[key] = value

                with open(path + '/' + yaml_file, 'w') as hiera_file:
                    hiera_file.write(yaml.dump(y, default_flow_style=False))
            
#config_builder()

# Child processes cannot set environment variables, so
# create a bash file to set some exports for facter
def facter_config():
    with open(metadata_path, 'r') as metadata:
        meta = yaml.load(metadata.read())
        print meta
        with open('/root/fact_exports', 'w') as facts:
            for key,value in meta.items():
                facts.write('FACTER_' + str(key) + '=' + str(value) + '\n')

facter_config()
