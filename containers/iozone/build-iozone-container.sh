#!/bin/sh
#
# Build the IOzone container
#
# Filename: build-iozone-container.sh
#
#set -x

#RPM_DIRECTORY="../elk-rpms"
#LOGSTASH_RPM="logstash.rpm"            # set actual name of rpm file
#ELASTICSEARCH_RPM="elasticsearch.rpm"  # set actual name of rpm file

CWD=`pwd`

# copy the RPMs to the directory where the container will be built
#cp ${RPM_DIRECTORY}/${LOGSTASH_RPM} ${CWD}

# build the container
docker build -t ranada/iozone .

# delete the RPMs from the Docker build directory
#rm ${CWD}/${LOGSTASH_RPM}
