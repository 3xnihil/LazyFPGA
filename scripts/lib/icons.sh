#!/usr/bin/env bash
#
# Lazy FPGA Icon Setup
#
# Author: Johannes Hüffer
# Begin of development: 29.11.2024
# Version: 0.1.0
# Copying: GPL-3.0-only
#


# Clone icon repository from GitHub to user's icon dir
# (i) Credits to zayronxio for providing the icons!
function setup_icons() {
	if [ ! -d "${LOCAL_ICONDIR}/elementary-kde" ]; then
		(
			mkdir -p "${LOCAL_ICONDIR}" &&\
			info "Please wait, downloading icon set from GitHub ..." &&\
			git clone "${G_ICON_REPO}" "${LOCAL_ICONDIR}/elementary-kde" &> /dev/null &&\
			{ ok "Icons have been set up"; return 0; }
		) ||\
		{ err "Could not install icons!"; return 1; }
	else
		ok "Icons already present"
		return 0
	fi
}