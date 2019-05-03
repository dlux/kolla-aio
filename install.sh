# !/bin/bash

# Followed https://docs.openstack.org/kolla-ansible/latest/user/quickstart.html
# Used the development steps.
# Doc lists steps for Deployment or evaluation / Development.
#
# OPTIONAL - Pass proxy as parameter on position $1

set -o xtrace

pushd /opt
release='rocky'
kolla_ansible_tag='7.1.0'
inventory_file=/opt/all-in-one

# If proxy passed as parameter
[[ -n "$1" ]] && x="-x $1"

curl -OL https://github.com/dlux/InstallScripts/raw/master/common_functions $x
curl -OL https://github.com/dlux/InstallScripts/raw/master/common_packages $x
source common_packages

WriteLog "Deploying conteinarized OpenStack AIO via Kolla-ansible"
WriteLog "Proxy=$1"

if [[ -n "$1" ]]; then
    SetProxy "$1"
    # Add private networks to no_proxy
    sed -i 's/no_proxy=/no_proxy=152.16.0.0\/24,20.20.0.0\/24,/g' .PROXY
    sed -i 's/NO_PROXY=/no_proxy=152.16.0.0\/24,20.20.0.0\/24,/g' .PROXY
    source .PROXY
fi

EnsureRoot
sleep 1
UpdatePackageManager

###########################################################################
#############    DEPENDENCIES                                ##############
###########################################################################
WriteLog '---> INSTALL SYSTEM DEPENDENCIES'
yum install -y python-devel libffi-devel gcc openssl-devel libselinux-python
yum install -y vim git

WriteLog '---> INSTALL PIP DEPENDENCIES'
curl -Lo- https://bootstrap.pypa.io/get-pip.py | python
pip install -U pip
pip install ansible
pip install virtualenv
virtualenv venv

WriteLog '---> INSTALLING KOLLA-ANSIBLE FOR PRODUCTION'
# Version 7.1.0 - rocky
# https://pypi.org/project/kolla-ansible/
# https://releases.openstack.org/teams/kolla.html
pip install "kolla-ansible==$kolla_ansible_tag"
mkdir -p /etc/kolla
cp /usr/share/kolla-ansible/etc_examples/kolla/* /etc/kolla/
cp /usr/share/kolla-ansible/ansible/inventory/* .

WriteLog '---> CONFIGURE ANSIBLE'
mkdir -p /etc/ansible
txt="[defaults]\nhost_key_checking=False\npipelining=True\nforks=100"
echo -e $txt >> /etc/ansible/ansible.cfg

WriteLog '---> PREPARING CONFIGURATION - INVENTORY'
ansible -i $inventory_file all -m ping

WriteLog '---> PREPARING CONFIGURATION - KOLLA PASSWORDS'
kolla-genpwd

WriteLog '---> PREPARING CONFIGURATION - GLOBALS'
pushd /etc/kolla
fg='globals.yml'
sed -i '/kolla_base_distro:/a kolla_base_distro: "centos"' $fg
sed -i '/kolla_install_type:/a kolla_install_type: "source"' $fg
sed -i "/openstack_release:/a openstack_release: \"$release\"" $fg
sed -i '/network_interface:/a network_interface: "eth1"' $fg
sed -i '/neutron_external_interface:/a neutron_external_interface: "eth2"' $fg
#sed -i '/neutron_plugin_agent:/a neutron_plugin_agent: "openvswitch"' $fg
sed -i 's/^kolla_internal_vip_address:/#kolla_internal_vip_address:/g' $fg
sed -i 's/^tempest_/#tempest_/g' $fg
sed -i '/kolla_internal_vip_address:/a \
kolla_internal_vip_address: "152.16.0.5"' $fg
sed -i '/kolla_external_vip_address:/a \
kolla_external_vip_address: "20.20.0.5"' $fg
sed -i '/kolla_external_vip_interface:/a \
kolla_external_vip_interface: "eth0"' $fg
sed -i '/enable_ironic:/a \
enable_ironic: "yes"
enable_ironic_ipxe: "yes"
enable_ironic_neutron_agent: "no"
enable_ironic_pxe_uefi: "yes"' $fg
sed -i '/ironic_dnsmasq_dhcp_range:/a \
ironic_dnsmasq_dhcp_range: "152.16.0.20,152.16.0.30"' $fg
popd

WriteLog '---> DEPLOYING'
kolla-ansible -vvv -i $inventory_file bootstrap-servers | tee 1_bootstrap.log
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
    # Add vagrant user to docker group
    usermod -aG docker vagrant

    systemctl daemon-reload
    systemctl restart docker
    popd
fi
kolla-ansible -vvv -i $inventory_file prechecks | tee 2_prechecks.log
kolla-ansible -vvv -i $inventory_file deploy | tee 3_deploy.log
kolla-ansible -vvv -i $inventory_file check | tee 4_check.log
kolla-ansible -vvv -i $inventory_file post-deploy | tee 5_post_deploy.log

. venv/bin/activate
pip install python-openstackclient python-glanceclient python-neutronclient
source /etc/kolla/admin-openrc.sh
/usr/share/kolla-ansible/init-runonce

# Create ssh vagrant tunnel
# ssh localhost -p 2222 -i .vagrant/machines/default/virtualbox/private_key \
#-l vagrant -L 8889:172.16.0.15:80
# Go to http://localhost:8889 to access horizon

# Connect to docker container to troubleshoot
# Get container name: 'docker ps'
# Connect 'docker exec -it <container_name> /bin/bash'

popd
WriteLog '---> INSTALLATION COMPLETE - See /opt/deploy.log'

