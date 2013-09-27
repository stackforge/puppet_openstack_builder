from build import debug, noop

def dprint(string):
    if debug:
        print '\033[94m' + str(string) + '\033[0m'


def nprint(string):
    if noop:
        print '\033[92m' + str(string) + '\033[0m'
