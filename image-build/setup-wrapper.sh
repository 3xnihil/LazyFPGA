#!/usr/bin/env bash
#
# Lazy FPGA Setup Wrapper
#
# Author: Johannes Hüffer
# Begin of development: 29.11.2024
# Version: 0.1.0
# Copying: GPL-3.0-only
#
# This wrapper script is to be installed inside of the Quartus container image.
# It invokes the actual Intel Quartus setup and checks its exit status.
#
# Depending on the latter, it will ...
#	a) Move the Quartus root dir to its final destination (env var "${Q_ROOTDIR}").
#		A hidden file called '.setup-done' inside the container's home dir
#		(env var "${CONTAINER_HOME}") if the setup has been successful;
#	b) A hidden file called '.setup-failed' inside the container's home dir
#		if the setup had problems.
#
# Only purpose of this wrapper is to tell 'post-installer.sh' when and how to
# continue with any finalizing steps, because processes executed inside the
# container run independently of the installer scripts. 
# 

if "${Q_INSTALLER_NAME}"; then
	# Maybe not best choice in case 'mv' fails,
	# but this will work if Intel setup went fine:
	mv "${Q_SETUP_DIR}/${Q_DIRNAME}" "${Q_ROOTDIR}"
	touch "${CONTAINER_HOME}/.setup-done"
else
	touch "${CONTAINER_HOME}/.setup-failed"
fi
