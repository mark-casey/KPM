FROM ubuntu:wily

RUN ls && \
    apt-get -q -y install curl python-pip python-dev gcc && \
    curl -sSL https://get.docker.io | bash && \
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
