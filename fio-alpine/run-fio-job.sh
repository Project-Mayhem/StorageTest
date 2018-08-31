#!/bin/sh
#
# Filename: run-fio-job.sh
#
# Run the fio metric container as a job
#
#set -x

usage() {
	echo "Start one or many jobs based on optional command line arguments supplied"
	echo "usage: $0 [OPTIONS]"
	echo "  -c, --completions <COMPLETIONS>  the number of completions per job."
	echo "  -d, --duration <DURATION>>       the minimum job duration, use Linux date notation."
	echo "                                   The value entered will be added to the time started."
	echo "                                   Examples include \"0 hour\" to run once, \"5 hour\" will"
	echo "                                   run for 5 hours."
	echo "  -j, --jobs <JOBS>                the number of jobs to run."	
	echo "  -n, --namespace <NAMESPACE>      the namespace that should be used for the run."	
	echo "  -s, --sleep <STAY_ALIVE_TIME>    the amount of time to sleep when the job completes to " 
	echo "                                   allow results collection and export."
	echo "                                   Use standard Linux sleep notation. Example: \"2m\" to"
	echo "                                   sleep for 2 minutes, which is the default."
	echo "  -h, --help                       display this help message."
}

# Execution parameters and settings
K8S_NAMESPACE="meadowgate"
NUMBER_OF_JOBS="1"
COMPLETIONS="1"
POD_NAME="fio-job"
JOB_NAME=${POD_NAME}
PERSISTENT_STORAGE_NAME="penguin-ceph-appliance"
PERSISTENT_STORAGE_VERSION="1.0.1"
STARTUP_WAIT="60s"
JOB_START_WAIT="5s"
CONTAINER_AND_VERSION="ranada/fio:0.0.3"
JOB_DURATION="0 hour"   # minimum test duration, use Linux data notation
                        # that will add time to the time the test started
STAY_ALIVE_SLEEP_TIME="5m"  # Stay alive time, default in container is 5 minutes

# fio parameters, add here
FILE_SIZES='500m'
NUM_RUNS='8'

# for posting to pywebsvr
#RESULTS_WEBSERVER="10.50.100.5"

# Process command line arguments
while [ "$1" != "" ]; do
	case $1 in
		-c | --completions )
			shift
			COMPLETIONS=$1
			;;
		-d | --duration )
			shift
			JOB_DURATION=$1
			;;
		-j | --jobs )
			shift
			NUMBER_OF_JOBS=$1
			;;
		-n | --namespace )
			shift
			K8S_NAMESPACE=$1
			;;
		-s | --sleep )
			shift
			STAY_ALIVE_SLEEP_TIME=$1
			;;
		-h | --help )
			usage
			exit 1
	esac
	shift
done

# k8s commands
#KUBECTL="kubectl" # for local minikube on Mac
KUBECTL="oc"      # for main system, recommended by OpenShift

if [ "${KUBECTL}" = "oc" ]
then
	# oc setup to assure running the correct project
	${KUBECTL} project ${K8S_NAMESPACE}
	END_TIME=$(date -ud "+${JOB_DURATION}" "+%m%d%H%M")

else
	# running local minikube on Mac
	${KUBECTL} project default
	END_TIME=$(date -u  "+%m%d%H%M")   # when running on MacOS, -d does not work
fi


# Useful variables
CWD=${PWD}

# Template YAML files
JOB_YAML_TEMPLATE="${CWD}/${JOB_NAME}-template.yml"
PVC_YAML_TEMPLATE="${CWD}/pvc-ceph-template.yml"

# Logstash configuration parameters, Elasticsearch location
#ELASTICSEARCH_HOST="10.50.100.5:9200"  # previously running ES
#ELASTICSEARCH_HOST="172.30.25.208:9200"
#ELASTICSEARCH_HOST="10.50.100.7:9200"   # or .8, .9 - Port can be 30387
#ELASTICSEARCH_HOST="elasticsearch:9200"
ELASTICSEARCH_HOST="10.50.100.7:9211"
ELASTICSEARCH_USER=
ELASTICSEARCH_PASSWORD=
LOGSTASH_DATE=`date -u "+%Y.%m.%d"`
LOGSTASH_INDEX="logstash-fio-${LOGSTASH_DATE}"
#LOGSTASH_INDEX="logstash-fio-test"

# for all jobs to run
for i in `seq 1 ${NUMBER_OF_JOBS}`; do
	JOB_TO_RUN="${JOB_NAME}-$i"
	echo "$i: Job: ${JOB_TO_RUN}; job will run ${COMPLETIONS} time(s)"

	# set PVC parameters
	PVC_NAME="fio-pvc-ceph-$i"
	PVC_YAML="${CWD}/pvc-ceph-$i.yml"

	# delete previous jobs and PVC
	${KUBECTL} delete job ${JOB_TO_RUN}
	${KUBECTL} delete pvc ${PVC_NAME}

	# find the PVC size
	ALLOCATION_FACTOR="2"
	TEST_FILE_SIZE=$(echo ${FILE_SIZES} | sed 's/[^0-9]*//g')
	PVC_SIZE=$((${TEST_FILE_SIZE} * ${ALLOCATION_FACTOR} * ${NUM_RUNS}))
	FILE_SIZE_UNITS=$(echo ${FILE_SIZES} | sed 's/[^a-zA-Z]*//g')
	PVC_UNITS="$(echo ${FILE_SIZE_UNITS} | tr '[:lower:]' '[:upper:]')i"
	PVC_SIZE="${PVC_SIZE}${PVC_UNITS}"
	echo "PVC size set to: ${PVC_SIZE}"

	# create the YAML for the PVC
	cat "${PVC_YAML_TEMPLATE}" \
		| sed "s|__PVC_NAME__|${PVC_NAME}|g" \
		| sed "s|__PVC_SIZE__|${PVC_SIZE}|g" \
		| sed "##/d" \
		> ${PVC_YAML}

	# create new PVC
	echo "Creating claim: ${PVC_NAME}"
	${KUBECTL} create -f ${PVC_YAML}
	
	# the YAML file that will be used to create the job
	JOB_YAML="${CWD}/${JOB_TO_RUN}.yml"

	# Create the YAML for the test job
	cat "${JOB_YAML_TEMPLATE}" \
		| sed "s|__COMPLETIONS__|${COMPLETIONS}|g" \
		| sed "s|__NAMESPACE__|${K8S_NAMESPACE}|g" \
		| sed "s|__CONTAINER_AND_VERSION__|${CONTAINER_AND_VERSION}|g" \
		| sed "s|__TEST_END_TIME__|${END_TIME}|g" \
		| sed "s|__ELASTICSEARCH_HOST__|${ELASTICSEARCH_HOST}|g" \
		| sed "s|__ELASTICSEARCH_USER__|${ELASTICSEARCH_USER}|g" \
		| sed "s|__ELASTICSEARCH_PASSWORD__|${ELASTICSEARCH_PASSWORD}|g" \
		| sed "s|__STAY_ALIVE_SLEEP_TIME__|${STAY_ALIVE_SLEEP_TIME}|g" \
		| sed "s|__LOGSTASH_INDEX__|${LOGSTASH_INDEX}|g" \
		| sed "s|__PERSISTENT_STORAGE_NAME__|${PERSISTENT_STORAGE_NAME}|g" \
		| sed "s|__PERSISTENT_STORAGE_VERSION__|${PERSISTENT_STORAGE_VERSION}|g" \
		| sed "s|__JOB_NAME__|${JOB_TO_RUN}|g" \
		| sed "s|__PVC_NAME__|${PVC_NAME}|g" \
		| sed "s|__RESULTS_WEBSERVER__|${RESULTS_WEBSERVER}|g" \
		| sed "##/d" \
		> ${JOB_YAML}

	# Start the test
	echo "Starting job: ${JOB_TO_RUN}"
	${KUBECTL} create -f ${JOB_YAML}

	# allow the job to start before attempting another job start
	sleep ${JOB_START_WAIT}
done  # end of job creation loop

# wait for all jobs to start
echo "Waiting ${STARTUP_WAIT} for jobs to start"
sleep ${STARTUP_WAIT}

# rethink how to view the running pods as part of this script
# for now get list of running pods

${KUBECTL} get pods -w | grep ${JOB_NAME}

#grep -h "size=" *.fio | sed "s|size=||g" | sed "s|m||g" | awk '{ SUM += $1} END { print SUM }'