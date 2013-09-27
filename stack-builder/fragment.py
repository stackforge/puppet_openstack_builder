import os
import string
import yaml

class PercentTemplate(string.Template):
    delimiter='%'

def available_fragments(d='./stack-builder/fragments'):
    return [d + '/' + f for f in os.listdir(d)]

# Create a deploy script from a list of fragments
def build_deploy(frag_list):
    deploy_script = ""
    for f in frag_list:
        with open(f, 'r') as frag:
            deploy_script = deploy_script + frag.read() + '\n'
    return deploy_script
            
def load_yaml_config(node_name, yaml_dir='./data', fragment_dir='./stack-builder/fragments', scenario='2_role'):
    with open(yaml_dir+'/nodes/'+scenario+'.yaml', 'r') as yaml_file:
        y = yaml.load(yaml_file.read())

        if node_name not in y['nodes']:
            print "No node listed for node " + node_name + " in scenario " + scenario
            return None
        if 'fragments' not in y['nodes'][node_name]:
            print "No fragments listed for node " + node_name + " in scenario " + scenario
            return None

        available = available_fragments(fragment_dir)
        for fragment in y['nodes'][node_name]['fragments']:
            if fragment_dir + '/' + fragment not in available:
                print "Fragment '" + fragment + "' specified in scenario " + scenario + "does not exist "

        return  [ fragment_dir + '/' + f for f in y['nodes'][node_name]['fragments']]

def compose(hostname, yaml_dir, fragment_dir, scenario, replacements):
    fragments = load_yaml_config(hostname, yaml_dir, fragment_dir, scenario)
    script = build_deploy(fragments)
    return PercentTemplate(script).safe_substitute(replacements)

def show(n, q, args):
    hostname = args.node
    yaml_dir = args.yaml_dir
    fragment_dir = args.fragment_dir
    scenario = args.scenario

    print compose(hostname, yaml_dir, fragment_dir, scenario, {'build_node_ip' : '192.168.1.100', 'control_node_ip' : '192.158.1.19'})
