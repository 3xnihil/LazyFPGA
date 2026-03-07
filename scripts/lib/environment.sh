#!/usr/bin/env bash
#
# Lazy FPGA Environment File
#
# Author: Johannes Hüffer
# Begin of development: 29.11.2024
# Version: 0.1.0
# Copying: GPL-3.0-only
#
# In here you find environment variables required by Quartus and Lazy FPGA.
# They are divided into two sections:
#
# 1) Variables which are OPTIONAL to be adjusted if you like (but don't need to);
# 2) Variables which are NOT INTENDED TO BE CHANGED MANUALLY in regular use cases.
#
#  /!\ WARNING: CHANGING VARIABLES UNDER (2) WILL LIKELY BREAK FUNCTIONALIY!
# 	ONLY TOUCH THESE IF NECESSARY AND IF YOU HAVE FULLY UNDERSTOOD THEIR PURPOSE!
#


### 1) These variables may be customized OPTIONALLY (but don't need to)
export SCRIPT_TITLE="lazyfpga"
export SCRIPT_PRETTY_NAME="Lazy FPGA Container Builder"
export SCRIPT_VERSION="0.1.0"
export IMAGE_NAME="fpga-image:latest"
export CONTAINER_NAME="fpga-container"
export CONTAINER_HOME="${HOME}/.containers/${CONTAINER_NAME}"

### 2) DO NOT MANUALLY CHANGE the following variables unless you really know why!
export LAZYFPGA_ROOTDIR="${PWD}"
export LAZYFPGA_PROJECTPAGE="https://github.com/3xnihil/LazyFPGA"
export PROVIDER_CMD=""
export IMAGE_BUILD_CONTEXT="${LAZYFPGA_ROOTDIR}/image-build"
export IMAGE_BUILD_ARGFILE="${IMAGE_BUILD_CONTEXT}/argfile.conf"
export Q_INSTALLER_NAME="qinst-lite-linux-23.1std.1-993.run"
export Q_INSTALLER="${IMAGE_BUILD_CONTEXT}/${Q_INSTALLER_NAME}"
export Q_INSTALLER_CHECKSUM="3b09df589ff5577c36af02a693a49d67d7e692ff"
export Q_INSTALLER_URL="https://downloads.intel.com/akdlm/software/acdsinst/23.1std.1/993/qinst/${Q_INSTALLER_NAME}"
export Q_INSTALLER_WRAPPER_NAME="setup-wrapper.sh"
export Q_DIRNAME="intelFPGA_lite"
export Q_ROOTDIR="${CONTAINER_HOME}/${Q_DIRNAME}"
export Q_SETUP_DIR="${CONTAINER_HOME}/setup"
export LM_LICENSE_FILE=""
export QSYS_ROOTDIR="${Q_ROOTDIR}/23.1std/quartus/bin"
export QFSE_ROOTDIR="${Q_ROOTDIR}/23.1std/questa_fse/bin"
export LOCAL_APPDIR="${HOME}/.local/share/applications"
export LOCAL_MIMEDIR="${HOME}/.local/share/mime"
export LOCAL_ICONDIR="${HOME}/.local/share/icons"
export QUARTUS_DESKTOP_LAUNCHER="${LOCAL_APPDIR}/com.intel.QuartusPrimeLite_23.1.1.desktop"
export QUESTA_DESKTOP_LAUNCHER="${LOCAL_APPDIR}/com.intel.QuestaVsim_23.1.1.desktop"
export QUESTA_ICON="${LOCAL_ICONDIR}/elementary-kde/scalable/apps/gtkwave.svg"
export QUARTUS_ICON="${LOCAL_ICONDIR}/elementary-kde/scalable/apps/marble.svg"
export G_ICON_REPO="https://github.com/zayronxio/Elementary-KDE-Icons.git"
