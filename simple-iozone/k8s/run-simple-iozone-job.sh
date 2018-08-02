#!/bin/sh
#
# Filename: run-simple-iozone-job.sh
#
# Run the simple IOzone metric container as a job
#
#set -x


# k8s commands
KUBECTL="kubectl" # for local minikube on Mac
#KUBECTL="oc"      # for main system, recommended by OpenShift
K8S_NAMESPACE="default"

if [ "${KUBECTL}" = "oc" ]
then
	# oc setup to assure running the correct project
	${KUBECTL} project ${K8S_NAMESPACE}
else
	# running local minikube
	${KUBECTL} project default
fi

# Useful variables
CWD=${PWD}
STARTUP_WAIT="60s"

# PVC
PVC_YAML="simple-iozone-gpfs.yml"
PVC_NAME="simple-iozone-pvc-gpfs"

# Job
JOB_YAML="simple-iozone-job.yml"
JOB_NAME="simple-iozone-job"

# delete the previous PVC and create a new PVC
echo "Deleting PVC"
${KUBECTL} delete pvc ${PVC_NAME}
echo "Creating PVC"
${KUBECTL} create -f ${PVC_YAML}

# delete the previous Job and create a new Job
echo "Deleting Job"
${KUBECTL} delete job ${JOB_NAME}
echo "Creating Job"
${KUBECTL} create -f ${JOB_YAML}

# wait for the job to start
echo "Waiting ${STARTUP_WAIT} for jobs to start"
sleep ${STARTUP_WAIT}

# show the running pod
POD_NAME=$(${KUBECTL} get pods | grep ${JOB_NAME} | grep "Running" | awk '{print $1}')
${KUBECTL} logs ${POD_NAME} -f
