#!/usr/bin/env bash
#
# Lazy FPGA Uninstaller
#
# Author: Johannes Hüffer
# Begin of development: 29.11.2024
# Version: 0.1.0
# Copying: GPL-3.0-only
#
# To be launched by ./lazyfpga
#
# This un-installer script will ...
#	1) Remove the Quartus container and images it has been built with
#	2) Remove Quartus container desktop integration, namely
#		a) Quartus and Questa launchers
#		b) MIME-types for Quartus and Questa project files
#		c) Udev-rules for USB-blaster
#		d) CLI wrappers for quartus and vsim
#		e) The container's home directory
#

# Remove container and images
function remove_container_setup() {
	info "Removing Quartus container \"${CONTAINER_NAME}\" ..."
	if (
		"${PROVIDER_CMD}" container rm -f "${CONTAINER_NAME}" &> /dev/null &&\
		"${PROVIDER_CMD}" image rm -f "${IMAGE_NAME}" &> /dev/null &&\
		"${PROVIDER_CMD}" image rm -f ubuntu:22.04 &> /dev/null
	); then
		ok "Removed old container setup and images"
		info "Finished uninstalling. Have a nice day!\n"
		return 0
	else
		err "At least one of the removal steps has failed!"
		cat <<- EOB
			  
			 ==> Try these steps manually:
			  1) Please remove the container itself first:
			    ${PROVIDER_CMD} container rm -f ${CONTAINER_NAME}
			  2) Remove both container image and Ubuntu base image:
			    ${PROVIDER_CMD} image rm -f ${IMAGE_NAME}
			    ${PROVIDER_CMD} image rm -f ubuntu:22.04
			  3) Optionally, clear the build cache to remove any artifacts
			     from previous builds:
			    ${PROVIDER_CMD} buildx prune
			  
			 --> In very tough cases only, try a full reset for ${PROVIDER_CMD}:
			     ${PROVIDER_CMD} system reset
			  
			 /!\\ DANGER: ONLY PERFORM A FULL RESET IF NOTHING ELSE HAS HELPED!
			   THIS COMMAND WILL DESTROY ALL CONTAINERS AND IMAGES SET UP ON YOUR SYSTEM!
			  
		EOB
	fi
	return 0
}

# Remove desktop integration
function remove_desktop_integration() {
	files_to_remove=(
		"${QUARTUS_DESKTOP_LAUNCHER}" "${QUESTA_DESKTOP_LAUNCHER}"
		"${QUARTUS_MIME}" "${QUESTA_MIME}" "/etc/udev/rules.d/51-usbblaster.rules"
		"${HOME}/.local/bin/quartus" "${HOME}/.local/bin/vsim"
	)
	files_not_removed=()

	info "(i) Please enter your password if prompted for\n"

	for file in "${files_to_remove[@]}"; do
		if [[ -f "${file}" ]]; then
			# Try to remove with regular permissions first
			if rm -f "${file}" 2> /dev/null; then
				info "Removed $(basename "${file}")"
			# If file is present, but cannot be removed, elevate privileges
			else
				sudo rm -f "${file}" 2> /dev/null && info "Removed $(basename "${file}")" \
				|| files_not_removed+=("${file}")
			fi
		else
			info "File \"${file}\" not present (removed already?), skipping ..."
		fi
	done

	# All files have been removed
	if [[ "${#files_not_removed[@]}" -eq 0 ]]; then
		ok "Successfully removed Quartus desktop integration"
		return 0
	else
		err "Sorry, some files have not been removed"
		info " ==> Please clean up these manually:"
		for file in "${files_not_removed[@]}"; do
			info "  - ${file}"
		done
		echo ""
		return 1
	fi
}

# Remove container home directory
function remove_container_home() {
	info "Removing container home directory, \"${CONTAINER_HOME}\" ..."
	if sudo rm -rf "${CONTAINER_HOME}" 2> /dev/null; then
		ok "Successfully removed"
		return 0
	else
		err "Sorry, could not remove!"
		cat <<- EOB
			  
			 ==> Please note that auto-removal is only supported
			  for the default container home directory!
			  If you chose a custom path for install, please remove
			  the directory manually.
			  
		EOB
		return 1
	fi
}

# Get container provider (podman or docker)
function get_container_provider() {
	possible_providers=("podman" "docker")
	for provider in "${possible_providers[@]}"; do
		[[ -x "$(which "${provider}")" ]] && { export PROVIDER_CMD="${provider}"; return 0; }
	done
	err "Neither Podman nor Docker seems installed on your system!"
	cat <<- EOB
		 ==> Running this uninstaller routine will not work without!
		  
		 (i) In case you removed Podman/Docker (and Distrobox) in a hurry
		  but now want to remove a left-over Quartus desktop integration,
		  please reinstall Podman or Docker for this purpose and try again.
		  
	EOB
	return 1
}

# Uninstall Quartus environment
function uninstall_quartus() {
	echo ""
	warn "YOU ARE ABOUT TO REMOVE YOUR ENTIRE CONTAINERIZED QUARTUS SETUP!"
	if ask_yn "Do you really want to continue?" \
		"Starting uninstall ..." "Did not touch anything!"; then
			if get_container_provider; then
				remove_desktop_integration
				remove_container_home
				remove_container_setup
			else
				info "Cancelled uninstaller. See you!\n"
			fi
	fi
}