import os
import shutil
import yaml
import re

dpath = './data'

def prepare_target():
    print "=============================="
    print "= Preparing target directory ="
    print "=============================="

    dirs = os.listdir('.')
    if 'data.new' not in dirs:
        os.mkdir('./data.new')
        print 'created data.new'

    dirs = os.listdir('./data.new')
    if 'hiera_data' not in dirs:
        shutil.copytree(dpath + '/hiera_data', './data.new/hiera_data')
        print 'copied tree from ' + dpath + '/hiera_data to /data.new/hiera_data'

        # Nodes used for vagrant info
        shutil.copytree(dpath + '/nodes', './data.new/nodes')
        print 'copied tree from ' + dpath + '/nodes to /data.new/nodes'
        shutil.copyfile('./contrib/aptira/build/Vagrantfile', './Vagrantfile')
        shutil.copyfile('./contrib/aptira/build/Puppetfile', './Puppetfile')

        shutil.copyfile('./contrib/aptira/puppet/config.yaml', './data.new/config.yaml')
        shutil.copyfile('./contrib/aptira/puppet/site.pp', './manifests/site.pp')
        shutil.copyfile('./contrib/aptira/puppet/user.yaml', './data.new/hiera_data/user.yaml')

    dirs = os.listdir('./data.new/hiera_data')
    if 'roles' not in dirs:
        os.mkdir('./data.new/hiera_data/roles')
        print 'made role dir'
    if 'contrib' not in dirs:
        os.mkdir('./data.new/hiera_data/contrib')
        print 'made contrib dir'

def hierafy_mapping(mapping):
   new_mapping = []
   if '{' in mapping:
       for c in mapping:
           if c == '}':
               new_mapping.append("')}")
           elif c == '{':
               new_mapping.append("{hiera('")
           else:
               new_mapping.append(c)
       return "".join(new_mapping)
   else:
       return "".join(['%{hiera(\'', mapping, '\')}'])

def scenarios():

    print "=============================="
    print "===== Handling Scenarios ====="
    print "=============================="

    scenarios = {}

    # This will be a mapping with scenario as key, to
    # a mapping of roles to a list of classes
    scenarios_as_hiera = {}

    for root,dirs,files in os.walk(dpath + '/scenarios'):
        for name in files:
            print os.path.join(root,name)
            with open(os.path.join(root,name)) as yf:
                scenarios[name[:-5]] = yaml.load(yf.read())

    for scenario, yaml_data in scenarios.items():
        if not os.path.exists('./data.new/hiera_data/scenario/' + scenario):
            os.makedirs('./data.new/hiera_data/scenario/' + scenario)
        for description in yaml_data.values():
            for role, values in description.items():
                if os.path.isfile('./data.new/hiera_data/scenario/' + scenario + '/' + role + '.yaml'):
                    with open('./data.new/hiera_data/scenario/' + scenario + '/' + role + '.yaml', 'a') as yf:
                        if 'classes' in values:
                            yf.write('classes:\n')
                            for c in values['classes']:
                                yf.write('  - \"' + c + '\"\n')
                        if 'class_groups' in values:
                            yf.write('class_groups:\n')
                            for c in values['class_groups']:
                                yf.write('  - \"' + c + '\"\n')

                else:
                    with open('./data.new/hiera_data/scenario/' + scenario + '/' + role + '.yaml', 'w') as yf:
                        if 'classes' in values:
                            yf.write('classes:\n')
                            for c in values['classes']:
                                yf.write('  - \"' + c + '\"\n')
                        if 'class_groups' in values:
                            yf.write('class_groups:\n')
                            for c in values['class_groups']:
                                yf.write('  - \"' + c + '\"\n')

def class_groups():

    print "=============================="
    print "=== Handling Class Groups ===="
    print "=============================="

    # Classes and class groups can contain interpolation, which
    # should be handled
    with open('./data.new/hiera_data/class_groups.yaml', 'w') as class_groups:
        for root,dirs,files in os.walk(dpath + '/class_groups'):
            for name in files:
                if 'README' not in name:
                    print os.path.join(root,name)
                    with open(os.path.join(root,name)) as yf:
                        cg_yaml = yaml.load(yf.read())
                        class_groups.write(name[:-5] + ':\n')
                        if 'classes' in cg_yaml:
                            for clss in cg_yaml['classes']:
                                class_groups.write('  - \"' + clss + '\"\n')
                        class_groups.write('\n')

    with open('./data.new/hiera_data/class_groups.yaml', 'r') as class_groups:
        s = class_groups.read()

    os.remove('./data.new/hiera_data/class_groups.yaml')
    s.replace('%{', "%{hiera(\'").replace('}', "\')}")
    with open('./data.new/hiera_data/class_groups.yaml', 'w') as class_groups:
        class_groups.write(s)

def global_hiera():

    print "=============================="
    print "=== Handling Global Hiera ===="
    print "=============================="

    scenarios = {}
    globals_as_hiera = {}

    for root,dirs,files in os.walk(dpath + '/global_hiera_params'):
        for name in files:
            print os.path.join(root,name)
            with open(os.path.join(root,name)) as yf:
                path = os.path.join(root,name).replace(dpath,'./data.new') \
                                              .replace('global_hiera_params', 'hiera_data')
                scenarios[path] = yaml.load(yf.read())

    for key in scenarios.keys():
        print key

    for scenario, yaml_data in scenarios.items():
        if not os.path.exists(scenario):
            with open(scenario, 'w') as yf:
                yf.write('# Global Hiera Params:\n')
                for key, value in yaml_data.items():
                    if value == False or value == True:
                        yf.write(key + ': ' + str(value).lower() + '\n')
                    else:
                        yf.write(key + ': ' + str(value) + '\n')
        else:
            with open(scenario, 'a') as yf:
                yf.write('# Global Hiera Params:\n')
                for key, value in yaml_data.items():
                    if value == False or value == True:
                        yf.write(key + ': ' + str(value).lower() + '\n')
                    else:
                        yf.write(key + ': ' + str(value) + '\n')


def find_array_mappings():
    print "=============================="
    print "=== Array Data Mappings ======"
    print "=============================="
    print "Hiera will flatten arrays when"
    print "using introspection, so arrays"
    print "and hashes are handled using  "
    print "YAML anchors. This means they "
    print "must be within a single file."
    print "=============================="

    array_mappings = {}
    # File path : [lines to change]
    lines = {}
    for root,dirs,files in os.walk(dpath + '/hiera_data'):
        for name in files:
            path = os.path.join(root,name)
            with open(path) as yf:
                y = yaml.load(yf.read())
                for key, value in y.items():
                    # Numbers and strings interpolate reasonably well, and things
                    # that aren't mappings will be for passing variables, and thus
                    # should contain the double colon for scope in most cases.
                    # This method is certainly fallible.
                    if (not isinstance(value, str) and ('::' not in key)):
                        print key + ' IS NON STRING MAPPING: ' + str(value)
                        if path.replace('/data/', '/data.new/') not in lines:
                            lines[path.replace('/data/', '/data.new/')] = {}
                        for nroot,ndirs,nfiles in os.walk(dpath + '/data_mappings'):
                            for nname in nfiles:
                                with open(os.path.join(nroot,nname)) as nyf:
                                    ny = yaml.load(nyf.read())
                                    if key in ny.keys():
                                        print key + ' is found, maps to: ' + str(ny[key]) + ' in ' + path
                                        for m in ny[key]:
                                            if key not in lines[path.replace('/data/', '/data.new/')]:
                                                lines[path.replace('/data/', '/data.new/')][key] = []
                                            else:
                                                lines[path.replace('/data/', '/data.new/')][key].append(m)
                                        # Inform data_mappings it can ignore these values
                                        array_mappings[key] = value

    # modify the files that contain the problem mappings
    # to contain anchor sources
    for source, mappings in lines.items():
        print 'handling non-string mapping in ' + str(source)
        # read original file and replace mappings
        # with yaml anchor sources
        with open(source, 'r') as rf:
            ofile = rf.read()
            for map_from in mappings.keys():
                if ('\n' + map_from + ':') not in ofile:
                    print 'WARNING: mapping ' + map_from + 'not found in file ' + source
                ofile = ofile.replace('\n' + map_from + ':','\n' +  map_from + ': &' + map_from + ' ')

        with open(source, 'w') as wf:
            wf.write(ofile)

    # appen anchor references to files
    for source, mappings in lines.items():
        with open(source, 'a') as wf:
            wf.write('\n')
            wf.write("#########################################\n")
            wf.write('# Anchor mappings for non-string elements\n')
            wf.write("#########################################\n\n")
            for map_from, map_to in mappings.items():
                for param in map_to:
                    wf.write(param + ': *' + map_from + '\n')

    return array_mappings

def data_mappings():
    """ Take everything from common.yaml and put
    it in data_mappings.yaml in hiera_data, and everything
    else try to append to its appropriate switch in the
    hierarchy """

    array_mappings = find_array_mappings()

    print "=============================="
    print "=== Handling Data Mappings ==="
    print "=============================="

    data_mappings = {}
    mappings_as_hiera = {}
    for root,dirs,files in os.walk(dpath + '/data_mappings'):
        for name in files:
            print os.path.join(root,name)
            with open(os.path.join(root,name)) as yf:
                path = os.path.join(root,name).replace(dpath,'data.new/') \
                                              .replace('data_mappings', 'hiera_data')
                data_mappings[path] = yaml.load(yf.read())
                mappings_as_hiera[path] = []

    # create a list of things to append for each file
    for source, yaml_mapping in data_mappings.items():
        for mapping, list_of_values in yaml_mapping.items():
            if mapping in array_mappings.keys():
                print mapping + ' found in ' + source + ', skipping  non-string mapping'
            else:
                mappings_as_hiera[source].append('# ' + mapping)
                for entry in list_of_values:
                    mappings_as_hiera[source].append(entry + ": \"" + hierafy_mapping(mapping) + '\"')
                mappings_as_hiera[source].append('')

    for key, values in mappings_as_hiera.items():
        folder = os.path.dirname(key)
        if not os.path.exists(folder):
            os.makedirs(folder)

        if os.path.isfile(key):
            print "appending to path "+ key
            with open(key, 'a') as map_file:
                map_file.write("#################\n")
                map_file.write("# Data Mappings #\n")
                map_file.write("#################\n\n")
                map_file.write("\n".join(values))
        else:
            print "writing to new path "+ key
            with open(key, 'w') as map_file:
                map_file.write("#################\n")
                map_file.write("# Data Mappings #\n")
                map_file.write("#################\n\n")
                map_file.write('\n'.join(values))

def move_dirs():
    shutil.move(dpath, './data.old')
    shutil.move('./data.new', './data')

if __name__ == "__main__":
    prepare_target()
    data_mappings()
    scenarios()
    class_groups()
    global_hiera()
    move_dirs()
