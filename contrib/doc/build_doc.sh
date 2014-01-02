# This is a short script that can be used to create RDoc documentation
# for all modules used by puppet_openstack_builder
#
# Only tested on Ubuntu 12.04
#
# Usage: 
# git clone https://github.com/stackforge/puppet_openstack_builder
# cd puppet_openstack_builder
# sudo bash contrib/doc/build_doc.sh
#
apt-get install -y git rubygems ruby

mkdir vendor
export GEM_HOME=`pwd`/vendor
gem install thor --no-ri --no-rdoc
gem install puppet --no-ri --no-rdoc
git clone git://github.com/bodepd/librarian-puppet-simple vendor/librarian-puppet-simple
export PATH=`pwd`/vendor/librarian-puppet-simple/bin/:$PATH

librarian-puppet install --verbose

rm -r modules/*/tests
rm -r modules/*/examples
rm modules/augeas/spec/fixtures/manifests/site.pp

mkdir build

vendor/bin/puppet doc --mode rdoc --outputdir build/doc --modulepath modules
