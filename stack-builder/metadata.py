#!/usr/bin/env python
"""
    stack-builder.metadata
    ~~~~~~~~~~~~~~~~~~~~~~

    This module will load in relevant environment variables
    and config from the scenario yaml in order to create a
    dictionary of metadata that will be used to build shell
    scripts, populate hiera data for puppet, and drive the
    creation of appropriate openstack resources for the
    specified scenario. Environment variables will
    override yaml data.
"""
import os
import yaml

def import_environ_keys(metadata, prefix):
    """
    Import any environment variables with the correct
    prefix into the metadata dictionary
    """
    for key,value in os.environ.items():
        if key[:9] == prefix:
            metadata[key[9:]] = value
    return metadata

def import_yaml(path, files):
    """
    """
    metadata = {}

    for filename in files:
        if os.path.exists(path+filename+'.yaml'):
            with open(path+filename+'.yaml', 'r') as f:
                y = yaml.load(f.read())
                if y:
                    for key, value in y.items():
                        metadata[key] = value
    return metadata

def build_metadata(path, scenario, config):
    """
    Create a metadata dictionary from yaml
    and environment variables
    """
    if config == "config":
        prefix = 'osi_conf_'
        files = ['config']
        return import_environ_keys(import_yaml(path+'/', files), prefix)
    if config == 'user':
        prefix = 'osi_user_'
        files = ['user']
        return import_environ_keys(import_yaml(path+'/hiera_data/',files), prefix)
    if config == "global":
        prefix = 'osi_glob_'
        files = ['user']
        return import_environ_keys(import_yaml(path+'/global_hiera_params/', files), prefix)
    else:
        print "Invalid config type: choose from 'user', 'conf' and 'glob'"

def show(n, q, k, args):
    hostname = args.node
    yaml_dir = args.yaml_dir
    scenario = args.scenario
    config   = args.config

    print yaml.dump(build_metadata(yaml_dir, scenario, config), default_flow_style=False)
