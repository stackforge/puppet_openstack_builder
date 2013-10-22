import os
import string
import yaml

from metadata import build_metadata

def signal_type(fragment):
    if fragment[:5] == 'WAIT_':
        return 'wait'
    if fragment[:7] == 'SIGNAL_':
        return 'signal'
    return None

class PercentTemplate(string.Template):
    delimiter='%'

def available_fragments(d='./stack-builder/fragments'):
    return [d + '/' + f for f in os.listdir(d)]

# Create a deploy script from a list of fragments
def build_deploy(fragment_dir, frag_list, metadata):
    deploy_script = ""
    for f in frag_list:
        sig = signal_type(f)
        if sig == 'wait':
            # Wait syntax is as follows:
            # WAIT_signal hostname1 hostnameN
            with open(fragment_dir + '/WAIT_TEMPLATE', 'r') as temp:
                spl = f.split(' ')
                nodes = ""
                for node in spl[1:]:
                    # Handle debug case where there is none of this metadata
                    if 'ci_'+node.replace('-', '_') not in metadata:
                        metadata['ci_'+node.replace('-', '_')] = "{"+node+"_ip}"
                        print "Fragment creation: Node " + node + " IP not present in metadata: using " + "{" + node + "_ip}"
                    nodes = nodes + metadata['ci_'+node.replace('-', '_')] + " "

                repl = { 'nodes': nodes, 'signal': spl[0].split('_')[1] }
                frag = PercentTemplate(temp.read()).safe_substitute(repl)
                deploy_script = deploy_script + frag + '\n'

        elif sig == 'signal':
            with open(fragment_dir + '/SIGNAL_TEMPLATE', 'r') as temp:
                spl = f.split('_')
                frag = PercentTemplate(temp.read()).safe_substitute({'signal': spl[1]})
                deploy_script = deploy_script + frag + '\n'
        else:
            with open(fragment_dir + '/' + f, 'r') as frag:
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
            if fragment_dir + '/' + fragment not in available and not signal_type(fragment):
                print "Fragment '" + fragment + "' specified in scenario " + scenario + "does not exist "

        return [f for f in y['nodes'][node_name]['fragments']]
        

def compose(hostname, yaml_dir, fragment_dir, scenario, replacements):
    fragments = load_yaml_config(hostname, yaml_dir, fragment_dir, scenario)
    script = build_deploy(fragment_dir, fragments, replacements)
    return PercentTemplate(script).safe_substitute(replacements)

def show(n, q, k, args):
    hostname = args.node
    yaml_dir = args.yaml_dir
    fragment_dir = args.fragment_dir
    scenario = args.scenario

    print compose(hostname, yaml_dir, fragment_dir, scenario, build_metadata('./data', '2_role', 'config'))
