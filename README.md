# Kolla deployment to PXE-booted bare metal hosts

### Layout of supporting infrastructure
Supporting infrastructure (Kolla deployer host, Canonical's MAAS, private Docker registry, etc.) are run inside Vagrant. While this layout is not targeted specifically to test/dev environments, running these components within Vagrant streamlines setup and maximizes repeatability.

![](layout1.png)

A single bare metal host is deployed with Vagrant, Docker, and Virtualbox (or similar virtualization product for which there is a Vagrant provider [VMware Workstation, libvirt, etc.]). This host will be referred to simply as the SI (Supporting Infrastructure) host. This is not a Kolla or OpenStack term, and is only used in this repo. No OpenStack services run on the SI host and it does not have to stay online once the deployment is complete, but preserving its data is highly recommended to facilitate using Kolla to run upgrades later. Some things like MAAS's list of enrolled hosts are persistent and we pass this list as a dynamic inventory for Ansible to use with Kolla.

![](layout2.png)

The SI host runs several Vagrant machines, each containing a piece of supporting infrastructure. These Vagrant machines are arranged as follows:
 - Running under Vagrant's virtualbox provider, a virtual machine (kpm-maas) running MAAS to handle PXE-boot services and IPMI power management
 - Running under Vagrant's docker provider, a container (kpm-preg) running Docker's registry:2 private registry image for Kolla to use
 - Also running under Vagrant's docker provider, a container (kpm-kolla) that acts as Kolla's deployer/operator host, and is where the command to build (build.py / kolla-build) container images for Kolla is run.

![](layout3.png)

### Layout of the physical network
The vlan terminology used here is described in terms of "vlan is untagged for port" and/or "vlan is tagged for port(s)". This terminology is common on many vendor's hardware such as D-Link and Netgear, but has also been seen on some midrange Cisco Business switches. It is assumed that anyone using the (arguably more traditional) access/trunk terminology will translate this reference layout to their environment.

1. A vlan for management network
  - This network has Internet access behind a NAT router.
  - The IP addresses for the hosts in Ansible's inventory are in this network, and Kolla's management VIP is also chosen as an unused IP in this network (config option: 'kolla_internal_vip_address').
  - The MAAS Vagrant guest handles DHCP on this network. Hardware that needs an IP prior to the MAAS guest coming up (this far: the router, the switch, the physical deployment host, the MAAS VM itself) are statically assigned.

![](layout4.png)

2. A vlan for IPMI network.
  - If your hosts have dedicated IPMI NICs, the ports they plug into are untagged on the switch for this network.
  - If your hosts have shared IPMI NICs, the ports they plug into are untagged for the NIC's primary function and the 
  - Other ports are set as tagged for this network as-needed (such as the uplink to the NAT router).
  - DHCP for the IPMI network is provided by the NAT router (the existing test setup runs the DHCP server on a vlan interface added to the router for this network, so you may need more than a SOHO router to do this - Mikrotik RB450G in use here.)

![](layout5.png)

3. External/provider network access
  - At least one NIC on each host is configured to be used for external/provider network access (config option: 'kolla_external_vip_interface').

![](layout6.png)

### SI Host Install

 - Install an OS on the SI (Supporting Infrastructure) host. Ubuntu 15.10 Wily x64 used for creating this document.
   - You should have one NIC connected to the IPMI network with a DHCP address.
   - You should have one NIC connected to the management network with a static IP address, as described above. (10.101.10.15 was used here, with the NAT router located at 10.101.10.1)
   - Install an SSH server on the SI host, then SSH to it on the management interface and continue with the following installs:  
        ```
        # tools
        sudo apt-get -qy update
        sudo apt-get -qy install curl git vim
        
        # install appropriate Vagrant
        wget https://releases.hashicorp.com/vagrant/1.8.1/vagrant_1.8.1_x86_64.deb
        sudo dpkg -i vagrant_1.8.1_x86_64.deb
        
        # fix missing deb package deps (if any) not included by 'dpkg -i'
        sudo apt-get install -f
        
        # install appropriate VirtualBox
        wget http://download.virtualbox.org/virtualbox/5.0.14/virtualbox-5.0_5.0.14-105127~Ubuntu~wily_amd64.deb
        sudo dpkg -i virtualbox-5.0_5.0.14-105127~Ubuntu~wily_amd64.deb
        
        # fix missing deb package deps (if any) not included by 'dpkg -i'
        sudo apt-get install -f
        
        # make Kolla build images and deploy faster
        # DO NOT USE THIS (the nobarrier flag) IN PRODUCTION UNLESS YOU HAVE
        # THE EQUIPMENT AND KNOW HOW TO MAKE IT "SAFE" (OR WANT TO LOSE
        # DATA ON WHEN THERE IS A POWER OUTAGE)
        sudo mount / -o remount,nobarrier,noatime,nodiratime
        
        # run Docker's installer
        sudo su root -c "curl -sSL https://get.docker.io | bash"
        
        #sudo usermod -aG docker USER_CHOSEN_AT_OS_INSTALL_GOES_HERE
        ```

 - Log out and log back in for docker group changes to take effect

 - Set/override vars. These are primarily scoped to this repo and used in its Vagrantfile. They are used in configuring MAAS and $DPLYR_MGMTNET_IP, for example, is passed in to the kpm-kolla container and used as the docker registry push target when building container images with Kolla. While you may need to set these again for some things (perhaps you removed the kpm-kolla container and need to recreate it to rebuild container images and run a 'kolla-ansible upgrade'), these are NOT directly referenced in day-to-day cloud operation.  
    ```
    export DPLYR_MGMTNET_IP='10.101.10.15'  # the SI host
    export MAASVM_IPMINET_IP='10.100.10.16'  # the MAAS VM's IP on the IPMI network
    export MAASVM_MGMTNET_IP='10.101.10.16'  # the MAAS VM's IP on the management network
    #export MAASVM_DEFAULTGW_IP='10.101.10.3'  # assumes the '.1' of the management IP if not defined
    #export MAAS_ADMIN_USER='admin'
    #export MAAS_ADMIN_EMAIL='admin@example.com'
    #export MAAS_ADMIN_PASS='admin'
    ```

 - Check out repo and bring up kpm-maas  
    ```
    git clone https://github.com/ropsoft/KPM.git && cd KPM
    vagrant up kpm-maas --provider=virtualbox
    ```

### Finish configuring MAAS

 - Add public SSH key to the user you will be logged into MAAS as when deploying (presumably $MAAS_ADMIN_USER).
     - Recent MAAS 2.0 beta releases seem to be missing the Add SSH Key button in the web UI. See https://github.com/ropsoft/mass_script/blob/master/setup.bash for commands to recreate CLI login to MAAS, and then add key with:
       ```maas "${MAAS_ADMIN_USER}" sshkeys create key="ssh-rsa AAAAB3N... your_key_comment"```
 - Enable DHCP and DNS from MAAS on the mgmt interface:
     - Recent MAAS 2.0 beta releases have this under "Take action" at the top left on the page found by clicking to config the VLAN assigned to the fabric of the desired interface/subnet.

### Install OSes with MAAS

 - Configure the BIOS of all target hosts to boot from the hard disk the OS will be installed to, then shut the hosts down.
 - Start target hosts and use the "one time boot config/menu" (most hardware has this) to perform a PXE-boot on each target host without making permanent changes to the boot order. If this is not an option you may have to set the boot order to network and then change it back to hard disk after the hosts are deployed. This is because some hosts will hang at grub when booting after deployment if they PXE boot and then get redirected to boot from disk.
 - Once the nodes appear in the MAAS interface, you will "Commission", "Acquire", and then "Deploy" them.
   - Commission: Boot a minimal environment to gather information on hardware and add a 'maas' user for IPMI access which will be auto-filled-in on each host's config page.
   - Acquire: Assign the target hosts to this MAAS user.
   - If installing with coreos-install, follow those instructions then skip the Deploy stage below and continue with tagging hosts.
   - Deploy: Choose to install Ubuntu Wily with the hwe (hardware enablement) kernel option.
 - Tag hosts in MAAS

### Test dynamic inventory from within deployment container



### Deploy
 
 - Run these to bring up containers for docker private reg and deployer
   
   ```
   vagrant up kpm-preg --provider=docker
   vagrant up kpm-kolla --provider=docker
   # note image ID of built container and use on next line
   docker run -it -e "DPLYR_MGMTNET_IP=${DPLYR_MGMTNET_IP}" -v /var/run/docker.sock:/var/run/docker.sock da8fdca3cea7
   ```
   
 - Run inside deployer after ^^^
   
   ```
   cd
   kolla-genpwd
   # change value of --threads based on CPU of physical host
   kolla-build --base ubuntu --type source --threads 16 --registry "${DPLYR_MGMTNET_IP}":5000 --push
   sed -i -e 's/^#*kolla_base_distro:.*/kolla_base_distro: "ubuntu"/' -e 's/^#*kolla_install_type:.*/kolla_install_type: "source"/' -e 's/^#*kolla_internal_vip_address:.*/kolla_internal_vip_address: "10.101.0.215"/' -e "s/^#*docker_registry:.*/docker_registry: \"${DPLYR_MGMTNET_IP}:5000\"/" /etc/kolla/globals.yml
   mkdir .ssh
   vim .ssh/id_rsa  # paste private key in
   chmod 600 .ssh/id_rsa
   #ansible -i /usr/local/share/kolla/ansible/inventory/ansible_maas_dynamic_inventory.py -u ubuntu -m shell -a 'sudo cp .ssh/authorized_keys /root/.ssh/authorized_keys' all
   ANSIBLE_SSH_PIPELINING=1 ansible-playbook -i /usr/local/share/kolla/ansible/inventory/ pre.yml
   ANSIBLE_SSH_PIPELINING=1 kolla-ansible prechecks --inventory /usr/local/share/kolla/ansible/inventory/
   ANSIBLE_SSH_PIPELINING=1 kolla-ansible deploy --inventory /usr/local/share/kolla/ansible/inventory/
   ANSIBLE_SSH_PIPELINING=1 kolla-ansible post-deploy --inventory /usr/local/share/kolla/ansible/inventory/
   source /etc/kolla/admin-openrc.sh
   # installing stuff like this and docker-py on ubuntu seems to break pip so I defer it to last
   pip install -U python-openstackclient python-neutronclient python-novaclient

   # if failures:
   ansible -i /usr/local/share/kolla/ansible/inventory/ -m script -a '/kolla/tools/cleanup-containers' all
   
   # goto prechecks ^^^
   
   ```

