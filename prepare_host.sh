#!/bin/bash

set -o xtrace

# Prepare host to run this AIO on a VM
# Install Vagrant plus [Libvirt or Virtualbox]

WriteLog (){
    echo -e "$1"  >> /var/log/kolla_host_preparation.log
    [[ $NOISY == 1 || -n "$2" ]] && echo -e "$1"
}

PrintError (){
    WriteLog "ERROR: $1" true
    exit 1
}

InstallVagrant (){
    WriteLog "Installing Vagrant"
    vagrant_version="${1:-2.2.4}"
    echo "Installing Vagrant $vagrant_version"
    wget -q https://releases.hashicorp.com/vagrant/$vagrant_version/vagrant_${vagrant_version}_x86_64.rpm
    yum install -y vagrant_${vagrant_version}_x86_64.rpm
    rm vagrant_${vagrant_version}_x86_64.rpm
}

InstallVirtualBox (){
    WriteLog "Installing VirtualBox"
    wget -q http://download.virtualbox.org/virtualbox/rpm/rhel/virtualbox.repo -P /etc/yum.repos.d
    yum install -y --enablerepo=epel dkms
    wget -q https://www.virtualbox.org/download/oracle_vbox.asc -O- | rpm --import -
    yum install -y VirtualBox-5.1
}

InstallLibvirt (){
    WriteLog "Installing Libvirt"
    yum install -y qemu libvirt libvirt-devel ruby-devel gcc qemu-kvm nfs-utils nfs-utils-lib
}

Selinux2Permissive (){
    # Set selinux as permissive
    WriteLog 'Setting selinux from enforcing to permissive'
    if [[ $(getenforce) == "Enforcing" ]]; then
        setenforce 0
        sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
        WriteLog "$(sestatus)"
    fi
}

EnsureRoot (){
    if [ "$EUID" -ne "0" ]; then
        PrintError "This script must be run as root."
    fi
}

UpdatePackageManager (){
    WriteLog "Updating yum repos"
    yum clean expire-cache
    yum check-update
    yum -y update
}

InstallPip (){
    if ! which pip; then
        curl -sL https://bootstrap.pypa.io/get-pip.py | python
    fi

    pip install --upgrade pip
}

InstallCommon (){
    yum install -y gdisk vim tree screen cifs-utils curl wget python-devel
    # disable firewalld
    systemctl stop firewalld
    systemctl disable firewalld
}

############################# MAIN FLOW ########################

EnsureRoot
UpdatePackageManager
Selinux2Permissive
InstallCommon
InstallPip
InstallVagrant
InstallLibvirt
#InstallVirtualBox

