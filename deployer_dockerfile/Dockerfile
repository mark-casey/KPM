FROM ubuntu:wily

RUN apt-get -q -y update && \
    apt-get -q -y install curl python-pip python-dev gcc inetutils-ping ntp vim wget && \
    curl -sSL https://get.docker.io | bash && \
    pip install -U ansible==1.9.4 oauth && \
    #pip install -U ansible==1.9.4 oauth docker-py && \
    git clone --branch stable/mitaka https://git.openstack.org/openstack/kolla && \
    pip install kolla/ && \
    cp -r kolla/etc/kolla /etc/ && \
    kolla-genpwd && \
    # remove hosts (control01, network02, etc.) since we're using dynamic inventory... but preserve groups
    grep -v 'control[^] -]\|network[^] -]\|compute[^] -]\|storage[^] -]' /usr/local/share/kolla/ansible/inventory/multinode > /usr/local/share/kolla/ansible/inventory/kolla_groups && \
    rm /usr/local/share/kolla/ansible/inventory/all-in-one && \
    rm /usr/local/share/kolla/ansible/inventory/multinode

ADD ansible_maas_dynamic_inventory.py /usr/local/share/kolla/ansible/inventory
ADD .bash_profile /root
ADD pre.yml /root

RUN chmod 755 /usr/local/share/kolla/ansible/inventory/ansible_maas_dynamic_inventory.py

ENTRYPOINT ["/bin/sh", "-c"]
CMD ["bash -l"]
