FROM ubuntu:wily

ADD ansible_maas_dynamic_inventory.py /usr/local/share/kolla/ansible/inventory

RUN apt-get -q -y update && \
    apt-get -q -y install curl python-pip python-dev gcc inetutils-ping ntp vim && \
    curl -sSL https://get.docker.io | bash && \
    pip install -U ansible==1.9.4 oauth python-openstackclient \
    python-neutronclient python-novaclient && \
    #pip install -U ansible==1.9.4 oauth python-openstackclient \
    #python-neutronclient python-novaclient docker-py && \
    git clone https://git.openstack.org/openstack/kolla && \
    pip install kolla/ && \
    cp -r kolla/etc/kolla /etc/ && \
    kolla-genpwd && \
    chmod 755 /usr/local/share/kolla/ansible/inventory/ansible_maas_dynamic_inventory.py
    #sudo usermod -aG docker your-user

ENTRYPOINT ["/bin/sh", "-c"]

CMD ["bash"]
