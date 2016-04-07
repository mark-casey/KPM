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
    
    sudo su root -c "curl -sSL https://get.docker.io | bash"
    sudo usermod -aG docker user
    sudo sed -i "s/^#DOCKER_OPTS=.*/DOCKER_OPTS='--insecure-registry ${DPLYR_MGMTNET_IP}:5000'/" /etc/default/docker
    sudo service docker restart
    ```

(exit and reopen SSH terminal for docker group changes to take effect)

```
git clone https://github.com/ropsoft/kolla_from_vagrant.git
cd kolla_from_vagrant

vagrant up maas --provider=virtualbox
vagrant up kd_reg --provider=docker
vagrant up deployer --provider=docker

# you can run this command in another terminal to save some time
docker run -it -v /var/run/docker.sock:/var/run/docker.sock da8fdca3cea7 "kolla-build --no-cache --base ubuntu --type source --registry ${DPLYR_MGMTNET_IP}:5000 --push"

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

 - Use MAAS to put an OS on the target hosts and set SSH key, set up IPMI... etc.
     - Begin image import
     - Add SSH key to the user in MAAS interface
     - Enable DHCP and DNS from MAAS on the mgmt interface
     - PXE boot instances

# Things not yet done/tested:
 - add the target hosts to inventory and run kolla-ansible
