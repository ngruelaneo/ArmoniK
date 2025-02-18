#! /bin/bash

BASEDIR=$(dirname "$0")
pushd "${BASEDIR}"
BASEDIR=$(pwd -P)
popd

MODE=""
CLEAN=""
NAMESPACE="armonik"
HOST_PATH=$(realpath "${HOME}/data")
SERVER_NFS_IP=""
SHARED_STORAGE_TYPE="HostPath"
SOURCE_CODES_LOCALHOST_DIR=$(realpath "${BASEDIR}/../../quick-deploy/localhost")
MODIFY_PARAMETERS_SCRIPT=$(realpath "${BASEDIR}/../../../tools/modify_parameters.py")
CONTROL_PLANE_IMAGE="dockerhubaneo/armonik_control"
POLLING_AGENT_IMAGE="dockerhubaneo/armonik_pollingagent"
WORKER_IMAGE="dockerhubaneo/armonik_worker_dll"
METRICS_EXPORTER_IMAGE="dockerhubaneo/armonik_control_metrics"
PARTITION_METRICS_EXPORTER_IMAGE="dockerhubaneo/armonik_control_partition_metrics"
CORE_TAG=None
WORKER_TAG=None
HPA_MAX_COMPUTE_PLANE_REPLICAS=None
HPA_MIN_COMPUTE_PLANE_REPLICAS=None
HPA_IDLE_COMPUTE_PLANE_REPLICAS=None
HPA_MAX_CONTROL_PLANE_REPLICAS=None
HPA_MIN_CONTROL_PLANE_REPLICAS=None
HPA_IDLE_CONTROL_PLANE_REPLICAS=None
INGRESS=None
WITH_TLS=false
WITH_MTLS=false
LOGGING_LEVEL="Information"
COMPUTE_PLANE_HPA_TARGET_VALUE=None
CONTROL_PLANE_HPA_TARGET_VALUE=None
KEDA=""
METRICS_SERVER=""
STORAGE_PARAMETERS_FILE="${SOURCE_CODES_LOCALHOST_DIR}/storage/parameters.tfvars"
MONITORING_PARAMETERS_FILE="${SOURCE_CODES_LOCALHOST_DIR}/monitoring/parameters.tfvars"
ARMONIK_PARAMETERS_FILE="${SOURCE_CODES_LOCALHOST_DIR}/armonik/parameters.tfvars"
KEDA_PARAMETERS_FILE="${SOURCE_CODES_LOCALHOST_DIR}/keda/parameters.tfvars"
METRICS_SERVER_PARAMETERS_FILE="${SOURCE_CODES_LOCALHOST_DIR}/metrics-server/parameters.tfvars"
GENERATED_STORAGE_PARAMETERS_FILE="${BASEDIR}/storage-parameters.tfvars.json"
GENERATED_MONITORING_PARAMETERS_FILE="${BASEDIR}/monitoring-parameters.tfvars.json"
GENERATED_ARMONIK_PARAMETERS_FILE="${BASEDIR}/armonik-parameters.tfvars.json"
GENERATED_KEDA_PARAMETERS_FILE="${BASEDIR}/keda-parameters.tfvars.json"
GENERATED_METRICS_SERVER_PARAMETERS_FILE="${BASEDIR}/metrics-server-parameters.tfvars.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
DRY_RUN="${DRY_RUN:-0}"

# Let shell functions inherit ERR trap.  Same as `set -E'.
set -o errtrace
# Trigger error when expanding unset variables.  Same as `set -u'.
set -o nounset
#  Trap non-normal exit signals: 1/HUP, 2/INT, 3/QUIT, 15/TERM, ERR
#  NOTE1: - 9/KILL cannot be trapped.
#+        - 0/EXIT isn't trapped because:
#+          - with ERR trap defined, trap would be called twice on error
#+          - with ERR trap defined, syntax errors exit with status 0, not 2
#  NOTE2: Setting ERR trap does implicit `set -o errexit' or `set -e'.

trap onexit 1 2 3 15 ERR

#--- onexit() -----------------------------------------------------
#  @param $1 integer  (optional) Exit status.  If not set, use `$?'

function onexit() {
  local exit_status=${1:-$?}
  if [[ $exit_status != 0 ]]; then
    echo -e "${RED}Exiting $0 with $exit_status${NC}"
    exit $exit_status
  fi

}

function execute() {
  echo -e "${GREEN}[EXEC] : $@${NC}"
  err=0
  if [[ $DRY_RUN == 0 ]]; then
    $@
    onexit
  fi
}

function isWSL() {
  if grep -qEi "(Microsoft|WSL)" /proc/version &>/dev/null; then
    return 0
  else
    return 1
  fi
}

function getHostName() {
  sed -nr '0,/127.0.0.1/ s/.*\s+(.*)/\1/p' /etc/hosts
}

# usage
usage() {
  echo "Usage: $0 [option...]" >&2
  echo
  echo "   -m, --mode <Possible options below>"
  cat <<-EOF
  Where --mode should be :
        deploy-storage          : To deploy Storage independently on master machine. Available (Cluster or single node)
        deploy-monitoring       : To deploy monitoring independently on master machine. Available (Cluster or single node)
        deploy-armonik          : To deploy ArmoniK on master machine. Available (Cluster or single node)
        deploy-keda             : To deploy KEDA on master machine. Available (Cluster or single node)
        deploy-metrics-server   : To deploy Metrics server on master machine. Available (Cluster or single node)
        deploy-all              : To deploy Storage, Monitoring and ArmoniK
        redeploy-storage        : To REdeploy storage
        redeploy-monitoring     : To REdeploy monitoring
        redeploy-armonik        : To REdeploy ArmoniK
        redeploy-keda           : To REdeploy KEDA
        redeploy-metrics-server : To REdeploy Metrics server
        redeploy-all            : To REdeploy storage, monitoring and ArmoniK
        destroy-storage         : To destroy storage deployment only
        destroy-monitoring      : To destroy monitoring deployment only
        destroy-armonik         : To destroy Armonik deployment only
        destroy-keda            : To destroy KEDA deployment only
        destroy-metrics-server  : To destroy Metrics server deployment only
        destroy-all             : To destroy all storage, monitoring and ArmoniK in the same command
EOF
  echo "   -n, --namespace <NAMESPACE>"
  echo
  echo "   --host-path <HOST_PATH>"
  echo
  echo "   --nfs-server-ip <SERVER_NFS_IP>"
  echo
  echo "   --shared-storage-type <SHARED_STORAGE_TYPE>"
  cat <<-EOF
  Where --shared-storage-type should be :
        HostPath            : Use in localhost
        NFS                 : Use a NFS server
EOF
  echo
  echo "   --control-plane-image <CONTROL_PLANE_IMAGE>"
  echo
  echo "   --polling-agent-image <POLLING_AGENT_IMAGE>"
  echo
  echo "   --worker-image <WORKER_IMAGE>"
  echo
  echo "   --metrics-exporter-image <METRICS_EXPORTER_IMAGE>"
  echo
  echo "   --partition-metrics-exporter-image <PARTITION_METRICS_EXPORTER_IMAGE>"
  echo
  echo "   --core-tag <CORE_TAG>"
  echo
  echo "   --worker-tag <WORKER_TAG>"
  echo
  echo "   --hpa-min-compute-plane-replicas <HPA_MIN_COMPUTE_PLANE_REPLICAS>"
  echo
  echo "   --hpa-max-compute-plane-replicas <HPA_MAX_COMPUTE_PLANE_REPLICAS>"
  echo
  echo "   --hpa-idle-compute-plane-replicas <HPA_IDLE_COMPUTE_PLANE_REPLICAS>"
  echo
  echo "   --hpa-min-control-plane-replicas <HPA_MIN_CONTROL_PLANE_REPLICAS>"
  echo
  echo "   --hpa-max-control-plane-replicas <HPA_MAX_CONTROL_PLANE_REPLICAS>"
  echo
  echo "   --hpa-idle-control-plane-replicas <HPA_IDLE_CONTROL_PLANE_REPLICAS>"
  echo
  echo "   --logging-level <LOGGING_LEVEL_FOR_ARMONIK>"
  echo
  echo "   --compute-plane-hpa-target-value <TARGET_VALUE_FOR_HPA_OF_COMPUTE_PLANE>"
  echo
  echo "   --control-plane-hpa-target-value <TARGET_VALUE_FOR_HPA_OF_CONTROL_PLANE>"
  echo
  echo "   --without-ingress"
  echo
  echo "   --with-tls"
  echo
  echo "   --with-mtls"
  echo
  echo "   -c, --clean <Possible options below>"
  cat <<-EOF
  Where --clean should be :
        storage        : Clean generated files for storage
        monitoring     : Clean generated files for monitoring
        armonik        : Clean generated files for armonik
        keda           : Clean generated files for keda
        metrics-server : Clean generated files for keda
        all            : Clean all generated
EOF
  exit 1
}

# Set environment variables
set_envvars() {
  export ARMONIK_KUBERNETES_NAMESPACE="${NAMESPACE}"
  export ARMONIK_SHARED_HOST_PATH="${HOST_PATH}"
  export ARMONIK_FILE_STORAGE_FILE="${SHARED_STORAGE_TYPE}"
  export ARMONIK_FILE_SERVER_IP="${SERVER_NFS_IP}"
  export KEDA_KUBERNETES_NAMESPACE="default"
  export METRICS_SERVER_KUBERNETES_NAMESPACE="kube-system"
}

# Create shared storage
create_host_path() {
  STORAGE_TYPE=$(echo "${SHARED_STORAGE_TYPE}" | awk '{print tolower($0)}')
  if [ "${STORAGE_TYPE}" == "hostpath" ]; then
    mkdir -p "${HOST_PATH}"
  fi
}

# Create Kubernetes namespace
create_kubernetes_namespace() {
  cd "${SOURCE_CODES_LOCALHOST_DIR}"
  make create-namespace
}

# Check if KEDA is deployed
check_keda_instance() {
  KEDA=$(kubectl get deploy -A -l app=keda-operator --no-headers=true -o name)
  if [ -z "${KEDA}" ]; then
    echo 0
  else
    echo 1
  fi
}

# Check if Metrics server is deployed
check_metrics_server_instance() {
  METRICS_SERVER=$(kubectl get deploy -A -l k8s-app=metrics-server --no-headers=true -o name)
  if [ -z "${METRICS_SERVER}" ]; then
    echo 0
  else
    echo 1
  fi
}

# Prepare storage parameters
prepare_storage_parameters() {
  STORAGE_TYPE=$(echo "${SHARED_STORAGE_TYPE}" | awk '{print tolower($0)}')
  python3 "${MODIFY_PARAMETERS_SCRIPT}" \
    -kv shared_storage.file_storage_type="${STORAGE_TYPE}" \
    -kv shared_storage.file_server_ip="${SERVER_NFS_IP}" \
    -kv shared_storage.host_path="${HOST_PATH}" \
    "${STORAGE_PARAMETERS_FILE}" \
    "${GENERATED_STORAGE_PARAMETERS_FILE}"
}

# Prepare monitoring parameters
prepare_monitoring_parameters() {
  python3 "${MODIFY_PARAMETERS_SCRIPT}" \
    -kv monitoring.metrics_exporter.image="${METRICS_EXPORTER_IMAGE}" \
    -kv monitoring.metrics_exporter.tag="${CORE_TAG}" \
    -kv monitoring.partition_metrics_exporter.image="${PARTITION_METRICS_EXPORTER_IMAGE}" \
    -kv monitoring.partition_metrics_exporter.tag="${CORE_TAG}" \
    "${MONITORING_PARAMETERS_FILE}" \
    "${GENERATED_MONITORING_PARAMETERS_FILE}"
}

# Prepare armonik parameters
prepare_armonik_parameters() {
  python3 "${MODIFY_PARAMETERS_SCRIPT}" \
    -kv control_plane.image="${CONTROL_PLANE_IMAGE}" \
    -kv control_plane.tag="${CORE_TAG}" \
    -kv control_plane.hpa.min_replica_count="${HPA_MIN_CONTROL_PLANE_REPLICAS}" \
    -kv control_plane.hpa.max_replica_count="${HPA_MAX_CONTROL_PLANE_REPLICAS}" \
    -kv control_plane.hpa.triggers[*].value="${CONTROL_PLANE_HPA_TARGET_VALUE}" \
    -kv compute_plane[default].polling_agent.image="${POLLING_AGENT_IMAGE}" \
    -kv compute_plane[default].polling_agent.tag="${CORE_TAG}" \
    -kv compute_plane[default].worker[*].image="${WORKER_IMAGE}" \
    -kv compute_plane[default].worker[*].tag="${WORKER_TAG}" \
    -kv compute_plane[default].hpa.min_replica_count="${HPA_MIN_COMPUTE_PLANE_REPLICAS}" \
    -kv compute_plane[default].hpa.max_replica_count="${HPA_MAX_COMPUTE_PLANE_REPLICAS}" \
    -kv compute_plane[default].hpa.triggers.threshold="${COMPUTE_PLANE_HPA_TARGET_VALUE}" \
    -kv logging_level="${LOGGING_LEVEL}" \
    -kv ingress="${INGRESS}" \
    -kv ingress.tls="${WITH_TLS}" \
    -kv ingress.mtls="${WITH_MTLS}" \
    "${ARMONIK_PARAMETERS_FILE}" \
    "${GENERATED_ARMONIK_PARAMETERS_FILE}"
}

# Prepare keda parameters
prepare_keda_parameters() {
  python3 "${MODIFY_PARAMETERS_SCRIPT}" \
    "${KEDA_PARAMETERS_FILE}" \
    "${GENERATED_KEDA_PARAMETERS_FILE}"
}

# Prepare metrics server parameters
prepare_metrics_server_parameters() {
  python3 "${MODIFY_PARAMETERS_SCRIPT}" \
    "${METRICS_SERVER_PARAMETERS_FILE}" \
    "${GENERATED_METRICS_SERVER_PARAMETERS_FILE}"
}

# Deploy storage
deploy_storage() {
  # Prepare storage parameters
  prepare_storage_parameters

  # Deploy
  cd "${SOURCE_CODES_LOCALHOST_DIR}"
  make deploy-storage PARAMETERS_FILE="${GENERATED_STORAGE_PARAMETERS_FILE}"
}

# Deploy monitoring
deploy_monitoring() {
  # Prepare monitoring parameters
  prepare_monitoring_parameters

  # Deploy
  cd "${SOURCE_CODES_LOCALHOST_DIR}"
  make deploy-monitoring PARAMETERS_FILE="${GENERATED_MONITORING_PARAMETERS_FILE}"
}

# Deploy ArmoniK
deploy_armonik() {
  # Prepare armonik parameters
  prepare_armonik_parameters

  # Deploy
  cd "${SOURCE_CODES_LOCALHOST_DIR}"
  make deploy-armonik PARAMETERS_FILE="${GENERATED_ARMONIK_PARAMETERS_FILE}"
}

# Deploy KEDA
deploy_keda() {
  if [ $(check_keda_instance) -eq 0 ]; then
    prepare_keda_parameters
    cd "${SOURCE_CODES_LOCALHOST_DIR}"
    echo "Deploying KEDA..."
    make deploy-keda PARAMETERS_FILE="${GENERATED_KEDA_PARAMETERS_FILE}"
  else
    echo "Keda is already deployed"
  fi
}

# Deploy Metrics server
deploy_metrics_server() {
  if [ $(check_metrics_server_instance) -eq 0 ]; then
    prepare_metrics_server_parameters
    cd "${SOURCE_CODES_LOCALHOST_DIR}"
    echo "Deploying Metrics server..."
    make deploy-metrics-server PARAMETERS_FILE="${GENERATED_METRICS_SERVER_PARAMETERS_FILE}"
  else
    echo "Metrics server is already deployed"
  fi
}

# Deploy storage, monitoring and ArmoniK
deploy_all() {
  deploy_metrics_server
  deploy_keda
  deploy_storage
  deploy_monitoring
  deploy_armonik
}

# Destroy storage
destroy_storage() {
  if [ ! -f "${GENERATED_STORAGE_PARAMETERS_FILE}" ]; then
    prepare_storage_parameters
  fi

  cd "${SOURCE_CODES_LOCALHOST_DIR}"
  make destroy-storage PARAMETERS_FILE="${GENERATED_STORAGE_PARAMETERS_FILE}"
}

# Destroy monitoring
destroy_monitoring() {
  if [ ! -f "${GENERATED_MONITORING_PARAMETERS_FILE}" ]; then
    prepare_monitoring_parameters
  fi

  cd "${SOURCE_CODES_LOCALHOST_DIR}"
  make destroy-monitoring PARAMETERS_FILE="${GENERATED_MONITORING_PARAMETERS_FILE}"
}

# Destroy ArmoniK
destroy_armonik() {
  if [ ! -f "${GENERATED_ARMONIK_PARAMETERS_FILE}" ]; then
    prepare_armonik_parameters
  fi

  cd "${SOURCE_CODES_LOCALHOST_DIR}"
  make destroy-armonik PARAMETERS_FILE="${GENERATED_ARMONIK_PARAMETERS_FILE}"
}

# Destroy KEDA
destroy_keda() {
  if [ -z "${KEDA}" ]; then
    if [ ! -f "${GENERATED_KEDA_PARAMETERS_FILE}" ]; then
      prepare_keda_parameters
    fi

    cd "${SOURCE_CODES_LOCALHOST_DIR}"
    make destroy-keda PARAMETERS_FILE="${GENERATED_KEDA_PARAMETERS_FILE}"
  fi
}

# Destroy Metrics server
destroy_metrics_server() {
  if [ -z "${METRICS_SERVER}" ]; then
    if [ ! -f "${GENERATED_METRICS_SERVER_PARAMETERS_FILE}" ]; then
      prepare_metrics_server_parameters
    fi

    cd "${SOURCE_CODES_LOCALHOST_DIR}"
    make destroy-metrics-server PARAMETERS_FILE="${GENERATED_METRICS_SERVER_PARAMETERS_FILE}"
  fi
}

# Destroy storage, monitoring and ArmoniK
destroy_all() {
  destroy_armonik
  destroy_monitoring
  destroy_storage
  destroy_keda
  destroy_metrics_server
}

# Redeploy storage
redeploy_storage() {
  cd "${SOURCE_CODES_LOCALHOST_DIR}"
  destroy_storage
  deploy_storage
}

# Redeploy monitoring
redeploy_monitoring() {
  cd "${SOURCE_CODES_LOCALHOST_DIR}"
  destroy_monitoring
  deploy_monitoring
}

# Redeploy ArmoniK
redeploy_armonik() {
  cd "${SOURCE_CODES_LOCALHOST_DIR}"
  destroy_armonik
  deploy_armonik
}

# Redeploy KEDA
redeploy_keda() {
  cd "${SOURCE_CODES_LOCALHOST_DIR}"
  destroy_keda
  deploy_keda
}

# Redeploy Metrics server
redeploy_metrics_server() {
  cd "${SOURCE_CODES_LOCALHOST_DIR}"
  destroy_metrics_server
  deploy_metrics_server
}

# Redeploy storage, monitoring and ArmoniK
redeploy_all() {
  destroy_all
  deploy_all
}

# Clean storage
clean_storage() {
  cd "${SOURCE_CODES_LOCALHOST_DIR}"
  make clean-storage
  rm -f "${GENERATED_STORAGE_PARAMETERS_FILE}"
}

# Clean monitoring
clean_monitoring() {
  cd "${SOURCE_CODES_LOCALHOST_DIR}"
  make clean-monitoring
  rm -f "${GENERATED_MONITORING_PARAMETERS_FILE}"
}

# Clean ArmoniK
clean_armonik() {
  cd "${SOURCE_CODES_LOCALHOST_DIR}"
  make clean-armonik
  rm -f "${GENERATED_ARMONIK_PARAMETERS_FILE}"
}

# Clean KEDA
clean_keda() {
  cd "${SOURCE_CODES_LOCALHOST_DIR}"
  make clean-keda
  rm -f "${GENERATED_KEDA_PARAMETERS_FILE}"
}
# Clean Metrics server
clean_metrics_server() {
  cd "${SOURCE_CODES_LOCALHOST_DIR}"
  make clean-metrics-server
  rm -f "${GENERATED_METRICS_SERVER_PARAMETERS_FILE}"
}

# Clean storage, monitoring and ArmoniK
clean_all() {
  clean_armonik
  clean_monitoring
  clean_storage
  clean_keda
  clean_metrics_server
}

# Main
function main() {
  for i in "$@"; do
    case $i in
    -h | --help)
      usage
      exit
      shift
      ;;
    -m)
      MODE="$2"
      shift
      shift
      ;;
    --mode)
      MODE="$2"
      shift
      shift
      ;;
    -c)
      CLEAN="$2"
      shift
      shift
      ;;
    --clean)
      CLEAN="$2"
      shift
      shift
      ;;
    --nfs-server-ip)
      SERVER_NFS_IP="$2"
      SHARED_STORAGE_TYPE="NFS"
      shift
      shift
      ;;
    --shared-storage-type)
      SHARED_STORAGE_TYPE="$2"
      shift
      shift
      ;;
    --host-path)
      HOST_PATH=$(realpath "$2")
      shift
      shift
      ;;
    -n)
      NAMESPACE="$2"
      shift
      shift
      ;;
    --namespace)
      NAMESPACE="$2"
      shift
      shift
      ;;
    --control-plane-image)
      CONTROL_PLANE_IMAGE="$2"
      shift
      shift
      ;;
    --polling-agent-image)
      POLLING_AGENT_IMAGE="$2"
      shift
      shift
      ;;
    --worker-image)
      WORKER_IMAGE="$2"
      shift
      shift
      ;;
    --metrics-exporter-image)
      METRICS_EXPORTER_IMAGE="$2"
      shift
      shift
      ;;
    --partition-metrics-exporter-image)
      PARTITION_METRICS_EXPORTER_IMAGE="$2"
      shift
      shift
      ;;
    --core-tag)
      CORE_TAG="$2"
      shift
      shift
      ;;
    --worker-tag)
      WORKER_TAG="$2"
      shift
      shift
      ;;
    --hpa-min-compute-plane-replicas)
      HPA_MIN_COMPUTE_PLANE_REPLICAS="$2"
      shift
      shift
      ;;
    --hpa-max-compute-plane-replicas)
      HPA_MAX_COMPUTE_PLANE_REPLICAS="$2"
      shift
      shift
      ;;
    --hpa-idle-compute-plane-replicas)
      HPA_IDLE_COMPUTE_PLANE_REPLICAS="$2"
      shift
      shift
      ;;
    --hpa-min-control-plane-replicas)
      HPA_MIN_CONTROL_PLANE_REPLICAS="$2"
      shift
      shift
      ;;
    --hpa-max-control-plane-replicas)
      HPA_MAX_CONTROL_PLANE_REPLICAS="$2"
      shift
      shift
      ;;
    --hpa-idle-control-plane-replicas)
      HPA_IDLE_CONTROL_PLANE_REPLICAS="$2"
      shift
      shift
      ;;
    --logging-level)
      LOGGING_LEVEL="$2"
      shift
      shift
      ;;
    --compute-plane-hpa-target-value)
      COMPUTE_PLANE_HPA_TARGET_VALUE="$2"
      shift
      shift
      ;;
    --control-plane-hpa-target-value)
      CONTROL_PLANE_HPA_TARGET_VALUE="$2"
      shift
      shift
      ;;
    --without-ingress)
      INGRESS=null
      shift
      ;;
    --with-tls)
      INGRESS=None
      WITH_TLS=true
      shift
      ;;
    --with-mtls)
      INGRESS=None
      WITH_TLS=true
      WITH_MTLS=true
      shift
      ;;
    --default)
      DEFAULT=YES
      shift # past argument with no value
      ;;
    *)
      # unknown option
      ;;
    esac
  done

  # Clean generated files
  if [ "${CLEAN}" == "storage" ]; then
    clean_storage
    exit
  elif [ "${CLEAN}" == "monitoring" ]; then
    clean_monitoring
    exit
  elif [ "${CLEAN}" == "armonik" ]; then
    clean_armonik
    exit
  elif [ "${CLEAN}" == "keda" ]; then
    clean_kda
    exit
  elif [ "${CLEAN}" == "metrics-server" ]; then
    clean_metrics_server
    exit
  elif [ "${CLEAN}" == "all" ]; then
    clean_all
    exit
  elif [ "${CLEAN}" != "" ]; then
    echo -e "\n${RED}$0 $@ where [ "${CLEAN}" ] is not a correct Mode${NC}\n"
    usage
    exit
  fi

  # Set environment variables
  set_envvars

  # Create shared storage
  create_host_path

  # Create Kubernetes namespace
  create_kubernetes_namespace

  # Manage infra
  if [ -z "${MODE}" ]; then
    usage
    exit
  elif [ "${MODE}" == "deploy-storage" ]; then
    deploy_storage
  elif [ "${MODE}" == "deploy-monitoring" ]; then
    deploy_monitoring
  elif [ "${MODE}" == "deploy-armonik" ]; then
    deploy_armonik
  elif [ "${MODE}" == "deploy-keda" ]; then
    deploy_keda
  elif [ "${MODE}" == "deploy-metrics-server" ]; then
    deploy_metrics_server
  elif [ "${MODE}" == "deploy-all" ]; then
    deploy_all
  elif [ "${MODE}" == "redeploy-storage" ]; then
    redeploy_storage
  elif [ "${MODE}" == "redeploy-monitoring" ]; then
    redeploy_monitoring
  elif [ "${MODE}" == "redeploy-armonik" ]; then
    redeploy_armonik
  elif [ "${MODE}" == "redeploy-keda" ]; then
    redeploy_keda
  elif [ "${MODE}" == "redeploy-metrics-server" ]; then
    redeploy_metrics_server
  elif [ "${MODE}" == "redeploy-all" ]; then
    redeploy_all
  elif [ "${MODE}" == "destroy-storage" ]; then
    destroy_storage
  elif [ "${MODE}" == "destroy-monitoring" ]; then
    destroy_monitoring
  elif [ "${MODE}" == "destroy-armonik" ]; then
    destroy_armonik
  elif [ "${MODE}" == "destroy-keda" ]; then
    destroy_keda
  elif [ "${MODE}" == "destroy-metrics-server" ]; then
    destroy_metrics_server
  elif [ "${MODE}" == "destroy-all" ]; then
    destroy_all
  else
    echo -e "\n${RED}$0 $@ where [ "${MODE}" ] is not a correct Mode${NC}\n"
    usage
    exit
  fi
}

main $@
