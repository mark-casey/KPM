FROM ubuntu:wily

RUN apt-get -q -y update && \
    apt-get -q -y install curl python-pip python-dev gcc inetutils-ping ntp vim && \
    curl -sSL https://get.docker.io | bash && \
    pip install -U ansible==1.9.4 oauth && \
    #pip install -U ansible==1.9.4 oauth docker-py && \
    git clone https://git.openstack.org/openstack/kolla && \
    pip install kolla/ && \
    cp -r kolla/etc/kolla /etc/ && \
    kolla-genpwd
    #sudo usermod -aG docker your-user

ADD ansible_maas_dynamic_inventory.py /usr/local/share/kolla/ansible/inventory

RUN chmod 755 /usr/local/share/kolla/ansible/inventory/ansible_maas_dynamic_inventory.py

# temporary unholy Bash hax to get MAAS's randomized hostnames into deployer container's /etc/hosts
# will make a little cleaner later
RUN dynamic_inven_hostnames_and_ips() { /usr/local/share/kolla/ansible/inventory/ansible_maas_dynamic_inventory.py --nodes | grep -E "hostname|ip_address\".+[0-9]{3}[\", ]+$" | sed "N;s/\n//"; } && \
    IFS=$'\n\b'; for hosts_entry in $(dynamic_inven_hostnames_and_ips); do echo "${hosts_entry}" | sed -e 's/hostname":\|ip_address\|[", ]//g' -e 's/:/\t/' | tee -a /etc/additional_static_hosts; done; unset IFS

ADD .bash_profile /root/

ENTRYPOINT ["/bin/sh", "-c"]

CMD ["bash"]
