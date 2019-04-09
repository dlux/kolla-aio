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

  config.vm.synced_folder ".", "/vagrant", type: "rsync",
    rsync__exclude: ".git/"

  config.vm.provider 'virtualbox' do |v|
    # Public - Filtered Provider Network
    v.customize ["modifyvm", :id, "--natnet1", "198.168.0.0/24"]
    v.customize ['modifyvm', :id, '--memory', 1024 * 2 ]
    v.customize ["modifyvm", :id, "--cpus", 2]
  end

  if ENV['http_proxy'] != nil and ENV['https_proxy'] != nil and ENV['no_proxy'] != nil
    if not Vagrant.has_plugin?('vagrant-proxyconf')
      system 'vagrant plugin install vagrant-proxyconf'
      raise 'vagrant-proxyconf was installed but it requires to execute again'
    end
    config.proxy.http     = ENV['http_proxy']
    config.proxy.https    = ENV['https_proxy']
    config.proxy.no_proxy = ENV['no_proxy']
  end

  config.vm.provision 'shell' do |s|
    s.path = 'install.sh'
  end

end

