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
    config.vm.define "maas", primary: false do |maas|
        maas.vm.box = "ubuntu/wily64"
        maas.vm.hostname = "maas"
        # 'vagrant up' will prompt for interface choice(s) if bridge(s) not set here
        maas.vm.network :public_network, ip: maasvm_ipminet_ip #, bridge: 'Intel(R) Ethernet Connection I217-LM'
        maas.vm.network :public_network, ip: maasvm_mgmtnet_ip #, bridge: 'Intel(R) Ethernet Connection I217-LM'
        #maas.vm.network :forwarded_port, guest: 22, host: 2961, id: "ssh"
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
            # set up env (FIXME: need to see if we can get rid of the intermediate ruby var step or otherwise simplify)
            MAASVM_IPMINET_IP=#{maasvm_ipminet_ip}
            MAASVM_MGMTNET_IP=#{maasvm_mgmtnet_ip}
            MAASVM_DEFAULTGW_IP=#{maasvm_defaultgw_ip}
            MAASVM_API_URL="http://#{maasvm_mgmtnet_ip}:5240/MAAS/api/1.0"
            MAAS_ADMIN_USER=#{maas_admin_user}
            MAAS_ADMIN_EMAIL=#{maas_admin_email}
            MAAS_ADMIN_PASS=#{maas_admin_pass}
            
            apt-get -qy update
            apt-get -qy install software-properties-common python-software-properties

            add-apt-repository -y ppa:maas/stable
            apt-get -qy update

            # in a Vagrant environment these two values can get set to the IP of the wrong interface
            echo "maas-cluster-controller maas-cluster-controller/maas-url string http://${MAASVM_MGMTNET_IP}/MAAS" | sudo debconf-set-selections
            echo "maas-region-controller-min maas/default-maas-url string ${MAASVM_MGMTNET_IP}" | sudo debconf-set-selections
            apt-get -qy install maas

            # calls to sleep from here on are to keep from moving faster than MAAS will keep up
            maas-region-admin createadmin --username=${MAAS_ADMIN_USER} --email=${MAAS_ADMIN_EMAIL} --password=${MAAS_ADMIN_PASS}
            sleep 2
            MAAS_ADMIN_APIKEY="$(maas-region-admin apikey --username ${MAAS_ADMIN_USER})"

            sleep 2
            maas login "${MAAS_ADMIN_USER}" "${MAASVM_API_URL}" "${MAAS_ADMIN_APIKEY}"
            sleep 3
            maas "${MAAS_ADMIN_USER}" boot-source-selections create 1 os="ubuntu" release="wily" arches="amd64" subarches="*" labels="*"
            sleep 2
            maas "${MAAS_ADMIN_USER}" boot-resources import

            sed -i "s,_url_find_replace_unique_,${MAASVM_API_URL}," /vagrant/deployer_dockerfile/ansible_maas_dynamic_inventory.py
            sed -i "s,_token_find_replace_unique_,${MAAS_ADMIN_APIKEY}," /vagrant/deployer_dockerfile/ansible_maas_dynamic_inventory.py

            #exit 0  # comment this out to let the next section run

            ### CentOS images in MAAS
            # April 15, 2016:
            #  - maas-image-builder compiles using the steps here which work around issue(s).
            #  - maas-image-builder project seems a little neglected at this time (hoping
            #    there is a replacement coming or something).
            #  - I had to create virbr0 and eth2 to it using virsh to get the call to
            #    maas-image-builder to make much progress.
            #  - The installer had booted and made real progress before it seemed to get unhappy.
            #  - I killed the installer/VM when it ran into issues; the fact I was trying to
            #    build the image using QEUM inside a VBox may have been causing several issues.
            #
            apt-get -qy install bzr make python-virtualenv python-pip
            bzr -Ossl.cert_reqs=none branch lp:maas-image-builder
            # 'python-stevedore' is the name of the apt package, not the Py package (https://code.launchpad.net/~ti-mo/maas-image-builder/maas-image-builder/+merge/278773 )
            sed -i "s,python-stevedore,stevedore," maas-image-builder/setup.py
            pip install maas-image-builder/
            # AppArmor doesn't allow qemu to access /tmp, so /var/lib/libvirt/images/<temppath> is chosen instead (https://code.launchpad.net/~ti-mo/maas-image-builder/maas-image-builder/+merge/278773 )
            sed -i "s,\(tempdir.*\)location=None,\1location=b'/var/lib/libvirt/images'," /usr/local/lib/python2.7/dist-packages/mib/utils.py
            cd maas-image-builder/ && make install-dependencies && cd -
            #maas-image-builder -a amd64 -o centos7-amd64-root-tgz centos --edition 7
            sleep 2
            #maas "${MAAS_ADMIN_USER}" boot-resources create name=centos/centos7 architecture=amd64/generic content@=./build-output/centos7-amd64-root-tgz

        SHELL
    end

    # Private Docker registry Vagrant guest
    config.vm.define "kd_reg", primary: false do |kd_reg|
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

    config.vm.define "deployer", primary: false do |deployer|
        deployer.vm.provider "docker" do |d2|
            d2.build_dir = "./deployer_dockerfile"
            d2.remains_running = false
            #d2.has_ssh = false
            d2.cmd = ["exit"]
        end
    end
end
