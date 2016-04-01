FROM ubuntu:wily

RUN mount --make-shared /run && \
    curl -sSL https://get.docker.io | bash && \
    apt-get -q -y install python-pip python-dev gcc && \
    pip install -U ansible==1.9.4 docker-py && \
    git clone https://git.openstack.org/openstack/kolla && \
    pip install kolla/ && \
    cp -r kolla/etc/kolla /etc/ && \


# 'ARG' seems to be a very new option in Docker and Quay.io's version of Docker is complaining
#ARG path="/var/work"
#ENV path="/var/work"

#RUN mkdir -p $path

#WORKDIR $path

ENTRYPOINT ["/bin/sh", "-c"]

CMD ["bash"]
