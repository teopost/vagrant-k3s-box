Vagrant.configure("2") do |config|
  config.vm.box = "dev-env"
  config.vm.network "forwarded_port", guest: 80, host: 80
  config.vm.network "forwarded_port", guest: 443, host: 443
  config.vm.network "forwarded_port", guest: 6443, host: 6443 

  config.vm.provider "virtualbox" do |vb|
        vb.name = "k3s-vm"
        vb.memory = 8192
        vb.cpus = 2
        vb.customize ["modifyvm", :id, "--graphicscontroller", "vmsvga"]
  end

end
