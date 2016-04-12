FROM ubuntu:wily

RUN apt-get -q -y update && \
    apt-get -q -y install curl python-pip python-dev gcc inetutils-ping ntp vim && \
    curl -sSL https://get.docker.io | bash && \
    pip install -U ansible==1.9.4 && \
    #pip install -U ansible==1.9.4 docker-py && \
    git clone https://git.openstack.org/openstack/kolla && \
    pip install kolla/ && \
    cp -r kolla/etc/kolla /etc/
    #sudo usermod -aG docker your-user

ENV MAAS_ADMIN_APIKEY="${MAAS_ADMIN_APIKEY}"

#VOLUME /var/run/docker.sock

ENTRYPOINT ["/bin/sh", "-c"]

CMD ["bash"]
