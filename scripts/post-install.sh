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

# Show success message in case install finished without any errors
function show_success_msg() {
	cat <<- EOB
		  
		 ${SCRIPT_PRETTY_NAME} has finished successfully!
		  
		 --> Quartus (and Questa) are now ready to use - nearly
		  independent of your base GNU+Linux distro :)
		  
		 --> To make sure everything will work smoothly,
		  please log out of your current desktop session and log back in.
		  
	EOB
}

# Show hint in cases the Quartus root dir cannot be found or Quartus/Questa are missing
function show_hint_to_missing_resource() {
	cat <<- EOB
		  
		 ==> Make sure that the Intel setup has enough time to finish!
		  You might see this if
		    - the Intel setup crashed during the "Installing" process;
		    - you accidentially clicked on "Cancel" or "Stop" before the download was finished.
		  
		 --> Just run ${SCRIPT_PRETTY_NAME} again, be patient and ensure a reliable internet connection.
		  In case the Intel setup seems not to do anything even if the download already finished,
		  just click the "Download" button again. This will do the trick and start the "Installing" process.
		  
	EOB
}

### Hang on in waiting loop until a flag-file is detected (Intel setup has quit).
# This tells us about the Intel setup's exit status, as the container prevents
# its direct investigation from the host

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

# Only proceed if the script was able to find a Quartus root dir
# ready for deployment! Otherwise, tell the user that it's missing and
# the setup has to be run again in order to download all required components
if [[ -d "${Q_ROOTDIR}" ]]; then
	is_anything_missing=false
	[[ -x "${QSYS_ROOTDIR}/quartus" ]] || { err "Found no binary for Quartus!"; is_anything_missing=true; }
	[[ -x "${QFSE_ROOTDIR}/vsim" ]] || { err "Found no binary for Questa (Vsim)!"; is_anything_missing=true; }
	if "${is_anything_missing}"; then
		show_hint_to_missing_resource
		exit 1
	fi
else
	err "Could not find Quartus root dir!"
	show_hint_to_missing_resource
	exit 1
fi

### Perform final post-install steps

steps_failed=()
exit_status=0

create_udevrules || steps_failed+=("Udev-rules (USB-blaster support)")
create_qlaunchers || steps_failed+=("Desktop launchers")
create_qmimetypes || steps_failed+=("MIME-types")
setup_icons || steps_failed+=("Icons for desktop launchers")
export_qcmds || steps_failed+=("Quartus/Questa container export and integration to host environment")


### Concise installation summary

if [[ "${#steps_failed[@]}" -eq 0 ]]; then
	show_success_msg
else
	cat <<- EOB
		  
		 Sorry, some steps experienced problems!
		  ==> Please investigate and try to fix manually:
		  
	EOB
	for step in "${steps_failed[@]}"; do
		echo "    - ${step}"
	done
	echo ""
	exit_status=1
fi

cat <<- EOB
	(i) Found a bug or do you have any suggestions for improvement or feedback?
	  ${SCRIPT_PRETTY_NAME} is free software (GPLv3).
	  You are welcome to make a pull request on GitHub
	  or fork the entire project at ${LAZYFPGA_PROJECTPAGE}
	  
	 Have a good day!
	  
EOB

exit "${exit_status}"