# Bring up the control node and then reboot it to ensure
# it has an ip netns capable kernel
vagrant up control1
vagrant halt control1
vagrant up control1
vagrant provision control1

# Bring up compute node
vagrant up compute1

vagrant ssh -c "bash /vagrant/contrib/aptira/tests/$1/test.sh"
