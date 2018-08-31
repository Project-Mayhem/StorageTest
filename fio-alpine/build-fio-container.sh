#!/bin/sh
#
# Build the fio container
#
# Filename: build-fio-container.sh
#
#set -x

CONTAINER_NAME="fio-alpine"
CONTAINER_IMAGE="0.0.1"
REPO_AND_NAME="falenn/${CONTAINER_NAME}:${CONTAINER_IMAGE}"
ELK_RPM_DIRECTORY="../../elk-rpms"
GENERAL_RPM_DIRECTORY="../../rpms"
LOGSTASH_RPM="logstash-5.6.2.rpm"            # set actual name of rpm file
#ELASTICSEARCH_RPM="elasticsearch.rpm"  # set actual name of rpm file

CWD=`pwd`
CONTAINER_RPM_DIRECTORY="${CWD}/rpms"

# copy the RPMs to the directory where the container will be built
cp ${ELK_RPM_DIRECTORY}/${LOGSTASH_RPM} ${CONTAINER_RPM_DIRECTORY}
cp ${GENERAL_RPM_DIRECTORY}/* ${CONTAINER_RPM_DIRECTORY}

# build the container
docker build -t ${REPO_AND_NAME} .

# delete the RPMs from the Docker build directory
# rm ${CONTAINER_RPM_DIRECTORY}/*.rpm
