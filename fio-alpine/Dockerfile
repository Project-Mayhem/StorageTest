# start with an Alpine base
# Thanks to Dmitry Monakhov dmonakhov@openvz.org
#
from alpine

label version="0.0.3" \
      run="docker run ranada/fio:0.0.3" \
	  source="" \
	  description="fio benchmark container. Results can be sent to Logstash, results will be stored in /data." \
	  purpose="Test storage performance." \
	  parameters="Execution parameters are set via environment variables. The environment variables used include: TEST_END_TIME, ELASTICSEARCH_HOST, ELASTICSEARCH_USER, and ELASTICSEARCH_PASSWORD. These variables are set in the K8S YAML file." \
	  maintainer="" \
	  base-image="Alpine Base Image" \
	  test-source="" \
	  name="fio-alpine test" \
	  build-date="2018-08-06"

# set environment variables
ENV CONTAINER_NAME fio
ENV CONTAINER_VERSION "0.0.1"
ENV HOME_DIR /home/fio
ENV DATA_DIR /data

# Finding what packages Alpine supports:
# https://distrowatch.com/dwres.php?resource=compare-packages&firstlist=nixos&secondlist=alpine&firstversions=0&secondversions=0&showall=yes


# Install build deps + permanent dep: libaio
RUN apk --no-cache add \
    	make \
	alpine-sdk \
	zlib-dev \
	libaio-dev \
	linux-headers \
	coreutils \
	libaio && \
    git clone https://github.com/axboe/fio && \
    cd fio && \
    ./configure && \
    make -j`nproc` && \
    make install && \
    cd .. && \
    rm -rf fio && \
    apk --no-cache del \
    	make \
	alpine-sdk \
	zlib-dev \
	libaio-dev \
	linux-headers \
	coreutils

# create a directory to hold the fio benchmark files
RUN mkdir /home/fio \
	/home/fio/rpms \
	/config \
	/data 

# copy fio config files
COPY config/ /config/

# copy the fio benchmark files to the container
COPY configure-fio.sh /home/fio/
COPY run-fio.sh /home/fio/
COPY keep-alive.sh /home/fio/

# change to the fio directory, prepare to run benchmark
WORKDIR /home/fio

# run the fio benchmark
CMD ["/bin/sh", "/home/fio/configure-fio.sh"]
