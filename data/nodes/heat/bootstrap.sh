#!/bin/bash

cat > /root/deploy.sh<<EOF
function get_meta {
python -c "import json
with open('/mnt/config/openstack/latest/meta_data.json') as jsonf:
  j = json.loads(jsonf.read())
  if '\$1' in j['meta']:
    print j['meta']['\$1']"
}

function get_classgroup {
python -c "import json
with open('/mnt/config/openstack/latest/meta_data.json') as jsonf:
  j = json.loads(jsonf.read())
  if u'\$1' in j['meta']['class_groups'].split(' '):
    print j['meta']['class_groups']"
}
#mount config drive
mkdir -p /mnt/config
mount /dev/disk/by-label/config-2 /mnt/config

exec > /var/log/cloud-init-output.log 2>&1

# Fix fqdn so puppet apply doesn't give us one on the wrong domain
sed -i 's/\#supersede/supersede/g' /etc/dhcp/dhclient.conf;
sed -i "s/fugue.com home.vix.com/\$(get_meta domain)/g" /etc/dhcp/dhclient.conf;
sed -i 's/domain-name,//g' /etc/dhcp/dhclient.conf
dhclient -r eth0 && dhclient eth0;

ntpdate \$(get_meta initial_ntp)
usermod --password p1fhTXKKhbc0M root

sed -i "s/archive.ubuntu.com/\$(get_meta apt_mirror_ip)/g" /etc/apt/sources.list

for i in 1 2 3
do
  ifconfig -a | grep eth\$i
  if [ \$? -eq 0 ];
    then
      ifconfig eth\$i up
      dhclient eth\$i -v
  fi
done

if [ "\$(get_meta apt_proxy_host)" != "" ]; then
  echo "Acquire::http::Proxy \"http://\$(get_meta apt_proxy_host):\$(get_meta apt_proxy_port)\";" >> /etc/apt/apt.conf.d/proxy
fi

# Facter fqdn will come from DNS unless we do this
echo "127.0.1.1 \$(hostname).\$(get_meta domain) \$(hostname)" >> /etc/hosts
apt-get update
apt-get install -y puppet git rubygems curl python-yaml apache2 socat

chmod a+r /var/log/cloud-init-output.log
ln -s /var/log/cloud-init-output.log /var/www/cloud-init-output.log

if [ "\$(get_meta apt_proxy_host)" != "" ]; then
  echo '#!/bin/bash' > /usr/bin/gitproxy
  echo "_proxy=\$(get_meta apt_proxy_host)"  >> /usr/bin/gitproxy
  echo "_proxyport=\$(get_meta apt_proxy_port)">> /usr/bin/gitproxy
  echo 'exec socat STDIO PROXY:\$_proxy:\$1:\$2,proxyport=\$_proxyport' >> /usr/bin/gitproxy
  chmod a+x /usr/bin/gitproxy
  git config --system core.gitproxy gitproxy
fi

cd /root
git clone -b \$(get_meta installer_branch) \$(get_meta git_protocol)://github.com/\$(get_meta installer_repo)/puppet_openstack_builder.git /root/puppet_openstack_builder
gem install librarian-puppet-simple
export git_protocol=\$(get_meta git_protocol)
export openstack_version=\$(get_meta openstack_version)
librarian-puppet install --verbose --path /etc/puppet/modules --puppetfile=/root/puppet_openstack_builder/Puppetfile

if [ "\$(get_meta custom_module)" != "" ]; then
  rm -rf /etc/puppet/modules/\$(get_meta custom_module)
  git clone -b \$(get_meta custom_branch) https://github.com/\$(get_meta custom_repo)/puppet-\$(get_meta custom_module).git /etc/puppet/modules/\$(get_meta custom_module)
fi

cp -r /root/puppet_openstack_builder/data /etc/puppet
cp -r /root/puppet_openstack_builder/manifests /etc/puppet

python -c "import json
with open('/mnt/config/openstack/latest/meta_data.json') as jsonf:
  j = json.loads(jsonf.read())
  with open('/root/user.yaml', 'w') as f:
    for key,value in j['meta'].items():
        if 'OS_USER_' in key:
            f.write(key[8:] + ': ' + value + '\n')"

python -c "import json
with open('/mnt/config/openstack/latest/meta_data.json') as jsonf:
  j = json.loads(jsonf.read())
  with open('/root/global.yaml', 'w') as f:
    for key,value in j['meta'].items():
        if 'OS_GLOB_' in key:
            f.write(key[8:] + ': ' + value + '\n')"

echo "scenario: \$(get_meta scenario) " > /root/config.yaml

# set hosts entries for all nodes
python -c "import json
with open('/mnt/config/openstack/latest/meta_data.json') as jsonf:
  j = json.loads(jsonf.read())
  with open('/etc/hosts', 'a') as f:
    for key,value in j['meta'].items():
        if 'NODE_' in key:
            f.write(value + '  ' + key[5:] + '.' + j['meta']['domain'] + ' ' + key[5:] + '\n')"


cp /root/config.yaml /etc/puppet/data
cp /root/user.yaml   /etc/puppet/data/hiera_data
cp /root/global.yaml /etc/puppet/data/global_hiera_params/user.yaml
cp -r /root/puppet_openstack_builder/templates /etc/puppet
chmod a+r /etc/puppet/data/config.yaml
chmod a+r /etc/puppet/data/hiera_data/user.yaml
chmod a+r /etc/puppet/data/global_hiera_params/user.yaml

if [ "\$(get_meta apt_proxy_host)" != "" ]; then
  export FACTER_apt_proxy_host="\$(get_meta apt_proxy_host)"
  export FACTER_apt_proxy_port="\$(get_meta apt_proxy_port)"
fi

if [ "\$(get_classgroup build)" != "" ]; then
  # set a fact to indicate we are puppet master
  export FACTER_puppet_run_mode=master
else
  export FACTER_puppet_run_mode=agent
fi

# Install the latest puppet and purge the old puppet
puppet apply /root/puppet_openstack_builder/manifests/setup.pp --certname setup_cert

if [ "\$(get_classgroup build)" != "" ]; then
# Install build server
puppet apply /root/puppet_openstack_builder/manifests/site.pp
puppet plugin download --server build-server.domain.name
fi

if [ "\$(get_meta wait_nodes)" != '' ]; then
  for node in \$(get_meta wait_nodes); do
    until [ \$(curl http://\$node/deploy | grep complete) ]; do
      echo "waited for \$node" >> /root/waiting
      sleep 1
    done
  done
fi

if [ "\$(get_classgroup build)" == "" ]; then
  puppet agent -t --server build-server.\$(get_meta domain)
  puppet agent -t --server build-server.\$(get_meta domain)
fi

echo 'complete' > /var/www/deploy
EOF
bash -x /root/deploy.sh
