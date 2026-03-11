#!/usr/bin/env bash
#
# Lazy FPGA Desktop Launcher Setup
#
# Author: Johannes Hüffer
# Begin of development: 29.11.2024
# Version: 0.1.0
# Copying: GPL-3.0-only
#

# Create a desktop file for Quartus
function create_quartus_launcher() {
	cat <<- EOF > "${QUARTUS_DESKTOP_LAUNCHER}"
		[Desktop Entry]
		Version=1.0
		Type=Application
		Name=Quartus
		Terminal=false
		Exec=distrobox enter ${CONTAINER_NAME} -- quartus --64bit %f
		Comment=Intel Quartus Prime Lite 23.1.1
		Icon=${QUARTUS_ICON}
		Categories=Development;IDE;ComputerScience;
		MimeType=application/x-qpf
		Keywords=intel;fpga;ide;quartus;prime;lite;
		StartupWMClass=quartus
	EOF
}


# Create a desktop file for Questa
function create_questa_launcher() {
	cat <<- EOF > "${QUESTA_DESKTOP_LAUNCHER}"
		[Desktop Entry]
		Version=1.0
		Type=Application
		Name=Questa
		Terminal=false
		Exec=distrobox enter "${CONTAINER_NAME}" -- vsim -gui %f
		Comment=Intel Questa Vsim (Prime Lite 23.1.1)
		Icon=${QUESTA_ICON}
		Categories=Development;IDE;ComputerScience;
		MimeType=application/x-mpf;
		Keywords=intel;fpga;ide;simulation;model;vsim;
		StartupWMClass=Vsim"
	EOF
}


# Create desktop launchers for Quartus and Questa
function create_qlaunchers() {
	if [ ! -d "${LOCAL_APPDIR}" ]; then
		info "Creating local app directory \"${LOCAL_APPDIR}\" ..."
		mkdir -p "${LOCAL_APPDIR}" ||\
		(err "Could not create app dir!" &&\
		return 1)
	fi

	create_quartus_launcher || err "Could not create Quartus desktop launcher!"
	create_questa_launcher || err "Could not create Questa destop launcher!"
}
