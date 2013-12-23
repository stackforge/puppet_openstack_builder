import os
import base64
import struct
import time
import uuid

# create mon secret
key = os.urandom(16)
header = struct.pack('<hiih', 1, int(time.time()), 0, len(key))

# create mon key
fsid = uuid.uuid4()

print "Your ceph_monitor_secret is: " + base64.b64encode(header + key)
print "Your ceph_monitor_fsid is: " + str(fsid)
