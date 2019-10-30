# -*- mode: ruby -*-
# vi: set ft=ruby :

# options:
#  'virtualbox'
#  'libvirt'
provider   = ENV['PROVIDER'] ? ENV['PROVIDER'] : 'libvirt'
provider   = provider.to_sym
# virtualbox:
#  - centos/6
#  - centos/7
#  - generic/centos8
#  - 'ubuntu/trusty64'
#  - 'ubuntu/xenial64'
# libvirt
#  - centos/6
#  - centos/7
#  - generic/centos8
#  - generic/ubuntu1404
#  - generic/ubuntu1604
box_ubuntu = ENV['BOX'] ? ENV['BOX'] : 'generic/ubuntu1604'
box_centos = ENV['BOX'] ? ENV['BOX'] : 'generic/centos8'

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.define "centos" do |centos|
    hostname = "patching-centos.localdomain"
    # Box details
    centos.vm.box = box_centos
    centos.vm.hostname = hostname
    centos.vm.network :private_network, ip: "192.168.121.100"
    centos.vm.synced_folder '.', '/vagrant', disabled: true

    # Box Specifications
    if provider == :virtualbox
      centos.vm.provider :virtualbox do |vb|
        vb.name = hostname
        vb.memory = 2048
        vb.cpus = 2
        vb.customize ["modifyvm", :id, "--uartmode1", "disconnected"]
      end
    elsif provider == :libvirt
      centos.vm.provider :libvirt do |lv|
        lv.host = hostname
        lv.memory = 2048
        lv.cpus = 2
        lv.uri = "qemu:///system"
        lv.storage_pool_name = "images"
      end
    else
      raise RuntimeError.new("Unsupported provider: #{provider}")
    end
  end
    
  config.vm.define "ubuntu" do |ubuntu|
    hostname = "patching-ubuntu.localdomain"
    # Box details
    ubuntu.vm.box = box_ubuntu
    # older version so we have some updates
    ubuntu.vm.box_version = '1.9.18'
    ubuntu.vm.hostname = hostname
    ubuntu.vm.network :private_network, ip: "192.168.121.101"
    ubuntu.vm.synced_folder '.', '/vagrant', disabled: true

    # Box Specifications
    if provider == :virtualbox
      ubuntu.vm.provider :virtualbox do |vb|
        vb.name = hostname
        vb.memory = 2048
        vb.cpus = 2
        vb.customize ["modifyvm", :id, "--uartmode1", "disconnected"]
      end
    elsif provider == :libvirt
      ubuntu.vm.provider :libvirt do |lv|
        lv.host = hostname
        lv.memory = 2048
        lv.cpus = 2
        lv.uri = "qemu:///system"
        lv.storage_pool_name = "images"
      end
    else
      raise RuntimeError.new("Unsupported provider: #{provider}")
    end
  end
end
