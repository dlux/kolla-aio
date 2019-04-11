# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.require_version ">= 1.8.4"

Vagrant.configure(2) do |config|
  config.vm.box = 'centos/7'
  config.vm.box_version = '1902.01'
  config.vm.box_check_update = false
  config.vm.hostname = 'kolla-aio'
  config.vm.network :forwarded_port, guest: 80, host: 8080
  # Private openstack management network
  config.vm.network :private_network, ip: '172.16.0.15'
  #config.vm.synced_folder ".", "/opt/shared", type: "nfs"

  config.vm.provider 'virtualbox' do |v|
    # Public - Filtered Provider Network
    v.customize ["modifyvm", :id, "--natnet1", "198.168.0.0/24"]
    v.customize ['modifyvm', :id, '--memory', 1024 * 6 ]
    v.customize ["modifyvm", :id, "--cpus", 2]
  end

  config.vm.provision 'shell' do |s|
    s.path = 'install.sh'
#    s.args = 'http://proxy-server'
  end

end

