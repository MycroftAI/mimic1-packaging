#!/usr/bin/env bash
# fail on any error
set -Ee
# source common functions
source deb-functions.sh

TOP=$(cd $(dirname $0)/.. && pwd -L)
MIMIC_SRC=${TOP}/src/mimic

remove_source_path $MIMIC_SRC
create_source_path $MIMIC_SRC

git_clone_release "mimic" "${TOP}/src" "https://github.com/MycroftAI/mimic.git"

rm -rf ${MIMIC_SRC}/.git

VERSION="${VERSION}-1ppa1"
DATE=$(date -R)
DEB_DIR=${MIMIC_SRC}/debian

create_deb_files

cd ${MIMIC_SRC}
debuild -us -uc
