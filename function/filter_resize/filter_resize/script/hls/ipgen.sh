#!/bin/bash

#=================================================
# Copyright 2024 NTT Corporation, FUJITSU LIMITED
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

KRNL_NAME=$1
KRNL_VERSION=$2

if [ -z "${KRNL_NAME}" ]; then
  echo "ERROR: KRNL_NAME not specified."
  exit 1
fi

if [ -z "${KRNL_VERSION}" ]; then
  echo "ERROR: KRNL_VERSION not specified."
  exit 1
fi

echo "KRNL_VERSION=${KRNL_VERSION}"
echo "KRNL_NAME   =${KRNL_NAME}"

TEMPLATE_TCL=./ipgen_template.tcl
TEMP_TCL=./tmp.${KRNL_NAME}.tcl

set -eux

cp -- "${TEMPLATE_TCL}" "${TEMP_TCL}"
sed -i "${TEMP_TCL}" -e "s/__KRNL_NAME__/${KRNL_NAME}/g"
sed -i "${TEMP_TCL}" -e "s/__KRNL_VERSION__/${KRNL_VERSION}/g"

ZIP_PATH=`pwd`/${KRNL_NAME}_prj/solution1/impl/export.zip
IP_DIR=../src/ip/${KRNL_NAME}
rm -rf ${IP_DIR}
mkdir -p ${IP_DIR}

vitis_hls -f "${TEMP_TCL}" -l vitis_hls.${KRNL_NAME}.log

cd ${IP_DIR}
unzip ${ZIP_PATH}
