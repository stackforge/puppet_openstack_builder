#!/bin/bash

os=${1:-ubuntu}

if ! [ type qemu-img 2>/dev/null ]; then
   apt-get install -y qemu-utils
fi

#need kpartx for Fedora
if ! [ type kpartx 2>/dev/null ]; then
    apt-get install -y kpartx
fi

if ! [ -f diskimage-builder ]; then
    git clone https://github.com/openstack/diskimage-builder.git
fi

if ! [ -f tripleo-image-elements ]; then
    git clone https://github.com/openstack/tripleo-image-elements.git
fi

export ELEMENTS_PATH=tripleo-image-elements/elements:CI-elements

if [[ "$os" == "ubuntu" ]]; then
    export DIB_RELEASE=precise
    diskimage-builder/bin/disk-image-create vm $os heat-cfntools CI-tools -a i386 -o $os-heat-cfntools
else
    diskimage-builder/bin/disk-image-create vm $os heat-cfntools CI-tools -a amd64 -o $os-heat-cfntools
fi
