## "Semi-production" Kolla deploy
with Kolla-specific infra run via Vagrant

# Jobs/Tasks/Software/Deployment Host layout
A single host (which will not run OpenStack components) is deployed with Vagrant, Docker, and Virtualbox (or similar virtualization product). This document will refer to this host as Kolla's deployment (or operator) host, even though technically the normal jobs performed by that host (plus a few) are really running as Vagrant guests on the host. These are arranged as follows:
 - Running via Vagrant's virtualbox provider:
     - PXE boot services and IPMI power management are handled by Canonical's MAAS
 - Running via Vagrant's docker provider:
     - Private Docker registry is run from Docker's registry:2 image
     - Kolla's deployment/operator host is also built as a container. (Vagrant starts this container automatically [as that is just what it does when it finishes building from a Dockerfile], so we simply pass an overridden runtime command of 'exit'.)



# Physical network

vlans described here are on a d-link switch, which people have described as conceptually odd or backwards in their configuration (though they are still generally interoperable with gear from other brands)

1. A vlan for management network - this is the network you get if you plug into the switch untagged.
  - This network has Internet access behind a NAT router
  - Ansible's target addresses are in this network, and Kolla's management VIP is also chosen from this network
  - The MAAS Vagrant guest handles DHCP on this network. Hardware that needs an IP prior to the MAAS guest coming up (this far: the router, the switch, the physical deployment host, the MAAS guest itself) are statically assigned.

2. A vlan for IPMI network.
  - If your hosts have dedicated IPMI NICs, the ports they plug into are untagged on the switch for this network.
  - Other ports are set as tagged for this network as-needed (such as the uplink to the NAT router).
  - DHCP for the IPMI network is provided by the NAT router (the existing test setup runs the DHCP server on a vlan interface added to the router for this network, so you may need more than a SOHO router to do this - Mikrotik RB450G in use here.)


# Installation

 - Install an SSH server on the deployment host then in an SSH terminal to it...

 - Override any of the optional vars that you do not want to use defaults for

    ```
    export DPLYR_MGMTNET_IP='10.101.10.15'
    export MAASVM_IPMINET_IP='10.100.10.16'
    export MAASVM_MGMTNET_IP='10.101.10.16'
    #export MAASVM_DEFAULTGW_IP='10.101.10.3'  # assumes the '.1' of the management IP if unset
    #export MAAS_ADMIN_USER='admin'
    #export MAAS_ADMIN_EMAIL='admin@example.com'
    #export MAAS_ADMIN_PASS='admin'
    ```

 - Install some overall dependencies, download and install platform-appropriate VBox and Vagrant, fix dependencies, then run Docker's install script

    ```
    sudo apt-get -qy update
    sudo apt-get -qy install curl git vim
    
    wget https://releases.hashicorp.com/vagrant/1.8.1/vagrant_1.8.1_x86_64.deb
    sudo dpkg -i vagrant_1.8.1_x86_64.deb
    
    wget http://download.virtualbox.org/virtualbox/5.0.14/virtualbox-5.0_5.0.14-105127~Ubuntu~wily_amd64.deb
    sudo dpkg -i virtualbox-5.0_5.0.14-105127~Ubuntu~wily_amd64.deb
    
    sudo apt-get install -f
    
    sudo mount / -o remount,nobarrier,noatime,nodiratime
    
    sudo su root -c "curl -sSL https://get.docker.io | bash"
    sudo usermod -aG docker user
    sudo mkdir -p /lib/systemd/system/docker.service.d
    sudo tee /lib/systemd/system/docker.service.d/kolla.conf <<-EOF
    [Service]
    ExecStart=
    ExecStart=/usr/bin/docker daemon -H fd:// --insecure-registry ${DPLYR_MGMTNET_IP}:5000
    MountFlags=
    MountFlags=shared
    EOF
    sudo systemctl daemon-reload
    sudo service docker restart
    ```

(exit and reopen SSH terminal for docker group changes to take effect)
(REMEMBER TO REDEFINE ANY ENV VARS FROM ABOVE THAT ARE LOST AT LOGOUT)

```
git clone https://github.com/ropsoft/kolla_from_vagrant.git
cd kolla_from_vagrant

vagrant up maas --provider=virtualbox
vagrant ssh maas

# workaround for partitioning bug MAAS runs into on NVMe SSDs (https://bugs.launchpad.net/curtin/+bug/1401190)
cat >> ~/b1401190.patch <<EOF
--- /usr/lib/python2.7/dist-packages/curtin/commands/block_meta.py      2016-04-05 23:02:13.158079435 +0000
+++ /usr/lib/python2.7/dist-packages/curtin/commands/block_meta.py.mod  2016-04-05 23:23:13.642104142 +0000
@@ -368,7 +368,12 @@
         partnumber = determine_partition_number(vol.get('id'), storage_config)
         disk_block_path = get_path_to_storage_volume(vol.get('device'),
                                                      storage_config)
-        volume_path = disk_block_path + str(partnumber)
+
+        if disk_block_path == '/dev/nvme0n1':
+            volume_path = disk_block_path + 'p' + str(partnumber)
+        else:
+            volume_path = disk_block_path + str(partnumber)
+
         devsync_vol = os.path.join(disk_block_path)

     elif vol.get('type') == "disk":
EOF

# http://unix.stackexchange.com/questions/167216/how-can-i-apply-a-p0-patch-from-any-working-directory
(cd / && sudo patch -p0) < b1401190.patch

exit #(from 'vagrant ssh maas')
```

# Install OSes with MAAS

 - Configure BIOS of all target hosts to boot from the hard disk MAAS will install to, then shut them back down.
 - Add public SSH key to the admin user (or the MAAS user you will be logged in as when deploying) in MAAS interface
 - Enable DHCP and DNS from MAAS on the mgmt interface
 - Start target hosts and choose the "one time boot config/menu" (most hardware has this) to perform a PXE boot on each target host without making permanent changes to the boot order.
 - In the MAAS interface, you will "Commission", "Acquire", and then "Deploy" the hosts.
   - Commission: Boot a minimal environment to gather information on hardware and add a 'maas' user for IPMI access which will be auto-filled-in on each host's config page.
   - Acquire: Assign the target hosts to this MAAS user.
   - Deploy: Choose to install Ubuntu Wily with the hwe (hardware enablement) kernel option.
 - Tag hosts in MAAS

# Test dynamic inventory from within deployer container



# Deploy
 
 - Run these to bring up containers for docker private reg and deployer
   
   ```
   vagrant up kd_reg --provider=docker
   vagrant up deployer --provider=docker
   # note image ID of built container and use on next line
   docker run -it -e "DPLYR_MGMTNET_IP=${DPLYR_MGMTNET_IP}" -v /var/run/docker.sock:/var/run/docker.sock da8fdca3cea7
   ```
   
 - Run inside deployer after ^^^
   
   ```
   cd
   kolla-genpwd
   kolla-build --base ubuntu --type source --registry "${DPLYR_MGMTNET_IP}":5000 --push
   sed -i -e 's/^#*kolla_base_distro:.*/kolla_base_distro: "ubuntu"/' -e 's/^#*kolla_install_type:.*/kolla_install_type: "source"/' -e 's/^#*kolla_internal_vip_address:.*/kolla_internal_vip_address: "10.101.0.215"/' -e 's/^#*docker_registry:.*/docker_registry: "10.101.0.15:5000"/' /etc/kolla/globals.yml
   mkdir .ssh
   vim .ssh/id_rsa  # paste private key in
   chmod 600 .ssh/id_rsa
   ansible -i /usr/local/share/kolla/ansible/inventory/ansible_maas_dynamic_inventory.py -m shell -a 'cp .ssh/authorized_keys /root/.ssh/authorized_keys' all
   ANSIBLE_SSH_PIPELINING=1 kolla-ansible precheck --inventory /usr/local/share/kolla/ansible/inventory/ansible_maas_dynamic_inventory.py
   ANSIBLE_SSH_PIPELINING=1 kolla-ansible deploy --inventory /usr/local/share/kolla/ansible/inventory/ansible_maas_dynamic_inventory.py
   
   # if failures:
   ansible -i /usr/local/share/kolla/ansible/inventory/ansible_maas_dynamic_inventory.py -m script -a '/kolla/tools/cleanup-containers' all
   
   # goto prechecks ^^^
   
   ```


 - Run kolla-ansible prechecks
 - Run kolla-ansible deploy
 
on deployer container post-deploy:

source /etc/kolla/admin-openrc.sh

pip install -U python-openstackclient python-neutronclient python-novaclient

