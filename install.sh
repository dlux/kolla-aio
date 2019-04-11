# !/bin/bash

# Followed https://docs.openstack.org/kolla-ansible/latest/user/quickstart.html
# Used the development steps.
# Doc lists steps for Deployment or evaluation / Development.
#
# OPTIONAL - Pass proxy as parameter on position $1

set -o xtrace

pushd /opt
release='rocky'
branch='stable/rocky'

# If proxy passed as parameter
[[ -n "$1" ]] && x="-x $1"

curl -OL https://github.com/dlux/InstallScripts/raw/master/common_functions $x
curl -OL https://github.com/dlux/InstallScripts/raw/master/common_packages $x
source common_packages

WriteLog "Deploying conteinarized OpenStack AIO via Kolla-ansible"
WriteLog "Proxy=$1"

[[ -n "$1" ]] && SetProxy "$1"
EnsureRoot
sleep 1
UpdatePackageManager

###########################################################################
#############    DEPENDENCIES                                ##############
###########################################################################
WriteLog '---> INSTALL DEPENDENCIES'
curl -Lo- https://bootstrap.pypa.io/get-pip.py | python
yum install -y python-devel libffi-devel gcc openssl-devel libselinux-python
yum install -y vim git
yum groupinstall -y "Development Tools"
pip install ansible

WriteLog '---> ADD ANSIBLE CONFIGURATION'
mkdir -p /etc/ansible
txt="[defaults]\nhost_key_checking=False\npipelining=True\nforks=100"
echo -e $txt >> /etc/ansible/ansible.cfg

WriteLog '---> INSTALLING KOLLA-ANSIBLE'
# Production:
#pip install kolla-ansible
#cp -r /usr/share/kolla-ansible/etc_examples/kolla /etc/
#cp /usr/share/kolla-ansible/ansible/inventory/* .
#kolla-genpwd

# Development
git clone https://github.com/openstack/kolla
pushd kolla
git checkout $branch
pip install -r requirements.txt
popd

git clone https://github.com/openstack/kolla-ansible
pushd kolla-ansible
git checkout $branch
pip install -r requirements.txt
popd
mkdir -p /etc/kolla
cp -r kolla-ansible/etc/kolla/* /etc/kolla
cp kolla-ansible/ansible/inventory/* .

WriteLog '---> GENERATING KOLLA PASSWORDS'
pushd kolla-ansible/tools
./generate_passwords.py
popd

WriteLog '---> FIXING GLOBALS CONFIGURATION'
pushd /etc/kolla
sed -i '/kolla_base_distro:/a kolla_base_distro: "centos"' globals.yml
sed -i '/kolla_install_type:/a kolla_install_type: "source"' globals.yml
sed -i "/openstack_release:/a openstack_release: \"$release\"" globals.yml
sed -i '/network_interface:/a network_interface: "eth1"' globals.yml

#nei='neutron_external_interface:'
#sed -i "/$nei/a $nei \"eth2\"" globals.yml

kiv='kolla_internal_vip_address:'
sed -i "s/^$kiv/#$kiv/g" globals.yml
sed -i "/$kiv/a $kiv \"172.16.0.16\"" globals.yml


sed -i '/enable_haproxy:/a enable_haproxy: "no"' globals.yml
popd
ansible -i all-in-one all -m ping

WriteLog '---> DEPLOYING'
pushd kolla-ansible/tools
inventory_file="/opt/all-in-one"

./kolla-ansible -i $inventory_file bootstrap-servers
popd

# Configure proxy on docker
if [[ -f .PROXY ]]; then
    source .PROXY
    mkdir -p /etc/systemd/system/docker.service.d

    pushd /etc/systemd/system/docker.service.d
    WriteLog '---> SETTING PRXY ON DOCKER'
    echo '[Service]' > http-proxy.conf
    echo "Environment=\"HTTP_PROXY=$http_proxy\"" >> http-proxy.conf
    echo '[Service]' > https-proxy.conf
    echo "Environment=\"HTTPS_PROXY=$http_proxy\"" >> https-proxy.conf
    if [[ -n "$no_proxy" ]]; then
        echo '[Service]' > no-proxy.conf
        echo "Environment=\"NO_PROXY=$no_proxy\"" >> no-proxy.conf
    fi
    systemctl daemon-reload
    systemctl restart docker
    popd
fi
pushd kolla-ansible/tools
for action in prechecks deploy check post-deploy; do
    ./kolla-ansible -vvv -i $inventory_file $action | tee $action.log
done
popd

