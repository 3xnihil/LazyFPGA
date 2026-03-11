#!/usr/bin/env bash
#
# Lazy FPGA Pre-Installer
#
# Author: Johannes Hüffer
# Begin of development: 29.11.2024
# Version: 0.1.0
# Copying: GPL-3.0-only
#
# This script aims to prepare the host environment and will perform
# some checks in order to make sure that Quartus will be able to run
# on your computer platform.
#
# Quartus will be installed if ...
#	a)		The operating system is a GNU+Linux distro.
#			Other Unix-like OSes (BSD, macOS etc) are not supported!
#	b)		Your PC features an x86 CPU with 64 bit.
#			Neither 32 bit architectures nor ARM will work with Quartus
#			and are therefore not supported!
#	c)		The user you are running under may gain root privileges (can use sudo)
#	d)		The user you are running under is not root.
#			In case this is true it will be discouraged due to security reasons!
#	e)		The login shell of the user you are running under is either Bash or Zsh.
#			Different shells are not supported, sorry!
#	f)		A container provider is installed. This can be either Podman (recommended)
#			or Docker (which will of course work fine too, but Podman supports root-less
#			containers natively, while you will have to set up Docker Rootless additionally
#			if you are on Docker and want this feature).
#			When unsure, just choose Podman ;)
#	g)		Distrobox is installed, which is a very nice wrapper for Podman or Docker,
#			making the management of containers for desktop applications much more versatile.
#			For more information on distrobox, visit https://distrobox.it
#
# This pre-installer script will ...
#	1)		Display the content of the Questa license key file variable such that you can check
#			if everything is set correctly. If not, you can abort at this point and adjust things as needed.
#	2)		Download Quartus installer.
#	3)		If the download has been verified, the container image will be built.
#			The Quartus installer will then be moved to the container home directory.
#	4)		The actual container will be created and started if successful.
#			On its first startup, the container will launch the Quartus installer instantly.
#	5)		After you set up Quartus via Intel's setup and all resources required have been downloaded,
#			the setup will do its job and prepare Quartus' root directory.
#	6)		Once the setup finished, 'pre-install.sh' will launch 'post-install.sh'
#

### Load dependencies

# shellcheck source=/dev/null
source scripts/lib/feedback.sh
source scripts/lib/download.sh


### Verify the requirements

# Check if running on Linux kernel
function check_kernel() {
	if [ "$(uname)" != "Linux" ]; then
		err "This script only works on GNU+Linux!"
		return 1
	fi
}

# Check CPU architecture
function check_cpu_arch() {
	cpu_arch="$(uname -m)"
	case "${cpu_arch}" in
		x86_64)
			ok "CPU check passed"
			return 0
			;;
		unknown)
			warn "Could not determine CPU architecture!"
			ask_yn "Only answer 'Yes' if your are sure that your CPU is based on x86_64 architecture!" \
			"Hoping you were right!" \
			"Going to quit."
			;;
		*)
			err "Quartus Prime Lite is only supported on CPUs with x86_64 architecture!"
			info "Your's is based on ${cpu_arch}.\n"
			return 1
			;;
	esac
}

# Check user's login shell
function check_shell() {
	case "$(basename "${SHELL}")" in
		bash|zsh)
			ok "Your login shell is \"${SHELL}\"."
			return 0
			;;
		*)
			err "Sorry, your login shell \"${SHELL}\" is not supported by Quartus!"
			info "Please use ZSH or BASH instead.\n"\
				"\t ==> I.e. by issuing \"chsh -s $(which bash)\" you can switch easily :)\n"
			return 1
			;;
	esac
}

# Check Linux distro
function check_distro() {
	if [[ -f /etc/os-release ]]; then
		pretty_name="$(grep -oP '^PRETTY_NAME="\K.+[^"]' /etc/os-release)"
		info "Running on ${pretty_name}"
		return 0
	else
		warn "No OS release file found (\"/etc/os-release\"): Cannot determine distribution!"
		ask_yn "Only answer 'Yes' if you are sure that your system is an actual GNU+Linux distro (not Android or so)!" \
			"Taking by your word ..." \
			"See you!"
	fi
}

# Determine desktop environment
function check_desktop_env() {
	if [[ -n "${XDG_CURRENT_DESKTOP}" ]]; then
		ok "Desktop environment is ${XDG_CURRENT_DESKTOP}"
		return 0
	elif [[ -z "${XDG_SESSION_TYPE}" ]] && [[ -n "${DISPLAY}" ]] || [[ -n "${WAYLAND_DISPLAY}" ]]; then
		warn "Your session is graphical, but does not seem to follow the XDG Base Directory Specification!"
		cat <<- EOB
			  
			 ==> You see this because ${SCRIPT_PRETTY_NAME} relies on this specification
			  to determine where to store desktop launchers and mime types for Quartus and Questa.
			  Probably you will have to handle integration by yourself if things don't work out later!
			  
			 ==> However, ${SCRIPT_PRETTY_NAME} will still work and you may proceed with the installation.
			  
		EOB
		ask_yn "Are you comfortable with tinkering in case integration does not work?"
	else
		err "Your session runs on pure TTY!"
		info " ==> This is a CLI tool, but Intel Quartus setup requires a graphical session to work."
		info "  Please log in to a graphical session first and try again."
		return 1
	fi
}

# Check for not running as root
function verify_is_not_root() {
	[[ "${EUID}" -ne 0 ]] || { err "Running as root, which is discouraged! Choose a regular user."; return 1; }
}

# Check if sudo is available and the user may elevate privilege level
function check_sudo() {
	sudo_cmd="$(which sudo)"
	sudo_groups=("sudo" "wheel")
	effective_sudo_group=""
	if [[ -x "${sudo_cmd}" ]]; then
		for tested_group in "${sudo_groups[@]}"; do
			getent group "${tested_group}" &> /dev/null && effective_sudo_group="${tested_group}"
		done
		# Effective sudo group has been found. Exit status depends on whether current user has a membership
		if [[ -n "${effective_sudo_group}" ]]; then
			getent group "${effective_sudo_group}" | grep -q "${USER}"
			# --> Will return with '0' (success) only if user is a member of $effective_sudo_group
		# No effective sudo group has been found. Perform manual test if sudo is applicable
		else
			warn "Command 'sudo' is present, but none of these common sudo groups have been found: ${sudo_groups[*]}"
			info " ==> Let us test manually if user ${USER} is permitted to use sudo"
			info " Enter your password if prompted for:"
			if sudo echo -e "\t\t User ${USER} is allowed to use sudo"; then
				ok "Manual sudo check passed"
				return 0
			else
				err "Sorry, manual sudo check failed!"
				info " ==> Make sure to join your adequate sudo group first or please contact your system administration."
				return 1
			fi
		fi
	else
		err "It seems 'sudo' is not available at all!"
		info " ==> Please make sure sudo is installed on your system and ${USER} is allowed to use it!"
		return 1
	fi
}

# Make sure container provider (either Podman or Docker) is present
function check_container_provider() {
	possible_providers=("podman" "docker")
	for provider in "${possible_providers[@]}"; do
		[[ -x "$(which "${provider}")" ]] && { ok "Provider is ${provider}"; export PROVIDER_CMD="${provider}"; return 0; }
	done
	err "No container provider found!"
	info " ==> Please install either Podman (recommended) or Docker first."
	return 1
}

# Make sure given dependencies installed
function check_dependencies() {
	required_deps=( "$@" )
	deps_total="${#required_deps[@]}"
	deps_found=()
	deps_missing=()
	for dep in "${required_deps[@]}"; do
		if [[ -x "$(which "${dep}" 2> /dev/null)" ]]; then
			deps_found+=("${dep}")
		else
			deps_missing+=("${dep}")
		fi
	done
	if [[ "${#deps_found[@]}" -lt "${deps_total}" ]]; then
		err "${SCRIPT_PRETTY_NAME} is missing dependencies!"
		info " ==> Please install first: ${deps_missing[*]}\n"
		return 1
	else
		return 0
	fi
}

# Create future container home and setup dirs
function create_container_homedir() {
	info "Creating container home directory at \"${CONTAINER_HOME}\" ..."
	mkdir -p "${CONTAINER_HOME}" 2> /dev/null ||\
		{ err "Could not create container home directory at \"${CONTAINER_HOME}\"!"; return 1; }
	mkdir -p "${Q_SETUP_DIR}" 2> /dev/null ||\
		{ err "Could not create Quartus setup directory at \"${Q_SETUP_DIR}\"!"; return 1; }
}

# Write an 'argfile.conf' for the container builder (Podman or Docker) which includes
# all updated environment variables required by the image build process
function create_build_env_file() {
	cat <<- EOF > "${IMAGE_BUILD_ARGFILE}" || { err "Could not create build environment file!"; return 1; }
		# Argument file for Podman/Docker build
		# Used for Quartus Container image
		# Created automatically by ${SCRIPT_PRETTY_NAME} on $(date)
		lazyfpga_rootdir=${LAZYFPGA_ROOTDIR}
		container_home=${CONTAINER_HOME}
		container_setup_dir=${CONTAINER_SETUP_DIR}
		q_installer_dir=${Q_INSTALLER_DIR}
		q_installer_script=${Q_INSTALLER_SCRIPT}
		q_installer_wrapper=${Q_INSTALLER_WRAPPER}
		q_installer_wrapper_name=${Q_INSTALLER_WRAPPER_NAME}
		q_setup_dir=${Q_SETUP_DIR}
		q_dirname=${Q_DIRNAME}
		q_rootdir=${Q_ROOTDIR}
		lm_license_file=${LM_LICENSE_FILE}
		qsys_rootdir=${QSYS_ROOTDIR}
		qfse_rootdir=${QFSE_ROOTDIR}
	EOF
}

# Search Questa license key. If none can be found, inform the user and ask to proceed
function set_qlicense_key() {
	# License variable is empty, run auto-search for license file
	if [[ -z "${LM_LICENSE_FILE}" ]]; then
		if LM_LICENSE_FILE="$(find_file "*_License.dat")"; then
			ok "Found Questa license at \"${LM_LICENSE_FILE}\""
			return 0
		else
			warn "Could not find a license key for Questa"
			cat <<- EOB

				 /!\\ If you intend to use Questa, you will need one!
				      In this case, please obtain a license from Intel first.
				      Then, just run ${SCRIPT_PRETTY_NAME} again. It will automatically
				      find and set up the license key file.

				  --> If auto-find (still) doesn't work, please provide
				      the license manually by running "./${SCRIPT_TITLE} -l /path/to/your/license"!

				 PLEASE NOTE:
				  You will NOT be able to update the license once the Quartus container has been created!
				  Containers are designed to be rather static environments difficult to modify afterwards.
				  If you want to add a license key later, you have to uninstall the old
				  container first by running "./${SCRIPT_TITLE} -u" and create a new one.

				 Choose 'No' at the prompt below if you want Questa Vsim to work.
				 You may proceed with 'Yes' if you don't need Questa at all.

			EOB
			ask_yn "Are you really sure you want to proceed without a Questa license?" \
				"Be aware that Questa will not work!" \
				"Cancelled. Just run ${SCRIPT_PRETTY_NAME} again after you got one :)"
		fi
	# User defined -l option, use this instead
	else
		ok "Questa license is \"${LM_LICENSE_FILE}\""
		return 0
	fi
}

# Fetch Quartus setup. If none can be found locally, get one from Intel.
# IMPORTANT: Either way, the setup file MUST be finally moved into the 'image-build' folder
# where it is part of the Podman/Docker build context to be accessible from inside of the
# container environment later on!
function fetch_qinstaller() {
	# User provided installer via -s option
	if [[ -f "${Q_INSTALLER}" ]]; then
		ok "Intel Quartus setup already present"
	else
		# Search for setup locally first if not present
		if Q_INSTALLER="$(find_file "${Q_INSTALLER_NAME}")"; then
			ok "Auto-search found an Intel setup file"
			mv "${Q_INSTALLER}" "${IMAGE_BUILD_CONTEXT}/" 2> /dev/null \
			|| { warn "Could not move setup file to \"${IMAGE_BUILD_CONTEXT}\"!";
				info " --> Switching to download instead";
				download_qinstaller "${IMAGE_BUILD_CONTEXT}"; }
		# If there is no installer (with a default name), download one from Intel
		else
			info "Could not find an Intel setup file locally. Going to download ..."
			download_qinstaller "${IMAGE_BUILD_CONTEXT}"
		fi
	fi
	# Verify setup's integrity
	if verify "${Q_INSTALLER}" "${Q_INSTALLER_CHECKSUM}"; then
		# Make installer executable (required!), unpack it and extract its components,
		# preparing them to being copied into the container image
		chmod +x "${Q_INSTALLER}"
		"${Q_INSTALLER}" --target "${Q_INSTALLER_DIR}" --noexec --noprogress
	else
		err "The setup file \"${Q_INSTALLER}\" is likely corrupted and should not be used!"
		if ask_yn "Do you want to delete it and download a new one?" \
			"Downloading ..." "Cancelled. If you change your mind, just run ${SCRIPT_PRETTY_NAME} again."; then
				rm -f "${Q_INSTALLER}"
				if download_qinstaller "${IMAGE_BUILD_CONTEXT}"; then
					# Ensure the setup's default path is set (again) in this case (could have been customized)!
					Q_INSTALLER="${IMAGE_BUILD_CONTEXT}/${Q_INSTALLER_NAME}"
					return 0
				else
					return 1
				fi
		else
			return 1
		fi
	fi
}


### Check all requirements before launching actual pre-installer

clear
greet_short
heading "Stage 1/3: Checking requirements"

if check_kernel &&\
	verify_is_not_root &&\
	check_cpu_arch &&\
	check_desktop_env &&\
	check_distro &&\
	check_shell &&\
	check_sudo &&\
	check_container_provider &&\
	check_dependencies distrobox curl git; then


### Create the container home dir and prepare image build env

	create_container_homedir &&\
	create_build_env_file &&\


### Set Questa license key file via $LM_LICENSE_FILE env var

	set_qlicense_key &&\


### Search Quartus setup in $HOME. If not found, download from Intel

	fetch_qinstaller &&\
	

### Switch over to actual installer script if download was successful

	sleep 4 &&\
	source scripts/install.sh

fi