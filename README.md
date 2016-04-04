## "Semi-production" Kolla deploy
with Kolla-specific infra run via Vagrant

# Goals
 - Relatively simple layout
 - Manageability
 - Simple to redeploy

# Software layout
A single server (which will not run OpenStack components) is deployed with Vagrant, Docker, and Virtualbox (or etc.). Each of the following is a separate Vagrant guest using the Docker provider, except MAAS which uses the Virtualbox provider:
 - PXE and IPMI management are handled by Canonical's MAAS
 - Private Docker registry is run from Docker's registry:2 image
 - Kolla's deployment/operator host is also built. (Vagrant starts this container automatically as well, so we simply pass an runtime command of 'exit'.)


# Physical network




 - Install an SSH server on the server then...
```
sudo apt-get -qy update
sudo apt-get -qy install curl

wget https://releases.hashicorp.com/vagrant/1.8.1/vagrant_1.8.1_x86_64.deb
sudo dpkg -i vagrant_1.8.1_x86_64.deb

wget http://download.virtualbox.org/virtualbox/4.3.36/virtualbox-4.3_4.3.36-105129~Ubuntu~raring_amd64.deb
sudo dpkg -i virtualbox-4.3_4.3.36-105129~Ubuntu~raring_amd64.deb
(watch for errors like)...
 virtualbox-4.3 depends on libsdl1.2debian (>= 1.2.11); however:
  Package libsdl1.2debian is not installed.
(then fix with)...
sudo apt-get install libsdl1.2debian

sudo su root -c "curl -sSL https://get.docker.io | bash"
sudo usermod -aG docker luser

(exit and reopen)

git clone https://github.com/ropsoft/kolla_from_vagrant.git
cd kolla_from_vagrant


export MAASVM_IPMINET_IP='10.100.10.16'
export MAASVM_MGMTNET_IP='10.101.10.16'
export #MAASVM_DEFAULTGW_IP='10.101.10.3'  # assumes the '.1' of the management IP if unset
export MAAS_ADMIN_USER='admin'
export MAAS_ADMIN_EMAIL='admin@example.com'
export MAAS_ADMIN_PASS='admin'

vagrant up
```
