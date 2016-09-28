#!/usr/bin/bash

# quiet option for s3 upload function
if [ "$1" = "-q" ]; then
  QUIET="echo"
fi

# funtion to run s3cmd
function _run {
  if [[ "$QUIET" ]]; then
    echo "$*"
  else
    eval "$@"
  fi
}

# function to create bdist and sdist from setup.py
function python_package_full {
  local SETUP_PATH=$1
  local SETUP_SCRIPT=$2  # argument to script to act upon
  cp ${SETUP_PATH}/${SETUP_SCRIPT} ${SETUP_PATH}/setup.py # copy SETUP_SCRIPT to setup.py
  pushd ${SETUP_PATH}
  python ${SETUP_PATH}/setup.py clean  # run setup.py clean
  python ${SETUP_PATH}/setup.py bdist_egg # create binary
  python ${SETUP_PATH}/setup.py sdist
  rm ${SETUP_PATH}/setup.py
  popd
}

function python_package_sdist {
  local SETUP_PATH=$1
  local SETUP_SCRIPT=$2  # argument to script to act upon
  cp ${SETUP_SCRIPT} ${SETUP_PATH}/setup.py # copy SETUP_SCRIPT to setup.py
  python ${SETUP_PATH}/setup.py clean  # run setup.py clean
  python ${SETUP_PATH}/setup.py bdist_egg # create binary
  python ${SETUP_PATH}/setup.py sdist
  rm ${SETUP_PATH} setup.py
}

# setup init scripts
function setup_init_script() {
  local NAME=$1
  echo "Creating init script for ${NAME}"
  INIT_SCRIPT=${DEB_DIR}/mycroft-core.${NAME}.init
  cp ${TOP}/*/deb_base/init.template ${INIT_SCRIPT}
  pattern_replace ${INIT_SCRIPT} "%%NAME%%" "${NAME}"
  pattern_replace ${INIT_SCRIPT} "%%DESCRIPTION%%" "${NAME}"
  pattern_replace ${INIT_SCRIPT} "%%COMMAND%%" "\/usr\/local\/bin\/${NAME}"
  pattern_replace ${INIT_SCRIPT} "%%USERNAME%%" "mycroft"
  chmod a+x ${INIT_SCRIPT}
}


function create_source_path {
  local SRC_PATH=$1
  pushd ${TOP}
  if [ ! -d ${SRC_PATH} ]; then
    mkdir -p ${SRC_PATH}
  fi
  popd
}

function remove_source_path {
  local SRC_PATH=$1
  pushd ${TOP}
  rm -Rvf ${SRC_PATH}
  popd
}

function version_date {
  local VERSION_PATH=$1
  VERSION=$(date +%Y%m%d%H%M%S)
  echo "version=\"${VERSION}\"" > ${VERSION_PATH}
}

function version_release {
  local SRC_PATH=$1
  local VERSION_PATH=$2
  pushd ${SRC_PATH}
}

function pattern_replace {
  local FILE=$1
  local PATTERN=$2
  local VALUE=$3
  local TMP_FILE="/tmp/$$.replace"
  cat ${FILE} | sed -e "s/${PATTERN}/${VALUE}/g" > ${TMP_FILE}
  mv ${TMP_FILE} ${FILE}
}

function create_virtualenv {
  local VIRTUALENV_ROOT=$1
  if [ ! -d ${VIRTUALENV_ROOT} ]; then
    mkdir -p $(dirname ${VIRTUALENV_ROOT})
    virtualenv -p python2.7 ${VIRTUALENV_ROOT}
  fi
}

function activate_virtualenv {
 local VIRTUALENV_ROOT=$1
 source ${VIRTUALENV_ROOT}/bin/activate
}

function s3_upload {
  local SRC_DIR=$1
  local S3_PATH=$2
  local S3_VERSION_PATH=$3
  pushd  ${SRC_DIR}/dist
  _run s3cmd -c ${HOME}/.s3cfg.mycroft-artifact-writer sync --acl-public . ${S3_PATH}
  echo ${VERSION} > latest
  _run s3cmd -c ${HOME}/.s3cfg.mycroft-artifact-writer put --acl-public ${S3_VERSION_PATH}
  popd
}

function git_clone_src {
  local PROJECT_NAME=$1
  local SRC_DEST=$2
  local SRC_URL=$3
  local SRC_BRANCH=$4
  pushd ${SRC_DEST}
  git clone ${SRC_URL}
  cd ${PROJECT_NAME}
  git checkout ${SRC_BRANCH}
  VERSION="$(basename $(git describe --abbrev=0 --tags) | sed -e 's/v//g')"
  popd
}

function git_clone_release {
  local PROJECT_NAME=$1
  local SRC_DEST=$2
  local SRC_URL=$3
  pushd ${SRC_DEST}
  git clone ${SRC_URL}
  cd ${SRC_DEST}/${PROJECT_NAME}
  local VERSION="$(basename $(git describe --abbrev=0 --tags) | sed -e 's/v//g')"
  git checkout release/${VERSION}
}



function install_pip {
  local PIP_VERSION=$1
  easy_install pip==${PIP_VERSION} # force version of pip
}

function build_dist_virtualenv {
ARCH="$(dpkg --print-architecture)"
SYSTEM_TARGET="/usr/local/"
ARTIFACT_BASE="mycroft-core-${ARCH}-${VERSION}"
MYCROFT_ARTIFACT_DIR=${MYCROFT_CORE_SRC}/build/${ARTIFACT_BASE}

virtualenv --always-copy --clear ${MYCROFT_ARTIFACT_DIR}
virtualenv --always-copy --clear --relocatable ${MYCROFT_ARTIFACT_DIR}

virtualenv --always-copy --relocatable ${MYCROFT_ARTIFACT_DIR}
}

function create_deb_files {

mkdir -p ${DEB_DIR}

echo "Creating debian copyright file"
COPYRIGHT_FILE=${DEB_DIR}/copyright
cp ${TOP}/publish/deb_base/copyright.template ${COPYRIGHT_FILE}

echo "Creating debian changelog file"
CHANGELOG_FILE=${DEB_DIR}/changelog
#CHANGELOG_FILE=${MYCROFT_CORE_SRC}/changelog
cp ${TOP}/publish/deb_base/changelog.template ${CHANGELOG_FILE}
pattern_replace ${CHANGELOG_FILE} "%%DATE%%" "${DATE}"
pattern_replace ${CHANGELOG_FILE} "%%VERSION%%" "${VERSION}"

echo "Creating debian compat file"
COMPAT_FILE=${DEB_DIR}/compat
echo "9" > ${COMPAT_FILE}

echo "Creating debian rules file"
RULES_FILE=${DEB_DIR}/rules
cp ${TOP}/publish/deb_base/rules.template ${RULES_FILE}

echo "Creating debian control file"
# setup control file
CONTROL_FILE=${DEB_DIR}/control
cp ${TOP}/publish/deb_base/control.template ${CONTROL_FILE}
pattern_replace ${CONTROL_FILE} "%%PACKAGE%%" "mimic"
}
