#!/usr/bin/env bash
#
# Lazy FPGA Post-Installer
#
# Author: Johannes Hüffer
# Begin of development: 29.11.2024
# Version: 0.1.0
# Copying: GPL-3.0-only
#
# To be launched by ./scripts/install.sh
#
# This post-install script aims to integrate the Quartus container
# well within the host's environment.
# 
# It will ...
#	0)	Wait until either flag-file '.setup-done' or '.setup-failed'
#		 inside the container's home directory is detected:
#			a) Found '.setup-done', proceed with step (1);
#			b) Found '.setup-failed', cancel with error message.
#	1)	Set up udev rules for "USB-blaster" programmer
#	2)	Set up desktop launchers for Quartus and Questa
#	3)	Set up mime types for Quartus and Questa project files
#	4)	Set up icons for the launchers
#	5)	Export cli tools of Quartus and Questa from the container to make them
#		 accessible as they were installed natively on the host system.
#

FF_SETUP_DONE="${CONTAINER_HOME}/.setup-done"
FF_SETUP_FAILED="${CONTAINER_HOME}/.setup-failed"


### Hang on in waiting loop until flag-file detected

important_note "Waiting for Intel setup to finish: KEEP THIS SESSION OPENED!"

while [[ ! -f "${FF_SETUP_DONE}" ]] && [[ ! -f "${FF_SETUP_FAILED}" ]]; do
	sleep 1
done


### Check which file has been actually placed

clear
heading "Stage 3/3: Finalization and desktop integration"

if [[ -f "${FF_SETUP_FAILED}" ]]; then
	err "Sorry! Intel setup returned an error: Cannot finish Quartus container install :/\n"
	rm -f "${FF_SETUP_FAILED}"
	exit 1
elif [[ -f "${FF_SETUP_DONE}" ]]; then
	ok "Intel setup done"
	rm -f "${FF_SETUP_DONE}"
fi


### Finalizing installation and perform remaining integration steps

source scripts/lib/usbblaster.sh
source scripts/lib/desktop.sh
source scripts/lib/mime.sh
source scripts/lib/icons.sh
source scripts/lib/cmdexport.sh

create_udevrules
create_qlaunchers
create_qmimetypes
setup_icons
export_qcmds

# TODO: Display this goodbye message always with a sig-trap if the script exits
cat <<- EOB
	  
	 ${SCRIPT_PRETTY_NAME} has finished.
	  
	 --> Please evaluate the messages above.
	  If you can only see green "OK" feedback,
	  Quartus (and Questa) are now ready to use - nearly
	  independent of your base GNU+Linux distro :)
	  
	 --> To make sure everything will work smoothly,
	  please log out of your current desktop session and log back in.

	 (i) Found a bug or do you have any improvements or feedback?
	  ${SCRIPT_PRETTY_NAME} is free software (GPLv3).
	  You are welcome to make a pull request on GitHub
	  or fork the entire project:
	    "${LAZYPFGA_PROJECTPAGE}"
	  
EOB
