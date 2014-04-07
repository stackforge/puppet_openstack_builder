# convert data model to pure hiera
python contrib/aptira/build/convert.py

# install puppet modules
mkdir -p vendor
mkdir -p modules
export GEM_HOME=vendor
gem install librarian-puppet-simple
vendor/bin/librarian-puppet install

# get package caches
rm -rf stacktira
rm -rf stacktira.tar
wget https://bitbucket.org/michaeltchapman/puppet_openstack_builder/downloads/stacktira.tar
tar -xvf stacktira.tar
cp -r stacktira/contrib/aptira/gemcache contrib/aptira
cp -r stacktira/contrib/aptira/packages contrib/aptira

vagrant up control1
