#! /bin/bash -e

function verlte() {
  [ "$1" = "$(echo -e "$1\n$2" | sort -V | head -n1)" ]
}

function verlt() {
  [ "$1" = "$2" ] && return 1 || verlte $1 $2
}

function exit_trap() {
  result=$?
  if [ "$result" != "0" ]; then
    printf "Failed to install plugin helm drift\n"
  fi
  exit $result
}

function setOSArch() {
    arch=$1

    case "$arch" in
      "aarch64")
      echo "arm64"
      ;;
      *)
      echo $arch
      ;;
    esac
}

function download_plugin() {
  osName=$(uname -s)
  osArch=$(uname -m)

  osArch=$(setOSArch $osArch)

  OUTPUT_BASENAME=helm-drift
  version=$(grep version "$HELM_PLUGIN_DIR/plugin.yaml" | cut -d'"' -f2)

  DOWNLOAD_URL="https://github.com/nikhilsbhat/helm-drift/releases/download/v$version/helm-drift_${version}_${osName}_${osArch}.tar.gz"
  OUTPUT_BASENAME_WITH_POSTFIX="$HELM_PLUGIN_DIR/$OUTPUT_BASENAME.tar.gz"


  echo -e "download url set to ${DOWNLOAD_URL}\n"
  echo -e "artifact name with path ${OUTPUT_BASENAME_WITH_POSTFIX}\n"
  echo -e "downloading ${DOWNLOAD_URL} to ${HELM_PLUGIN_DIR}\n"

  if [ -z "${DOWNLOAD_URL}" ]; then
    echo -e "Unsupported OS / architecture: ${osName}/${osArch}\n"
    exit 1
  fi

  if [[ -n $(command -v curl) ]]; then
    if curl --fail -L "${DOWNLOAD_URL}" -o "${OUTPUT_BASENAME_WITH_POSTFIX}"; then
      echo -e "successfully download the archive proceeding to install\n"
    else
      echo -e "failed while downloading helm archive\n"
      exit 1
    fi
  else
    echo "Need curl"
    exit -1
  fi

}

function install_plugin() {
  local HELM_PLUGIN_ARTIFACT_PATH=${OUTPUT_BASENAME_WITH_POSTFIX}
  local PROJECT_NAME="helm-drift"
  local HELM_PLUGIN_TEMP_PATH="/tmp/$PROJECT_NAME"

  echo -n "HELM_PLUGIN_ARTIFACT_PATH: ${HELM_PLUGIN_ARTIFACT_PATH}"
  rm -rf "${HELM_PLUGIN_TEMP_PATH}"

  echo -e "Preparing to install into ${HELM_PLUGIN_DIR}\n"
  mkdir -p "${HELM_PLUGIN_TEMP_PATH}"
  tar -xvf "${HELM_PLUGIN_ARTIFACT_PATH}" -C "${HELM_PLUGIN_TEMP_PATH}"
  mkdir -p "$HELM_PLUGIN_DIR/bin"
  mv "${HELM_PLUGIN_TEMP_PATH}"/helm-drift "${HELM_PLUGIN_DIR}/bin/helm-drift"
  rm -rf "${HELM_PLUGIN_TEMP_PATH}"
  rm -rf "${HELM_PLUGIN_ARTIFACT_PATH}"
}

function install() {
  echo "Installing helm-drift..."

  download_plugin
  status=$?
  if [ $status -ne 0 ]; then
    echo -e "downloading plugin failed\n"
    exit 1
  fi

  set +e
  install_plugin
  local INSTALL_PLUGIN_STAT=$?
  set -e

  if [ "$INSTALL_PLUGIN_STAT" != "0" ]; then
    echo "installing helm plugin helm-drift failed with error code: ${INSTALL_PLUGIN_STAT}"
    exit 1
  fi

  echo
  echo "helm-drift is installed."
  echo
  "${HELM_PLUGIN_DIR}"/bin/helm-drift -h
  echo
  echo "See https://github.com/nikhilsbhat/helm-drift#readme for more information on getting started."
}

trap "exit_trap" EXIT

install "$@"
