# -*- mode: ruby -*-
# vi: set ft=ruby :

# Make sure Vagrant is new enough to use the Docker provider...
Vagrant.require_version ">= 1.6.0"

# Declare default vars if not set in ENV already
if ENV['MAASVM_IPMINET_IP']
    maasvm_ipminet_ip = ENV['MAASVM_IPMINET_IP']
    puts "Set MAAS VM's ipmi network IP to '#{maasvm_ipminet_ip}' from ENV var"
else
    maasvm_ipminet_ip = "10.100.10.16"
end

if ENV['MAASVM_MGMTNET_IP']
    maasvm_mgmtnet_ip = ENV['MAASVM_MGMTNET_IP']
    puts "Set MAAS VM's mgmt network IP to '#{maasvm_mgmtnet_ip}' from ENV var"
else
    maasvm_mgmtnet_ip = "10.101.10.16"
end

if ENV['MAASVM_DEFAULTGW_IP']
    maasvm_defaultgw_ip = ENV['MAASVM_DEFAULTGW_IP']
    puts "Set MAAS VM's default gateway IP to '#{maasvm_defaultgw_ip}' from ENV var"
else
    # Assume that MAAS VM's default gateway IP should be first address of the network that management IP is on"
    maasvm_defaultgw_ip = maasvm_mgmtnet_ip.gsub(/\.[0-9]*$/, '.1')
end

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

if ENV['MAAS_ADMIN_PASS']
    if ENV['MAAS_ADMIN_PASS'] != ''
        maas_admin_pass = ENV['MAAS_ADMIN_PASS']
        puts "Set MAAS Region Admin Password from ENV var"
    else
        puts "Error: MAAS_ADMIN_PASS variable cannot be an empty string"
    end
else
    maas_admin_pass = "admin"
end

Vagrant.configure(2) do |config|

    # MAAS VM Vagrant guest
    config.vm.define "kpm-maaspxe", primary: false do |maas|

        # This commit has to land in next Vagrant release before we can use a Xenial box...:
        # https://github.com/mitchellh/vagrant/commit/0505771481222b4893daa5454ff6c9c16f471fa4
        # because of: https://github.com/mitchellh/vagrant/issues/7155
        maas.vm.box = "ubuntu/wily64"
        maas.vm.hostname = "kpm-maaspxe"
        # 'vagrant up' will prompt for interface choice(s) if bridge(s) not set here
        maas.vm.network :public_network, ip: maasvm_ipminet_ip #, bridge: 'Intel(R) Ethernet Connection I217-LM'
        maas.vm.network :public_network, ip: maasvm_mgmtnet_ip #, bridge: 'Intel(R) Ethernet Connection I217-LM'
        #maas.vm.network :forwarded_port, guest: 22, host: 2961, id: "ssh"
        maas.vm.provider "virtualbox" do |vbox|
            vbox.name = "kpm-maaspxe"
            vbox.memory = "4096"
        end

        # move default route to bridged mgmt interface instead of NAT'ed eth0
        maas.vm.provision "shell", run: "always", inline: <<-SHELL

            # remove non-local eth0 route(s)
            eval `route -n | awk '{ if ($8 ==\"eth0\" && $2 != \"0.0.0.0\") print \"route del default gw \" $2; }'`

            route add default gw #{maasvm_defaultgw_ip}
        SHELL

        maas.vm.provision "shell", inline: <<-SHELL
            # set up env (FIXME: need to see if we can get rid of the intermediate ruby var step or otherwise simplify)
            export MAASVM_IPMINET_IP=#{maasvm_ipminet_ip}
            export MAASVM_MGMTNET_IP=#{maasvm_mgmtnet_ip}
            export MAASVM_DEFAULTGW_IP=#{maasvm_defaultgw_ip}
            export MAASVM_API_URL="http://#{maasvm_mgmtnet_ip}:5240/MAAS/api/1.0"
            export MAAS_ADMIN_USER=#{maas_admin_user}
            export MAAS_ADMIN_EMAIL=#{maas_admin_email}
            export MAAS_ADMIN_PASS=#{maas_admin_pass}
            export MAAS_ADD_COREOS="no"
            
            wget https://raw.githubusercontent.com/ropsoft/mass_script/master/setup.bash
            sleep 5
            bash setup.bash
            rm setup.bash

            export MAAS_ADMIN_APIKEY="$(maas-region-admin apikey --username ${MAAS_ADMIN_USER})"
            sed -i "s,_url_find_replace_unique_,${MAASVM_API_URL}," /vagrant/kolla_deployer/ansible_maas_dynamic_inventory.py
            sed -i "s,_token_find_replace_unique_,${MAAS_ADMIN_APIKEY}," /vagrant/kolla_deployer/ansible_maas_dynamic_inventory.py
        SHELL
    end

    # Private Docker registry Vagrant guest
    config.vm.define "kpm-preg", primary: false do |kd_reg|
        kd_reg.vm.provider "docker" do |d1|
            d1.image = "registry:2"
            d1.name = "registry"
            #d1.ports = ["6379:6379", "8080:80"]
            d1.ports = ["5000:5000"]
            #d1.build_dir = "."
            #d1.has_ssh = false
        end
        #config.ssh.port = 22
    end

    config.vm.define "kpm-kolla", primary: false do |deployer|
        deployer.vm.provider "docker" do |d2|
            d2.name="kpm-kolla"
            d2.build_dir = "./kolla_deployer"
            d2.remains_running = false
            #d2.has_ssh = false
            d2.cmd = ["exit"]
        end
    end
end
