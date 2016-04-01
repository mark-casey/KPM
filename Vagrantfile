# -*- mode: ruby -*-
# vi: set ft=ruby :

#
# Tooling to set up OpenStack on bare-metal using Kolla.
#
# Add a link to an image of the physical network layout here and also some explanation
#
#
# This Vagrantfile consists of two Vagrant guest machines and a container image build:
#   - The two Vagrant guests are:
#      - A VM that runs Canonical's MAAS (Metal As A Service) pxe-boot and hardware management platform
#      - A private docker registry container on the Vagrant host.
#
#   - The container image that is built will be used as Kolla's "deployment host"
#

# Make sure Vagrant is new enough to use the Docker provider...
Vagrant.require_version ">= 1.6.0"

# Declare default vars if not set in ENV already
if ENV['MAASVM_IPMINET_IP']
    maasvm_ipminet_ip = ENV['MAASVM_IPMINET_IP']
    puts "Set MAAS VM's ipmi network IP to '#{maasvm_ipminet_ip}' from ENV var"
else
    maasvm_ipminet_ip = "10.100.0.16"
end

if ENV['MAASVM_MGMTNET_IP']
    maasvm_mgmtnet_ip = ENV['MAASVM_MGMTNET_IP']
    puts "Set MAAS VM's mgmt network IP to '#{maasvm_mgmtnet_ip}' from ENV var"
else
    maasvm_mgmtnet_ip = "10.101.0.16"
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
        system('export MAAS_ADMIN_PASS=""')
        puts "Set MAAS Region Admin Password from ENV var (and then cleared the ENV var)"
    else
        puts "Error: MAAS_ADMIN_PASS variable cannot be an empty string"
    end
else
    maas_admin_pass = "admin"
end

Vagrant.configure(2) do |config|

    # MAAS VM Vagrant guest
    config.vm.define "maas", primary: false do |maas|
        maas.vm.box = "ubuntu/trusty64"
        maas.vm.hostname = "maas"
        # 'vagrant up' will prompt for interface choice(s) if bridge(s) not set here
        maas.vm.network :public_network, ip: maasvm_ipminet_ip #, bridge: 'Intel(R) Ethernet Connection I217-LM'
        maas.vm.network :public_network, ip: maasvm_mgmtnet_ip #, bridge: 'Intel(R) Ethernet Connection I217-LM'
        maas.vm.network :forwarded_port, guest: 22, host: 2961, id: "ssh"
        maas.vm.provider "virtualbox" do |vbox|
            vbox.name = "maas"
            vbox.memory = "4096"
        end

        # move default route to bridged mgmt interface instead of NAT'ed eth0
        maas.vm.provision "shell", run: "always", inline: <<-SHELL

            # remove non-local eth0 route(s)
            eval `route -n | awk '{ if ($8 ==\"eth0\" && $2 != \"0.0.0.0\") print \"route del default gw \" $2; }'`

            route add default gw #{maasvm_defaultgw_ip}
        SHELL

        maas.vm.provision "shell", inline: <<-SHELL
            apt-get -qy update
            apt-get -qy install software-properties-common python-software-properties

            add-apt-repository -y ppa:maas/stable
            apt-get -qy update

            # in a Vagrant environment these two values can get set to the IP of the wrong interface
            echo "maas-cluster-controller maas-cluster-controller/maas-url string http://#{maasvm_mgmtnet_ip}/MAAS" | sudo debconf-set-selections
            echo "maas-region-controller-min maas/default-maas-url string #{maasvm_mgmtnet_ip}" | sudo debconf-set-selections
            apt-get -qy install maas
            maas-region-admin createadmin --username=#{maas_admin_user} --email=#{maas_admin_email} --password=#{maas_admin_pass}
        SHELL
    end

    maas_admin_apikey=`ssh -q -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i .vagrant/machines/maas/virtualbox/private_key -p 2961 vagrant@127.0.0.1 sudo maas-region-admin apikey --username #{maas_admin_user}`
    puts '#{maas_admin_apikey}'
    
#  config.vm.provider "docker" do |d|
#    d.build_dir = "."
#  end

    # If MAAS VM is running, run a command against it via Vagrant ssh command to get the MAAS admin's apikey
    #system('if [ $(vagrant status maas | grep "maas.*running (" &>/dev/null) ]; then export MAAS_ADMIN_APIKEY=$(vagrant ssh -c "sudo maas-region-admin apikey --username #{maas_admin_user}" maas 2>&1 | head -n1) && hostname && echo "${MAAS_ADMIN_APIKEY}"; fi')

    # Private Docker registry Vagrant guest
    config.vm.define "kd_reg", primary: true do |kd_reg|
        kd_reg.vm.provider "docker" do |d|
            d.image = "registry:2"
            d.name = "registry"
            #d.ports = ["6379:6379", "8080:80"]
            d.ports = ["5000:5000"]
            #d.build_dir = "."
            #d.has_ssh = false
        end
        #config.ssh.port = 22
    end

    # Prefer Docker provider over virtualbox provider
    config.vm.provider "docker"
    config.vm.provider "virtualbox"
end
