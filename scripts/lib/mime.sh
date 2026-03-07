#!/usr/bin/env bash
#
# Lazy FPGA Pre-installer Script
#
# Author: Johannes Hüffer
# Begin of development: 29.11.2024
# Version: 0.1.0
# Copying: GPL-3.0-only
#


### Create new MIME-type
#
# 'new_type': Base of both MIME-type's identifier and file extension
# (i.e. 'x-qpf' resp. '.qpf' for Quartus project files);
# 'comment': Short description (i.e. 'Quartus project file');
# 'gen_iconname': Determines what icon the desktop will choose for such files.
#
#  Please mind: Heredoc's content has been indented with spaces on purpose!
#	'cat <<- EOF' prevents tabs from being accidentially taken over from this script
#	inside the configuration file created.
#
# Usage: 'create_mimetype <type-name> <comment> <gen-icon-name>'
#
function create_mimetype() {
	new_type="$1"
	comment="$2"
	gen_iconname="$3"

	info "Creating MIME-type for \"${comment}\" ..."

	cat <<- EOF > "${LOCAL_MIMEDIR}/packages/application-x-${new_type}.xml"
		<?xml version="1.0" encoding="UTF-8"?>
		<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
		  <mime-type type="application/x-${new_type}">
		    <comment>${comment}</comment>
		    <generic-icon name="${gen_iconname}"/>
		    <glob pattern="*.${new_type}"/>
		  </mime-type>
		</mime-info>
	EOF
}


### Create MIME-types for Quartus and Questa files
#
function create_qmimetypes() {
	if [ ! -d "${LOCAL_MIMEDIR}" ]; then
		info "Creating local MIME directory \"${LOCAL_MIMEDIR}\" ..."
		mkdir -p "${LOCAL_MIMEDIR}/packages" ||\
		(err "Could not create MIME dir!" &&\
		return 1)
	fi

	create_mimetype "qpf" "Quartus project" "model" ||\
		err "Could not create MIME-type for Quartus project files!"
	create_mimetype "mpf" "Questa Vsim project" "application-x-model" ||\
		err "Could not create MIME-type for Questa project files!"

	info "Telling desktop environment about changes ..."
	(
		update-mime-database "${LOCAL_MIMEDIR}" &> /dev/null &&\
		update-desktop-database "${LOCAL_APPDIR}" &> /dev/null &&\
		ok "Desktop environment updated changes"
	) ||\
	(
		warn "Desktop environment could not update changes automatically!"
		info " ==> Please log out and back in again after ${SCRIPT_PRETTY_NAME} finished. This works as well."
	)
}