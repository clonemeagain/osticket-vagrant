# -*- mode: ruby -*-
# vi: set ft=ruby :

# Configuration script for a VirtualBox vagrant vm
# Vagrant plugins I use: proxyconf, share, vbguest
# Configure these to your timezone and proxy server:
timezone = 'Australia/Melbourne'
proxy = ''

Vagrant.configure("2") do |config|
    # Every Vagrant development environment requires a box. You can search for
    # boxes at https://atlas.hashicorp.com/search
    # Ubuntu LTS latest version is:
    config.vm.box = "ubuntu/xenial64"
  
    # Specify a name for the vm
    config.vm.define :osTicket do |t|
    end

    # Customize the amount of memory on the VM
    config.vm.provider "virtualbox" do |v|
        v.memory = 2048
    end
    
    # Enable symlinks
    config.vm.provider "virtualbox" do |v|
        v.customize ["setextradata", :id, "VBoxInternal2/SharedFoldersEnableSymlinksCreate/v-root", "1"]
    end
    
    # Specify the sync directory
    config.vm.synced_folder ".","/var/www/html", create: true, type: "virtualbox"

    # Create a forwarded port mapping which allows access to a specific port
    # within the machine from a port on the host machine. In the example below,
    # accessing "localhost:8080" will access port 80 on the guest machine.
    config.vm.network "forwarded_port", guest: 80, host: 8080   # Apache2
    config.vm.hostname = 'osticket-dev'

    # Enable the proxy plugin, if possible use the proxy 
    if Vagrant.has_plugin?("vagrant-proxyconf")
        config.proxy.http     = "http://#{proxy}/"
        config.proxy.https    = "http://#{proxy}/"
        config.proxy.no_proxy = "localhost,127.0.0.1"
    end
  
    # Set the timezone
    config.vm.provision :shell, :inline => "sudo rm /etc/localtime && sudo ln -s /usr/share/zoneinfo/#{timezone} /etc/localtime", run: "always"

    #Ensure the correct shell is loaded for our provisioning script.
    config.ssh.shell = "bash -c 'BASH_ENV=/etc/profile exec bash'"

    # Run the provisioning script.
    config.vm.provision :shell, path:  "provision.sh"
end
