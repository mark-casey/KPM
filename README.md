# Kolla deployment to PXE-booted bare metal hosts

### Layout of supporting infrastructure
Supporting infrastructure (Kolla deployment host, Canonical's MAAS, private Docker registry, etc.) are run inside Vagrant. While this layout is not targeted specifically to test/dev environments, running these components within Vagrant streamlines setup and maximizes repeatability.

![](layout1.png)

A single bare metal host is deployed with Vagrant, Docker, and Virtualbox (or similar virtualization product for which there is a Vagrant provider [VMware Workstation, libvirt, etc.]). This host will be referred to simply as the SI (supporting infrastructure) host. This is not a Kolla or OpenStack term, and is only used in this repo. No OpenStack services run on the SI host and it does not have to stay online once the deployment is complete (though preserving its data is highly recommended to facilitate using Kolla to run upgrades later, since some things like MAAS's list of enrolled hosts are persistent).

![](layout2.png)

The SI host runs several Vagrant machines, each containing a piece of supporting infrastructure. These Vagrant machines are arranged as follows:
 - Running under Vagrant's virtualbox provider, a virtual machine running MAAS to handle PXE-boot services and IPMI power management
 - Running under Vagrant's docker provider, a container running Docker's registry:2 private registry image
 - Also running under Vagrant's docker provider, a container that acts as Kolla's deployment host

![](layout3.png)

### Physical network
The vlan terminology used here is described in terms of "vlan is untagged for port" and/or "vlan is tagged for port(s)". This terminology is common on many vendor's hardware such as D-Link and Netgear, but has also been seen on some midrange Cisco Business switches. It is assumed that anyone using the (arguably more traditional) access/trunk terminology will translate this reference layout to their environment.

1. A vlan for management network
  - This network has Internet access behind a NAT router
  - Ansible's target addresses are in this network, and Kolla's management VIP is also chosen as an unused IP in this network
  - The MAAS Vagrant guest handles DHCP on this network. Hardware that needs an IP prior to the MAAS guest coming up (this far: the router, the switch, the physical deployment host, the MAAS guest itself) are statically assigned.

2. A vlan for IPMI network.
  - If your hosts have dedicated IPMI NICs, the ports they plug into are untagged on the switch for this network.
  - Other ports are set as tagged for this network as-needed (such as the uplink to the NAT router).
  - DHCP for the IPMI network is provided by the NAT router (the existing test setup runs the DHCP server on a vlan interface added to the router for this network, so you may need more than a SOHO router to do this - Mikrotik RB450G in use here.)


### Installation

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

### Install OSes with MAAS

 - Configure BIOS of all target hosts to boot from the hard disk MAAS will install to, then shut them back down.
 - Add public SSH key to the admin user (or the MAAS user you will be logged in as when deploying) in MAAS interface
 - Enable DHCP and DNS from MAAS on the mgmt interface
 - Start target hosts and choose the "one time boot config/menu" (most hardware has this) to perform a PXE-boot on each target host without making permanent changes to the boot order.
 - In the MAAS interface, you will "Commission", "Acquire", and then "Deploy" the hosts.
   - Commission: Boot a minimal environment to gather information on hardware and add a 'maas' user for IPMI access which will be auto-filled-in on each host's config page.
   - Acquire: Assign the target hosts to this MAAS user.
   - Deploy: Choose to install Ubuntu Wily with the hwe (hardware enablement) kernel option.
 - Tag hosts in MAAS

### Test dynamic inventory from within deployment container



### Deploy
 
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
   # change value of --threads based on CPU of physical host
   kolla-build --base ubuntu --type source --threads 16 --registry "${DPLYR_MGMTNET_IP}":5000 --push
   sed -i -e 's/^#*kolla_base_distro:.*/kolla_base_distro: "ubuntu"/' -e 's/^#*kolla_install_type:.*/kolla_install_type: "source"/' -e 's/^#*kolla_internal_vip_address:.*/kolla_internal_vip_address: "10.101.0.215"/' -e "s/^#*docker_registry:.*/docker_registry: \"${DPLYR_MGMTNET_IP}:5000\"/" /etc/kolla/globals.yml
   mkdir .ssh
   vim .ssh/id_rsa  # paste private key in
   chmod 600 .ssh/id_rsa
   ansible -i /usr/local/share/kolla/ansible/inventory/ansible_maas_dynamic_inventory.py -u ubuntu -m shell -a 'sudo cp .ssh/authorized_keys /root/.ssh/authorized_keys' all
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

