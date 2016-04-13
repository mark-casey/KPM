FROM ubuntu:wily

RUN apt-get -q -y update && \
    apt-get -q -y install curl python-pip python-dev gcc inetutils-ping ntp vim && \
    curl -sSL https://get.docker.io | bash && \
    pip install -U ansible==1.9.4 oauth && \
    #pip install -U ansible==1.9.4 oauth docker-py && \
    git clone https://git.openstack.org/openstack/kolla && \
    pip install kolla/ && \
    cp -r kolla/etc/kolla /etc/
    #sudo usermod -aG docker your-user

ADD ansible_maas_dynamic_inventory.py /root/

ENTRYPOINT ["/bin/sh", "-c"]

CMD ["bash"]
