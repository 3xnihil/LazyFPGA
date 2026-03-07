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
	build_log="${IMAGE_BUILD_CONTEXT}/build-$(date -I seconds).log"
	info "Building the container image. This may take a while, so feel free to get some coffee ..."
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
	creation_log="${IMAGE_BUILD_CONTEXT}/creation-$(date -I seconds).log"
	info "Creating Quartus container \"${CONTAINER_NAME}\", please be patient ..."
	if distrobox create --name "${CONTAINER_NAME}" \
		--image "${IMAGE_NAME}" \
		--home "${CONTAINER_HOME}" \
		--no-entry &> "${creation_log}"; then
			ok "The Quartus container has been created successfully!"
			return 0
		else
			err "Sorry, something went wrong when trying to create the Quartus container!"
			info " ==> Please check the creation log, \"${creation_log}\""
			return 1
	fi
}

# Remove container and images (for cases of build fails)
function remove_container_setup() {
	cat <<- EOB
		 (i) Steps performed to remove container setup:
		  - Container "${CONTAINER_NAME}" itself
		  - Both container image "${IMAGE_NAME}" and Ubuntu base image
		  - Clearing build cache
		  
		 --> Finally, try to run ${SCRIPT_PRETTY_NAME} again.
		  
	EOB
	if (
		"${PROVIDER_CMD}" container rm -f "${CONTAINER_NAME}" &&\
		"${PROVIDER_CMD}" image rm -f "${IMAGE_NAME}" &&\
		"${PROVIDER_CMD}" image rm -f ubuntu:22.04 &&\
		"${PROVIDER_CMD}" buildx prune
	); then
		ok "Removed old container setup"
		return 0
	else
		err "At least one of the removal steps has failed!"
		cat <<- EOB
			  
			 ==> Try these steps manually:
			  1) Please remove the damaged container itself first:
			    ${PROVIDER_CMD} container rm ${CONTAINER_NAME}
			  2) Remove both container image and Ubuntu base image:
			    ${PROVIDER_CMD} image rm ${IMAGE_NAME}
			    ${PROVIDER_CMD} image rm ubuntu:22.04
			  3) Finally, clear the build cache:
			     ${PROVIDER_CMD} buildx prune
			  
			 After that, just run ${SCRIPT_PRETTY_NAME} again.
			  
			 --> In tough cases, you could try a full reset for ${PROVIDER_CMD}:
			     ${PROVIDER_CMD} system reset
			  
			 /!\\ CAUTION: ONLY DO THIS IF NOTHING ELSE HAS HELPED, AS THIS COMMAND
			   WILL AFFECT AND DESTROY ALL CONTAINERS AND IMAGES SET UP ON YOUR SYSTEM!
			  
		EOB
	fi
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

# Launch the Intel setup on first container start automatically
function launch_intel_setup() {
	info "Just a moment, distrobox init runs ..."
	if distrobox enter "${CONTAINER_NAME}" -- "${Q_INSTALLER_WRAPPER_NAME}" &> /dev/null; then
		ok "Container is ready"
		info "${GREEN_BOLD}==> Intel Quartus setup will now launch. Please continue at its window!${ENDCOLOR}\n"
		# (Give user time to notice the info before launching Quartus setup)
		sleep 2
		return 0
	else
		err "Sorry, distrobox had problems to initialize the container!"
		cat <<- EOB
			  
			 ==> Two main issues might have caused this:
			  i)  Base image corruption. If this happened, a container
			      created from such an image likely will have trouble.
			  ii) System time mismatch. The container's system time
			      is not in sync with that of the host system, causing
			      the container's initial package-index update to fail.
			  
			 --> Try to remove the problematic container setup first to
			  eliminate (i) as a cause. Answer 'Yes' at the next prompt.
			  Then run ${SCRIPT_PRETTY_NAME} again.
			 --> Should the problem persist, likely (ii) is the cause.
			  Answer 'No' at the next prompt and 'Yes' at the second.
			  Then compare the system time set on your computer to the time set
			  on the container. If they differ, please adjust your computer's
			  system time. The updated time will be propagated to the container
			  automatically, solving the issue.
			 --> In case none of these steps have helped, please investigate
			  the container log by yourself:
			   ${PROVIDER_CMD} logs -f ${CONTAINER_NAME}
			  
		EOB
		ask_yn "(i) Do you want to auto-remove the problematic container setup?" \
			"Starting auto-removal ..." "Switching to next option ..." &&\
			remove_container_setup &&\
			exit 1
		ask_yn "(ii) Do you want to compare system time settings?" \
			"Comparing time settings ..." &&\
			compare_systime_settings
		# Prevent the post-install stage from launching in this case!
		exit 1
	fi
}


### Build image, install the container and auto-launch the setup

clear
heading "Stage 2/3: Build image and create container"

build_image &&\
create_container &&\
launch_intel_setup


### Finally, launch the post-installer

# shellcheck source=/dev/null
source scripts/post-install.sh
