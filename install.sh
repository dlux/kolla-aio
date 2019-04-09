# !/bin/bash

# Followed https://docs.openstack.org/kolla-ansible/latest/user/quickstart.html
# Used the development steps.
# Doc lists steps for Deployment or evaluation / Development.

set -o xtrace

curl -OL https://github.com/dlux/InstallScripts/raw/master/common_functions
curl -OL https://github.com/dlux/InstallScripts/raw/master/common_packages
curl -OL https://github.com/dlux/InstallScripts/raw/master/install_docker.sh
chmod +x install_docker.sh

source common_packages

EnsureRoot
UpdatePackageManager

###########################################################################
#############    DEPENDENCIES                                ##############
###########################################################################
echo '---> INSTALL DEPENDENCIES'
curl -Lo- https://bootstrap.pypa.io/get-pip.py | python
yum install -y python-devel libffi-devel gcc openssl-devel libselinux-python
yum install -y vim git
yum groupinstall -y "Development Tools"
pip install ansible

echo '---> ADD ANSIBLE CONFIGURATION'
mkdir -p /etc/ansible
txt="[defaults]\nhost_key_checking=False\npipelining=True\nforks=100"
#txt="$txt\nansible_user=vagrant\nansible_password=vagrant"
echo -e $txt >> /etc/ansible/ansible.cfg

echo '---> INSTALLING KOLLA-ANSIBLE'
# Production:
#pip install kolla-ansible
#cp -r /usr/share/kolla-ansible/etc_examples/kolla /etc/
#cp /usr/share/kolla-ansible/ansible/inventory/* .
#kolla-genpwd

# Development
git clone https://github.com/openstack/kolla
pushd kolla
git checkout stable/rocky
pip install -r requirements.txt
popd
git clone https://github.com/openstack/kolla-ansible
pushd kolla-ansible
git checkout stable/rocky
pip install -r requirements.txt
popd
mkdir -p /etc/kolla
cp -r kolla-ansible/etc/kolla/* /etc/kolla
cp kolla-ansible/ansible/inventory/* .

echo '---> GENERATING KOLLA PASSWORDS'
pushd kolla-ansible/tools
./generate_passwords.py
popd

echo '---> FIXING GLOBALS CONFIGURATION'
pushd /etc/kolla
sed -i '/kolla_base_distro:/a kolla_base_distro: "centos"' globals.yml
sed -i '/kolla_install_type:/a kolla_install_type: "source"' globals.yml
sed -i '/openstack_release:/a openstack_release: "rocky"' globals.yml
kiv='kolla_internal_vip_address:'
sed -i "s/^$kiv/#$kiv/g" globals.yml
sed -i "/$kiv/a $kiv \"172.16.0.15\"" globals.yml
sed -i '/network_interface:/a network_interface: "eth1"' globals.yml
nei='neutron_external_interface:'
sed -i "/$nei/a $nei \"eth0\"" globals.yml
sed -i '/enable_haproxy:/a enable_haproxy: "no"' globals.yml
popd
ansible -i all-in-one all -m ping

echo '---> DEPLOYING'
pushd kolla-ansible/tools
./kolla-ansible -i ../ansible/inventory/all-in-one bootstrap-servers
./kolla-ansible -i ../ansible/inventory/all-in-one prechecks
./kolla-ansible -i ../ansible/inventory/all-in-one deploy
popd
