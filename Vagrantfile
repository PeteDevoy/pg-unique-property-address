# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
    config.vm.box = "bionic-server-amd64"
    config.vm.box_url = "https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64-vagrant.box"
    config.vm.network :forwarded_port, guest: 5432, host:65432
    config.vm.provision :ansible do |ansible|
        ansible.playbook = 'ansible/playbook.yml'
        ansible.extra_vars = {
            ansible_python_interpreter: "/usr/bin/python3",
        }
    end
    config.vm.provider "virtualbox" do |v|
        v.memory = 2048
    end
end
