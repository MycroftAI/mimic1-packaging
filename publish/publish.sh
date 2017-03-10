#!/usr/bin/env bash

# fail on all errors
set -Ee

TOP=$(cd $(dirname $0)/.. && pwd -L)
BUILD_DIR=${TOP}/build
DIST_DIR=${TOP}/dist
ARCH="$(dpkg --print-architecture)"

if [ "$1" = "-q" ]; then
  QUIET="echo"
fi

# clean
pushd ${TOP}
rm -rf $DIST_DIR/*
rm -rf $BUILD_DIR/*
popd

function _run() {
  if [[ "$QUIET" ]]; then
    echo "$*"
  else
    eval "$@"
  fi
}

MIMIC_SRC=${TOP}/src
rm -Rvf ${MIMIC_SRC}
mkdir -p ${MIMIC_SRC}
pushd ${MIMIC_SRC}
git clone https://github.com/MycroftAI/mimic.git
popd
pushd $MIMIC_SRC/mimic
VERSION="$(basename $(git describe --abbrev=0 --tags) | sed -e 's/v//g')"
git checkout tags/${VERSION}
popd
echo $VERSION
MIMIC_ARTIFACT_BASE="mimic-${ARCH}-${VERSION}"
MIMIC_ARTIFACT_DIR=${BUILD_DIR}/${MIMIC_ARTIFACT_BASE}
MIMIC_SYSTEM_TARGET="/usr/local"
MIMIC_CONFIG_OPTIONS="--with-audio=alsa --enable-shared"
echo $MIMIC_ARTIFACT_BASE

function build_mimic() {
  pushd $MIMIC_SRC/mimic
  ./autogen.sh
  ./configure --prefix=${MIMIC_ARTIFACT_DIR}/${MIMIC_SYSTEM_TARGET} ${MIMIC_CONFIG_OPTIONS}
  make && make install  -j ${nproc} 
}


#wget https://github.com/MycroftAI/mimic/archive/1.0.0.tar.gz

build_mimic

mkdir -p ${TOP}/dist
pushd ${TOP}/build
tar cvzf ${TOP}/dist/${MIMIC_ARTIFACT_BASE}.tar.gz -C ${TOP}/build/${MIMIC_ARTIFACT_BASE} .
popd

function replace() {
  local FILE=$1
  local PATTERN=$2
  local VALUE=$3
  local TMP_FILE="/tmp/$$.replace"
  cat ${FILE} | sed -e "s/${PATTERN}/${VALUE}/g" > ${TMP_FILE}
  mv ${TMP_FILE} ${FILE}
}


DEB_BASE="mimic-${ARCH}_${VERSION}-1"
DEB_DIR=${TOP}/build/${DEB_BASE}
mkdir -p ${DEB_DIR}/DEBIAN
cp -rfv ${TOP}/build/${MIMIC_ARTIFACT_BASE}/* ${DEB_DIR}

echo "Creating debian control file"
# setup control file
CONTROL_FILE=${DEB_DIR}/DEBIAN/control
cp ${TOP}/publish/deb_base/control.template ${CONTROL_FILE}
replace ${CONTROL_FILE} "%%PACKAGE%%" "mimic"
replace ${CONTROL_FILE} "%%VERSION%%" "${VERSION}"
replace ${CONTROL_FILE} "%%ARCHITECTURE%%" "${ARCH}"
replace ${CONTROL_FILE} "%%DESCRIPTION%%" "mimic"
#replace ${CONTROL_FILE} "%%PRE_DEPENDS%%" ""

echo "Creating debian preinst file"
PREINST_FILE=${DEB_DIR}/DEBIAN/preinst
cp ${TOP}/publish/deb_base/preinst.template ${PREINST_FILE}
replace ${PREINST_FILE} "%%INSTALL_USER%%" "mycroft"
chmod 0755 ${PREINST_FILE}

echo "Creating debian postinst file"
POSTINST_FILE=${DEB_DIR}/DEBIAN/postinst
cp ${TOP}/publish/deb_base/postinst.template ${POSTINST_FILE}
replace ${POSTINST_FILE} "%%INSTALL_USER%%" "mycroft"
chmod 0755 ${POSTINST_FILE}

echo "Creating debian prerm file"
PRERM_FILE=${DEB_DIR}/DEBIAN/prerm
cp ${TOP}/publish/deb_base/prerm.template ${PRERM_FILE}
#replace ${PRERM_FILE} "%%INSTALL_USER%%" "mycroft"
chmod 0755 ${PRERM_FILE}

echo "Creating debian postrm file"
POSTRM_FILE=${DEB_DIR}/DEBIAN/postrm
cp ${TOP}/publish/deb_base/postrm.template ${POSTRM_FILE}
replace ${POSTRM_FILE} "%%INSTALL_USER%%" "mycroft"
chmod 0755 ${POSTRM_FILE}


pushd $(dirname ${DEB_DIR})
dpkg-deb --build ${DEB_BASE}
mv *.deb ${TOP}/dist
popd


cd ${TOP}/dist
_run s3cmd -c ${HOME}/.s3cfg.mycroft-artifact-writer sync --acl-public . s3://bootstrap.mycroft.ai/artifacts/apt/${ARCH}/mimic/${VERSION}/
echo ${VERSION} > latest
_run s3cmd -c ${HOME}/.s3cfg.mycroft-artifact-writer put --acl-public ${TOP}/dist/latest s3://bootstrap.mycroft.ai/artifacts/apt/${ARCH}/mimic/
