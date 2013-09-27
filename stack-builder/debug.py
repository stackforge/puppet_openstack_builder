debug = False
even = True

def dprint(string):
    global even
    global debug
    if debug:
        if even:
            print '\x1b[34m' + str(string) + '\x1b[0m'
            even = False
        else:
            print '\x1b[1;34m' + str(string) + '\x1b[0m'
            even = True
