#!/usr/bin/env bash
#
# Lazy FPGA Main Container Installer
#
# Author: Johannes Hüffer
# Begin of development: 29.11.2024
# Version: 0.1.0
# Copying: GPL-3.0-only
#
# To be launched by ./scripts/pre-install.sh
#
# This installer script will ...
# 	1) Build the container image
#	2) Create a container using this image
# 	3) Install Quartus inside this container
# 


# Build the container image
function build_image() {
	build_log="${IMAGE_BUILD_CONTEXT}/build-$(date --iso-8601=seconds).log"
	info "The next steps may take some time to complete, so feel free to get some coffee"
	info "Building the container image ..."
	if "${PROVIDER_CMD}" build --build-arg-file "${IMAGE_BUILD_ARGFILE}" -t "${IMAGE_NAME}" "${IMAGE_BUILD_CONTEXT}" &> "${build_log}"; then
		ok "Image \"${IMAGE_NAME}\" built successfully"
		return 0
	else
		err "Sorry, a problem occurred during the build!"
		info " ==> Please investigate the build log, \"${build_log}\""
		return 1
	fi
}

# Create the container itself from the image
function create_container() {
	creation_log="${IMAGE_BUILD_CONTEXT}/creation-$(date --iso-8601=seconds).log"
	info "Creating Quartus container \"${CONTAINER_NAME}\" ..."
	if distrobox create --name "${CONTAINER_NAME}" \
		--image "${IMAGE_NAME}" \
		--home "${CONTAINER_HOME}" \
		--no-entry &> "${creation_log}"; then
			ok "Quartus container has been created"
			return 0
		else
			err "Sorry, something went wrong when trying to create the Quartus container!"
			info " ==> Please check the creation log, \"${creation_log}\""
			return 1
	fi
}

# Remove container and images in cases of build fails
function cleanup_after_buildfail() {
	# shellcheck source=/dev/null
	source scripts/uninstall.sh
	cat <<- EOB
		 (i) Steps performed to clean-up a corrupted container setup:
		  - Removing container "${CONTAINER_NAME}" itself
		  - Removing both container image "${IMAGE_NAME}" and Ubuntu base image
		  - Clearing build cache
		  
	EOB
	remove_container_setup
	info "--> Finally, try to run ${SCRIPT_PRETTY_NAME} again.\n"
	return 0
}

# Compare system times between host and container (for debugging purposes only)
function compare_systime_settings() {
	container_time_utc="$(${PROVIDER_CMD} container run --replace --name "${CONTAINER_NAME}-test" "${IMAGE_NAME}" date +%s)"
	host_time_utc="$(date +%s)"
	time_diff_secs=$(( container_time_utc - host_time_utc ))
	time_diff_secs="${time_diff_secs#-}"
	if [[ "${time_diff_secs}" -eq 0 ]]; then
		cat <<- EOB
			 Host and container system time are synchronized perfectly.
			  --> However, please make sure that the actual system time set on your PC is correct!
			  
		EOB
		return 0
	else
		cat <<- EOB
			 Time set on host (your PC): $(date)
			 Time set on container:      $(${PROVIDER_CMD} container run --replace --name "${CONTAINER_NAME}-test" "${IMAGE_NAME}" date)
			 Time difference in seconds: ${time_diff_secs}
			  
			 --> Please adjust your PC's time setting!
			   Then, try to run ${SCRIPT_PRETTY_NAME} again.
			  
		EOB
		return 1
	fi
}

# Check root sharing for filesystem
function check_root_sharing() {
	# If "/" is shared, this can't be the problem
	if findmnt -o TARGET,PROPAGATION / | grep -q shared; then
		ok "Filesystem root, \"/\", already shared"
		info " ==> This is not the cause of this problem!"
		return 0
	else
		exit_status=0
		warn "Filesystem root, \"/\", is not shared!"
		info "(i) Changing this temporarily. Please enter you password if prompted for\n"
		sudo mount --make-shared / && exit_status="$?"
		cat <<- EOB
			  
			 --> Make the share permanent manually. On many distros, edit
			  Grub configuration at "/etc/default/grub" and append to
			  the same line starting with "GRUB_CMDLINE_LINUX= ... shared-subtree=shared",
			  where "..." stands for any parameters which already had been in place before
			  and should remain unchanged normally!
			 --> Update your Grub bootloader. How to do this heavily depends on your distro,
			  so please figure this out by yourself. The change should then survive reboots.
			  
		EOB
		return "${exit_status}"
	fi
}

# Launch the Intel setup on first container start automatically
function launch_intel_setup() {
	info "${GREEN_BOLD}Distrobox will prepare the container in the next step."
	info " ==> If ready, container will auto-launch the Intel setup. If it does, please continue at its window!${ENDCOLOR}\n"
	cat <<- EOB
		 PLEASE READ CAREFULLY BEFORE YOU CONTINUE:
		  
		  --> For the Intel setup, make sure to un-tick the checkbox "After-install actions".
		      This prevents placement of broken launcher files on your desktop (they don't do any
		      harm, they are just annoying and useless).
		  
		  --> Keep all other settings-related options at their defaults! Otherwise, ${SCRIPT_PRETTY_NAME}
		      cannot find the components Intel setup has downloaded, breaking functionality of this script.
		  
		  --> Choose the FPGA components you need.
		      If you are ready, click on "Download" to start the setup process.
		  
		  --> If the Intel setup tells you it finished, confirm this message and close the setup's window.
		      ${SCRIPT_PRETTY_NAME} will continue automatically and finish your Quartus install :)
		  
	EOB
	important_note "As ${SCRIPT_PRETTY_NAME} waits for it to finish, PLEASE KEEP THIS SESSION OPENED!"

	# User can confirm by pressing Enter if finished reading the message above
	read -rp " Got it! [Enter]: "
	echo ""
	info "Preparing container. This may take a while, so please be patient ..."

	# Ensure that distrobox successfully prepares the container:
	#  Launch the wrapper script which will run the actual Intel setup such that we
	#  can track when (flag-file has been placed) and how (exit status) the setup has quit:
	if distrobox enter "${CONTAINER_NAME}" -- "${Q_INSTALLER_WRAPPER}" &> /dev/null; then
		ok "Container is ready"
		# Prevent the ok-message from being cleared instantly
		sleep 3
		return 0

	# If container preparation fails, provide gentle guidance for troubleshooting
	else
		err "Sorry, distrobox had problems to initialize the container!"
		cat <<- EOB
			  
			 ==> Three main issues might have caused this:
			  i)    Base image corruption. If this happened, a container
			        created from such an image likely will not work at all.
			  ii)   System time mismatch. System time is set wrongly,
			        causing the container's initial package-index update
			        to fail (time-related cert validation problem).
			  iii)  Maybe your host's filesystem root, "/", is not shared,
			        posing potential problems to rootless container setups
			        like the one about to set up.
			  
			 --> Try to remove the problematic container setup first to
			  eliminate (i) as a cause. Answer 'Yes' at the next prompt.
			  
			 --> Should the problem persist, maybe (ii) is the cause.
			  Answer 'No' at the next prompt and 'Yes' at the second.
			  Then ensure the system time set on your host computer is accurate
			  and compare it to the time set on the container.
			  If the time is wrong, please adjust and correct your host
			  computer's system time!
			  The updated host time will be propagated to the container
			  automatically, solving the issue.
			  
			 --> Should the problem still persist, (iii) could be the cause.
			  Answer 'No' at the next two prompts and 'Yes' at the third.
			  This will temporarily enable root sharing, which is required
			  for rootless containers to work properly.
			  
			 (i) In case none of these steps have helped, please investigate
			  the container log by yourself:
			    ${PROVIDER_CMD} logs -f ${CONTAINER_NAME}
			  
		EOB
		ask_yn "(i)   Do you want to auto-remove the problematic container setup?" \
			"Starting auto-removal ..." "Switching to next option ..." &&\
			cleanup_after_buildfail &&\
			exit 1
		ask_yn "(ii)  Do you want to compare system time settings?" \
			"Comparing time settings ..." "Switching to next option ..." &&\
			compare_systime_settings &&\
			exit 1
		ask_yn "(iii) Do you want to check root sharing?" \
			"Checking root sharing ..." &&\
			check_root_sharing
			
		info "Finally, run ${SCRIPT_PRETTY_NAME} again.\n"
		# Prevent the post-install stage from launching in this case!
		exit 1
	fi
}


### Build image, install the container and auto-launch the setup

clear
heading "Stage 2/3: Build image and create container"

if build_image && create_container; then
	launch_intel_setup

### Finally, launch the post-installer

	# shellcheck source=/dev/null
	source scripts/post-install.sh

# If the essential preparation steps (image build and container setup) fail, leave
else
	exit 1
fi