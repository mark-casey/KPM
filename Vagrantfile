# -*- mode: ruby -*-
# vi: set ft=ruby :

if ENV['MAAS_ADMIN_USER']
    maas_admin_user = ENV['MAAS_ADMIN_USER']
    puts "Set MAAS Region Admin Username to '#{maas_admin_user}' from ENV var"
else
    maas_admin_user = "admin"
end

if ENV['MAAS_ADMIN_EMAIL']
    maas_admin_email = ENV['MAAS_ADMIN_EMAIL']
    puts "Set MAAS Region Admin Email to '#{maas_admin_email}' from ENV var"
else
    maas_admin_email = "admin@email.com"
end

if ENV['MAAS_ADMIN_PASS'] and ENV['MAAS_ADMIN_PASS'] != ''
    maas_admin_pass = ENV['MAAS_ADMIN_PASS']
    system('export MAAS_ADMIN_PASS=""')
    puts "Set MAAS Region Admin Password from ENV var (and then cleared the ENV var)"
else
    maas_admin_pass = "admin"
end

Vagrant.configure(2) do |config|
    config.vm.define "maas", primary: true do |maas|
        maas.vm.box = "ubuntu/trusty64"
        maas.vm.hostname = "maas"
        # 'vagrant up' will prompt for interface choice if bridge(s) not set here
        maas.vm.network :public_network, ip: '10.100.0.16' #, bridge: 'Intel(R) Ethernet Connection I217-LM'
        maas.vm.network :public_network, ip: '10.101.0.16' #, bridge: 'Intel(R) Ethernet Connection I217-LM'
        maas.vm.network :private_network, ip: '192.168.56.100'
        #maas.vm.network :forwarded_port, guest: 80, host: 8080
        maas.vm.provider "virtualbox" do |vbox|
            vbox.name = "maas"
            vbox.memory = "2048"
        end
        config.vm.provision "shell", inline: <<-SHELL
            apt-get -qy update
            apt-get -qy install software-properties-common python-software-properties
            add-apt-repository -y ppa:maas/stable
            apt-get -qy update
            apt-get -qy install maas
            maas-region-admin createadmin --username=#{maas_admin_user} --email=#{maas_admin_email} --password=#{maas_admin_pass}
        SHELL
    end
end
