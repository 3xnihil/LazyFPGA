#!/usr/bin/env bash
#
#######################################
### LazyFPGA Helper                 ###
### for Quartus Prime Lite (23.1.1) ###
#######################################
#
# Author: Johannes Hüffer
# Begin of development: 29.11.2024
# Version: 0.5
# Copying: GPL-3.0-only
#

SCRIPT_PRETTY_NAME="LazyFPGA Helper"
SCRIPT_TITLE="$(basename "${0}")"
SCRIPT_VERSION="0.5"

HELLO_MSG="\n${DIND}*-*-* Welcome to Jo's ${SCRIPT_PRETTY_NAME} *-*-*\n"

# Check GNU grep requirement, because BSD's grep syntax is slightly different
# and doesn't know the -P option going to be used
#
case "$(uname)" in
	Darwin)
		grep_bin="ggrep"
		if [ ! -f "$(which ggrep)" ]; then
			echo -e " To use the download option (-d) on macOS, you have to install GNU grep via Homebrew first!\n"
			exit 1
		fi
		;;
	# On Linux, GNU grep is the default
	Linux)
		grep_bin="grep"
		;;
	*)
		# Unsupported system will be rejected below ...
		grep_bin="grep"
		;;
esac

# 'lsb_release' command is too rare for serving as a reliable distro id tool.
# DISTRO="$(lsb_release -si)"
# This is only useful on actual Linux systems
if [ "$(uname)" = "Linux" ]; then
	DISTRO="$("${grep_bin}" -oP '^NAME="\K.+[^"]' /etc/os-release)"
	DISTRO_VARIANT="$("${grep_bin}" -oP '^VARIANT="\K.+[^"]' /etc/os-release)"
fi

# Dependencies: curl, git
DEPS=( "curl" "git" )


LOCAL_ICONDIR="${HOME}/.local/share/icons"
QUESTA_ICON="${LOCAL_ICONDIR}/elementary-kde/scalable/apps/gtkwave.svg"
QUARTUS_ICON="${LOCAL_ICONDIR}/elementary-kde/scalable/apps/marble.svg"
G_ICON_REPO="https://github.com/zayronxio/Elementary-KDE-Icons.git"

Q_LICENSE_DIR="${HOME}/.licenses"  # INFO: Change if you like.

TMP_SETUP_DIR="/tmp/fpga-setup"
Q_INSTALLER="qinst-lite-linux-23.1std.1-993.run"
Q_INSTALLER_CHECKSUM="3b09df589ff5577c36af02a693a49d67d7e692ff"
Q_INSTALLER_URL="https://downloads.intel.com/akdlm/software/acdsinst/23.1std.1/993/qinst/${Q_INSTALLER}"
Q_INSTALLER_URI="${TMP_SETUP_DIR}/${Q_INSTALLER}"
Q_DIRNAME="intelFPGA_lite"
Q_ROOTDIR="/opt/${Q_DIRNAME}"  # INFO: You can safely change '/opt' to any other location for testing purposes :)

LOCAL_APPDIR="${HOME}/.local/share/applications"
LOCAL_MIMEDIR="${HOME}/.local/share/mime"

QUARTUS_DESKTOP_LAUNCHER="com.intel.QuartusPrimeLite_23.1.1.desktop"
QUARTUS_DESKTOP_LAUNCHER_URI="${LOCAL_APPDIR}/${QUARTUS_DESKTOP_LAUNCHER}"

QUESTA_DESKTOP_LAUNCHER="com.intel.QuestaVsim_23.1.1.desktop"
QUESTA_DESKTOP_LAUNCHER_URI="${LOCAL_APPDIR}/${QUESTA_DESKTOP_LAUNCHER}"

# Text formatting variables
RED_BOLD="\e[1;31m"
YELLOW_BOLD="\e[1;33m"
GREEN_BOLD="\e[1;32m"
GREY="\e[90m"
ENDCOLOR="\e[0m"
DIND="\t\t"	# Double INDentation


### Direct error messages to STDERR (2)
#
function err() {
	echo -e "${GREY}[${ENDCOLOR}"\
			"${RED_BOLD}ERROR${ENDCOLOR}"\
			"${GREY}]${ENDCOLOR}\t$*" >&2
}


### Success messages also to STDERR (2)
#
function ok() {
	echo -e "${GREY}[${ENDCOLOR}"\
			"${GREEN_BOLD}OK${ENDCOLOR}"\
			"${GREY}]${ENDCOLOR}"\
			"${DIND}$*" >&2
}


### Warning messages to STDERR (2)
#
function warn() {
	echo -e "${GREY}[${ENDCOLOR}"\
			"${YELLOW_BOLD}WARNING${ENDCOLOR}"\
			"${GREY}]${ENDCOLOR}"\
			"\t$*" >&2
}


### Info messages to STDOUT (1)
#
function info() {
	echo -e "${DIND}$*"
}


### Check running kernel and CPU architecture
#
function check_platform() {
	if [ "$(uname)" != "Linux" ]; then
		echo -e "  /!\\ This script only works on GNU+Linux!\n"
		return 1
	fi

	cpu_arch="$(uname -p)"
	case "${cpu_arch}" in
		x86_64)
			ok "Running on x86-64 CPU"
			return 0
			;;
		unknown)
			warn "Could not determine CPU architecture!"
			ask_yn "Only answer 'Yes' if your are sure that your CPU is based on x86-64!" \
			"Hoping you were right ..." \
			"Going to quit."
			;;
		*)
			err "Quartus Prime Lite is only supported on x86-64 CPUs! Your's is based on ${cpu_arch}.\n"
			return 1
			;;
	esac
}


### Check login shell compatibility
#
# Only BASH and ZSH are supported.
#
function check_shell() {
	case "$(basename "${SHELL}")" in
		bash|zsh)
			ok "Your login shell is \"${SHELL}\"."
			return 0
			;;
		*)
			err "Sorry, your login shell \"${SHELL}\" is not supported by ${SCRIPT_PRETTY_NAME}!"
			info "Please use ZSH or BASH instead.\n"\
				"\t ==> I.e. by issuing \"chsh -s $(which bash)\" you can switch easily :)\n"
			return 1
			;;
	esac
}


### Check distribution
#
function check_distro() {
	case "${DISTRO}" in
		Ubuntu|Debian|'Linux Mint'|LMDE)
			ok "Running on ${DISTRO}."
			return 0
			;;

		'Fedora Linux')
			case "${DISTRO_VARIANT}" in
				Silverblue|Kinoite|*Atomic)
					err "Sorry, Fedora ${DISTRO_VARIANT} is not supported yet!"
					info " ==> The reason is its immutable nature. You'd must set up a Toolbox first,\n"\
						"${DIND} which requires extra tinkering. Maybe, ${SCRIPT_PRETTY_NAME} will support dedicated Toolbox installs in future.\n"\
						"${DIND} Read more on Toolbox here: https://docs.fedoraproject.org/en-US/fedora-silverblue/toolbox/"
					return 1
					;;
				*)
					ok "Running on Fedora."
					return 0
					;;
			esac
			;;

		openSUSE*)
			err "Sorry, openSUSE - especially Tumbleweed - is not supported!"
			info " ==> The reason is that it features very recent packages (i.e. glibc-2.41 upwards),"\
				"${DIND} but Quartus requires especially older versions of glibc (<= 2.38). Sorry!"
			return 1
			;;

		*)
			warn "${SCRIPT_PRETTY_NAME} has not been tested to work with ${DISTRO}."
			info " ==> You may proceed, but please don't expect things to work overall smoothly!"
			ask_yn
			;;
	esac
}


### Determine which desktop environment is used
#
function check_desktop() {
	case "${XDG_CURRENT_DESKTOP}" in
		GNOME|LXQt)
			ok "Desktop environment is ${XDG_CURRENT_DESKTOP}."
			return 0
			;;
		*)
			warn "${SCRIPT_PRETTY_NAME} could work on ${XDG_CURRENT_DESKTOP} desktop, but has not been tested yet!"
			info " ==> Proceed if you are seasoned with your desktop environment!"
			ask_yn
			;;
	esac
}


### Ask if user decision required
#
function ask_yn() {
	prompt="$1"
	answer_on_y="$2"
	answer_on_n="$3"

	[ -z "${prompt}" ] && prompt="Is this okay?"
	[ -z "${answer_on_y}" ] && answer_on_y="Moving on, but less lazy ..."
	[ -z "${answer_on_n}" ] && answer_on_n="Cancelled on your decision."

	read -p "${prompt} [y/N]: " choice	
	case "${choice}" in
		y|Y|yes|Yes|YES)
			info "${answer_on_y}\n"
			return 0
			;;
		*)
			info "${answer_on_n}\n"
			return 1
			;;
	esac
}


### Append a string separated by comma
#
function append_str() {
	str_to_extend="$1"
	str_to_append="$2"
	if [ -z "${str_to_extend}" ]; then
		str_to_extend="${str_to_append}"
	else
		str_to_extend="${str_to_extend}, ${str_to_append}"
	fi
	echo "${str_to_extend}"
}


### Verify dependencies
#
# ${deps_unmet} is set to empty string at
# startup in order to clean its contents from
# previous runs.
# ==> Otherwise, check_deps() might
# always exit with '1' even if all dependencies
# are now satisfied.
#
function check_deps() {
	deps_unmet=""
	for dep in "${DEPS[@]}"; do
		dep_uri="$(which "${dep}")"
		if [ -f "${dep_uri}" ]; then
			ok "\"${dep}\" installed."
		else
			err "\"${dep}\" not found!"
			deps_unmet="$(append_str "${deps_unmet}" "${dep}")"
		fi
	done

	[ -n "${deps_unmet}" ] &&\
	info " ==> Please install: ${deps_unmet}\n"\
		 "${DIND}  Then run ${SCRIPT_PRETTY_NAME} again.\n"

	# Final exit status depends on wether any programs are missing
	[ -z "${deps_unmet}" ]
}


### Check if current user is able to gain elevated privileges
#
function check_sudo() {
	case "${DISTRO}" in
		Ubuntu|Debian|'Linux Mint'|LMDE|elementaryOS)
			sudoers_group="sudo"
			;;
		'Fedora Linux'|RHEL*)
			sudoers_group="wheel"
			;;
		*)
			# If we are going off-road entirely ^^
			warn "Sorry, not knowing sudoers group of ${DISTRO}!"
			info " ==> Only answer 'Yes' if you know that for your distro.\n"\
				"${DIND} Otherwise, ${SCRIPT_PRETTY_NAME} will fail to make Quartus ready for use!\n"
			ask_yn "Are you really sure having sudo access?" ""
			;;
	esac

	# User must not be root
	if [ "${USER}" = "root" ]; then
		err "Running as root!"
		info "This is highly discouraged, as it puts your system to unnecessary risks!\n"\
			"${DIND} ==> Please login as a regular user having access to sudo and try again."
		return 1
	fi

	if [ -n "${sudoers_group}" ]; then
		([ "$(id -Gn | "${grep_bin}" -c "${sudoers_group}")" = "1" ] &&\
		ok "Current user \"${USER}\" may gain elevated permissions.") ||\
		(err "Sorry, user ${USER} does not have sufficient permissions to run ${SCRIPT_PRETTY_NAME}!" &&\
		info "Please make sure you may gain root privileges first, then try again.\n"\
			"${DIND} ==> Otherwise please contact your system administration." &&\
		return 1)
	else
		info "Relying on your answer!\n"\
			"${DIND} ==> If things don't work out later on, don't cry. You have been warned ;)"
	fi
}


### Check whether internet and desired web resource can be reached
#
# HTTP responses between 100-399 are fine, as well as
# server error responses between 500-599.
# Why? In some cases, we won't get a successful response i.e. because
# we are not allow to access the resource directly, but at least we now
# know that it's there and reachable.
#
function is_webresource_avail() {
	service_url="$1"
	info "Checking internet connectivity ..."

	if [ "$(ping -c 3 9.9.9.9 2> /dev/null)" ]; then
		ok "Internet connected."
		info "Looking out for ${service_url} ..."
		http_response="$(curl -sI "${service_url}" | head -n 1 | "${grep_bin}" -so [1-5][0-9][0-9])"

		case "${http_response}" in
			[1][0-9][0-9])
				warn "Service replied, but informational only!"
				info "HTTP status: ${http_response}"
				return 0
				;;
			[2][0-9][0-9])
				ok "Service replied."
				# info "HTTP status: ${http_response}"
				return 0
				;;
			[3][0-9][0-9])
				warn "Service replied, but will redirect!"
				info "HTTP status: ${http_response}"
				return 0
				;;
			[5][0-9][0-9])
				warn "Service replied, but with error!"
				info "HTTP status: ${http_response}"
				return 0
				;;
			*)
				err "Client: Troubles reaching service!"
				info "HTTP status: ${http_response}"
				return 1
				;;
		esac
	else
		err "Sorry, likely no internet connection!"
		info "At least no echo from Quad9's DNS after three attempts."
		return 1
	fi
}


### Download a file from a given URL
#
# CAUTION: ${local_uri} must contain an absolute path to a file!
#   Examples: "/home/user/foo.txt", "/tmp/foo/bar.png"
#
# Usage:
#   download "https://resource.net/file.txt" "/path/to/target/file.txt"
#
function download() {
	download_url="$1"
	local_uri="$2"
	service_domain="$(echo "${download_url}" | "${grep_bin}" -oP '^(https?://[^/]+)')"

	download_dir="${local_uri%/*}"
	download_file="$(basename "${local_uri}")"
	is_webresource_avail "${download_url}"

	if [ $? -eq 0 ]; then
		if [ ! -d "${download_dir}" ]; then
			info "Creating ${download_dir} ..."
			mkdir -p "${download_dir}"
		fi

		info "Now downloading from \"${service_domain}\" ...\n"
		curl -L -o "${local_uri}" "${download_url}"

		# Using "$?" to investigate curl's exit status because providing it
		# directly to the 'if' statement leads to exit status '1' for unknown reason
		# even if the download works fine.
		if [ $? -eq 0 ]; then
			echo ""
			ok "Download of \"${download_file}\" has finished."
			return 0
		else
			err "Download had hickups!"
			return 1
		fi
	else
		err "Sorry, download not possible :/"
		return 1
	fi
}


### Download Quartus installer
#
# If provided with an argument containing a path,
# it will store the downloaded Quartus installer there instead!
#
function download_qinstaller() {
	if [ -z "${1}" ]; then
		# If no custom dir is provided, choose the default one
		custom_installer_uri="${Q_INSTALLER_URI}"
	else
		custom_installer_uri="${1}/${Q_INSTALLER}"
	fi
	download "${Q_INSTALLER_URL}" "${custom_installer_uri}"
}


### Clone icon repository from Github to user's icon dir
#
function setup_icons() {
	if [ ! -d "${LOCAL_ICONDIR}/elementary-kde" ]; then
		(
			mkdir -p "${LOCAL_ICONDIR}" &&\
			info "Please wait, downloading icon set from Github ..." &&\
			git clone "${G_ICON_REPO}" "${LOCAL_ICONDIR}/elementary-kde" 2> /dev/null &&\
			ok "Icons have been set up, yay :)"
		) ||\
		(
			err "Something went wrong during icon setup! :/" &&\
			return 1
		)
	else
		ok "Icons already there :)"
	fi
}


### Verify a file's checksum
#
# Using SHA1, because ... icecream.
# Seriously, for the scope of this
# helper script it's sufficient I guess,
# as Intel only provides an SHA1 checksum.
#
function verify() {
	local_uri="$1"
	sha1_checksum_expected="$2"
	file_to_verify="$(basename "${local_uri}")"

	if [ -f "${local_uri}" ]; then
		info "Checking file integrity ..."
		if [ "$(sha1sum "${local_uri}" 2> /dev/null | "${grep_bin}" -i "${sha1_checksum_expected}")" ]; then
			ok "\"${file_to_verify}\" matches expected checksum and seems intact :)"
			return 0
		else
			warn "CAUTION: \"${local_uri}\"\n${DIND}may be corrupted and should not be used!"
			info " ==> Regardlessly whether this file has been downloaded\n"\
				"${DIND}  by ${SCRIPT_PRETTY_NAME} or spotted yet, you should delete it first.\n"
			ask_yn "Delete \"${local_uri}\"?"\
				"Just run ${SCRIPT_PRETTY_NAME} again and let it download the installer for you :)\n"\
				"Please delete manually (i.e. by issuing \"rm -f ${local_uri}\")\n"
			# User has confirmed removal
			if [ $? -eq 0 ]; then
				(rm -f "${local_uri}" &&\
				ok "\"${local_uri}\" has been removed.") ||\
				err "Could not remove \"${local_uri}\" for some reason!"
			fi
			return 1
		fi
	else
		err "Not able to verify! \"${local_uri}\" not present."
		return 1
	fi
}


### Verify Quartus installer
#
function verify_qinstaller() {
	verify "${Q_INSTALLER_URI}" "${Q_INSTALLER_CHECKSUM}"
}


### Maybe the user already got the Quartus installer
#
# IMPORTANT:
# Keeping things simple, it will only select
# the first match it spotted!
#
function locate_qinstaller() {
	info "Please wait, investigating \"/\" for a suitable installer already present anywhere ..."
	q_inst="$(find / -name "${Q_INSTALLER}" -type f 2> /dev/null | head -n 1)"
	if [ -f "${q_inst}" ]; then
		info "Found installer candidate ..."
		Q_INSTALLER_URI="${q_inst}"
		# ==> Candidate becomes verified at the next step,
		#   rendering file size validation unneccessary.
	else
		info "No Quartus installer seems present on your system.\n"\
			"${DIND}Trying to download it from Intel ..."
		download_qinstaller
	fi
}


### Check if user already got a license key for Questa Vsim
#
# Caution: This function assumes the user has downloaded only a
#   single key file, which will be stored inside the designated
#   directory afterwards (i.e. "/home/user/.licenses/").
#
#  ==> If there is more than one file and/or with
#   different names matching Intel's default naming convention
#   of the keys, 'locate_qlicense()' will assume a new key is about
#   to install!
#
function locate_qlicense() {
	info "Please wait, scanning \"${HOME}/\" for Questa license key ..."
	license_found="$(find "${HOME}" -name "LR-*_License.dat" -type f 2> /dev/null | head -n 1)"
	if [ ! -f "${Q_LICENSE_DIR}/$(basename "${license_found}")" ]; then
		if [ -f "${license_found}" ]; then
			ok "Found license key for Questa at \"${license_found}\"."
			info "Moving to \"${Q_LICENSE_DIR}/\" ..."
			(
				mkdir -p "${Q_LICENSE_DIR}" &&\
				mv "${license_found}" "${Q_LICENSE_DIR}/" &&\
				Q_LICENSE_URI="${Q_LICENSE_DIR}/$(basename "${license_found}")" &&\
				ok "License key now stored at \"${Q_LICENSE_URI}\"."
			) ||\
			(
				warn "Could not move license file (likely permission problem)!"
				info " ==> Please place the key manually afterwards.\n"\
					"${DIND} Then relaunch ${SCRIPT_PRETTY_NAME} for patching this after install has finished."
			)
		else
			warn "Could not find any license key for Questa Vsim!" &&\
			cat <<- EOB &&\
			ask_yn "Proceed anyways and add license later?"\
				"Be aware that Questa will not work for now!"

				If you are intending to run Questa, this will be required!
				In case you have one, make sure the license key file is stored
				anywhere inside your home directory ("${HOME}/") and has its default name
				(i.e. "LR-123456_License.dat") such that ${SCRIPT_PRETTY_NAME} can find it!

				 ==> If you don't have a license yet, you can get one from
				     Intel's licensing center at https://licensing.intel.com

				 ==> In case you want to add the license later, just run
				     "${SCRIPT_TITLE} -p" in order to start patching!
				  
			EOB
		fi

	# If a key has already been placed, we can skip the block above.
	# ==> We have to still update ${Q_LICENSE_URI}. Otherwise, it would become
	#   filled with the dummy-path placeholder what we don't want to happen in this case.
	# However, it is also safer to use the exact assignment below, preventing
	# duplicate keys elsewhere in the user's home tree from overwriting the desired key location.
	#
	else
		Q_LICENSE_URI="${Q_LICENSE_DIR}/$(basename "${license_found}")"
		ok "Seems license has already been installed :)"
	fi
}


### Bolster license URI with placeholder if empty (no license found)
#
# Makes manually adding the key's path a little bit easier for impatient users ;)
#
function cushion_qlicense() {
	[ -z "${Q_LICENSE_URI}" ] &&\
	Q_LICENSE_URI="/please/fill/in/path/to/license.dat"
	return 0
}


### Launch the actual Quartus installer
#
function run_qinstaller() {
	echo ""
	cat <<- EOB
		PLEASE READ CAREFULLY:
		  At next, the Intel Quartus installer will be launched.
		  You can use it as you'd regularly do, choosing the FPGA components you need.
		  
		  IMPORTANT: Please, leave the install paths and any related settings at their defaults.
		  
		   ==> Otherwise, ${SCRIPT_PRETTY_NAME} might not be able to find the
		    directory containing Quartus, preventing post-install assistance!
		  
		   ==> Make sure to uncheck the option "After-install actions".
		    Those only add poorly designed desktop launchers, unfortunately not helping anything.
		    ${SCRIPT_PRETTY_NAME} aims to solve this and a bunch of other issues for you :)
		  
		   ==> If for some reason Quartus installer doesn't do anything after downloading and verifying your
		    selected components, please click the "Download" button again. This will do the trick.
		  	
		   ==> After confirming "OK" when Quartus installer tells it finished, just click on "Close"
		    at the lower right corner of the installer's main window.
		    Once Quartus installer quit, ${SCRIPT_PRETTY_NAME} will move on and tries to do all the rest for you :)
		  
	EOB

	read -p 'Got it! [Enter]: '
	info "Making installer executable first ..."
	chmod +x "${Q_INSTALLER_URI}"
	info "Please wait, launching Quartus installer. Continue at its window!\n"
	"${SHELL}" -c "${Q_INSTALLER_URI}" ||\
	(
		echo ""
		err "Quartus installer has stopped unexpectedly due to an internal error!"
		cat <<- EOB
			 Please investigate its messages above!
			  
			 ==> If you see something like "libnsl.so.1: cannot open shared object file",
			  the "problem" is that your version of ${DISTRO} ships a recent version of glibc (>= 2.38)
			  but Quartus installer 23.1.1 still depends on those older ones!

			 ==> If it's not that, but a similar message, the problem concerns a different package, but the
			  cause is likely comparable.
			  
			 ==> CAUTION: DO NOT TRY TO DOWNGRADE such packages, as this WILL LIKELY BREAK YOUR ENTIRE SYSTEM!
			  Instead, you can set up a Docker or Podman container featuring an older version of ${DISTRO}
			  and run ${SCRIPT_PRETTY_NAME} inside of that.
			  
			 ==> It's recommended to consult Intel's requirement page for Quartus at
			  https://https://www.intel.com/content/www/us/en/support/programmable/support-resources/design-software/os-support.html
			  Here you can see which distro and version would be best to use along with a Docker or Podman container.
			  (i) Future versions of ${SCRIPT_PRETTY_NAME} will feature this container approach, avoiding any of these problems.
			  
		EOB
		return 1
	)
}


### Move Quartus to /opt directory which is more adequate
#
function relocate_qrootdir() {
	q_dir="$1"
	info "Creating new Quartus root directory ..."
	(
		sudo mkdir -p "${Q_ROOTDIR}" &&\
		info "Please wait a moment while moving \"${q_dir}\" to \"${Q_ROOTDIR}/\" ..." &&\
		sudo mv "${q_dir}"/* "${Q_ROOTDIR}/" &&\
		info "Making root the owner of Quartus ..." &&\
		sudo chown -R root:root "${Q_ROOTDIR}" &&\
		ok "Successfully relocated Quartus."
	) ||\
	(
		err "Something went wrong moving Quartus to \"${Q_ROOTDIR}/\"!" &&\
		return 1
	)
}


### Detect potential previous Quartus installation inside /opt and report that
#
# IMPORTANT:
#  This function will only select the first Quartus install
#  in case it has spotted one, even if there should be in fact
#  more than this (for the sake of simplicity as it is unlikely
#  for one having more than a single current install)!
#
function find_old_qrootdir() {
	find /opt -maxdepth 3 -name "${Q_DIRNAME}" -type d 2> /dev/null | head -n 1
}


### Integrate Quartus Prime into the Linux filesystem tree nicely
#
function install_q() {
	q_dir="$(find "${HOME}" -name "${Q_DIRNAME}" -type d 2> /dev/null | head -n 1)"
	q_old_rootdir="$(find_old_qrootdir)"

	if [ -d "${q_dir}" ]; then
		if [ -d "${q_old_rootdir}" ]; then
			echo ""
			warn "Seems there is a similar FPGA installation already present at \"${q_old_rootdir}\"!\n"
			ask_yn "Do you want to remove it and install new one instead?"\
				"Removing old stuff ..."\
				"Nothing changed." &&\
			# If user wants a new install, first remove old qroot and then relocate the new one:
			(
				info "To authorize removal, please enter your password if prompted for."
				(sudo rm -rf "${q_old_rootdir}" ||\
				err "Could not remove old root dir \"${q_old_rootdir}\"!") &&\
				relocate_qrootdir "${q_dir}"
			)
			# --> If no new install is desired, status '1'
			#	is returned by 'ask_yn' which will exit the script from here.
		else
			relocate_qrootdir "${q_dir}"
		fi
	else
		warn "Could not find \"${Q_DIRNAME}\" program folder!\n"
		cat <<- EOB
			As it seems, Quartus installer has not set up anything.
			==> Maybe you clicked "Cancel" accidentially.
			  Please make sure to give Quartus installer enough time to finish!
		EOB
		return 1
	fi
}


### Create a desktop file for Quartus
#
function create_quartus_launcher() {
	(cat <<- EOF > "${QUARTUS_DESKTOP_LAUNCHER_URI}" &&\
	ok "Created Quartus launcher at \"${QUARTUS_DESKTOP_LAUNCHER_URI}\".") ||\
	(err "Failed to create desktop launcher for Quartus!" &&\
	return 1)
		[Desktop Entry]
		Version=1.0
		Type=Application
		Name=Quartus
		Terminal=false
		Exec=${Q_ROOTDIR}/23.1std/quartus/bin/quartus --64bit %f
		Comment=Intel Quartus Prime Lite 23.1.1
		Icon=${QUARTUS_ICON}
		Categories=Development;X-Programming;
		MimeType=application/x-qpf
		Keywords=intel;fpga;ide;quartus;prime;lite;
		StartupWMClass=quartus
	EOF
}


### Create a desktop file for Questa
#
function create_questa_launcher() {
	(cat <<- EOF > "${QUESTA_DESKTOP_LAUNCHER_URI}" &&\
	ok "Created Questa launcher at \"${QUESTA_DESKTOP_LAUNCHER_URI}\".") ||\
	(err "Failed to create desktop launcher for Questa!" &&\
	return 1)
		[Desktop Entry]
		Version=1.0
		Type=Application
		Name=Questa
		Terminal=false
		Exec=env LM_LICENSE_FILE="${Q_LICENSE_URI}" ${Q_ROOTDIR}/23.1std/questa_fse/bin/vsim -gui %f
		Comment=Intel Questa Vsim (Prime Lite 23.1.1)
		Icon=${QUESTA_ICON}
		Categories=Development;X-Programming;
		MimeType=application/x-mpf;
		Keywords=intel;fpga;ide;simulation;model;vsim;
		StartupWMClass=Vsim"
	EOF
}


### Create desktop launchers for Quartus and Questa
#
function create_qlaunchers() {
	if [ ! -d "${LOCAL_APPDIR}" ]; then
		info "Creating local app directory \"${LOCAL_APPDIR}\" ..."
		mkdir -p "${LOCAL_APPDIR}" ||\
		(err "Could not create app dir!" &&\
		return 1)
	fi

	create_quartus_launcher
	create_questa_launcher
}


### Modify Quartus' environment variables
#
# Quartus installer already creates
# environment variables necessary for operation.
# 
#  ==> Because they have to be changed if the
#   program's location changes, this is done by
#   this function.
#   In case this shouldn't have happened, 'sed'
#   will fail silently, because it doesn't really
#   matter as the env-vars are going
#   to be (re)created independently.
#
function update_envvars() {
	shellrc="${HOME}/.$(basename "${SHELL}")rc"
	info "Updating Quartus' environment variables in \"${shellrc}\" ..."
	sed -i.old '/ROOTDIR/d' "${shellrc}" 2> /dev/null &&\
	ok "Backed up previous version of \"${shellrc}\" as \"${shellrc}.old\"."
	sed -i '/LM_LICENSE_FILE/d' "${shellrc}" 2> /dev/null

	# IMPORTANT: The '$' in Heredoc's last line below MUST be escaped,
	#	because the actual variables and NOT their content have to be given to the $PATH

	(cat <<- EOB >> "${shellrc}" &&\
	ok "Updated Quartus' environment variables.") ||\
	(err "Someting went wrong when trying to update Quartus' environment variables!" &&\
	return 1)
		export LM_LICENSE_FILE="${Q_LICENSE_URI}"
		export QSYS_ROOTDIR="${Q_ROOTDIR}/23.1std/quartus/sopc_builder/bin"
		export QFSE_ROOTDIR="${Q_ROOTDIR}/23.1std/questa_fse/bin"
		export PATH="\${PATH}:\${QSYS_ROOTDIR}:\${QFSE_ROOTDIR}"
	EOB
}


### Create udev-rules for USB-blaster support
#
function create_udevrules() {
	udev_rulepath="/etc/udev/rules.d"
	udev_file="51-usbblaster.rules"
	udev_uri="${udev_rulepath}/${udev_file}"
	info "Creating new udev rules for USB-blaster ..."

	(cat <<- EOF | sudo tee "${udev_uri}" > /dev/null &&\
	ok "Rules have been added.") ||\
	(err "Failed to create udev rules at \"${udev_uri}\"!" &&\
	return 1)
		SUBSYSTEM=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6001", MODE="0666"
		SUBSYSTEM=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6002", MODE="0666"
		SUBSYSTEM=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6003", MODE="0666"
		SUBSYSTEM=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6010", MODE="0666"
		SUBSYSTEM=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6810", MODE="0666"
	EOF
}


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
function create_mimetype() {
	new_type="$1"
	comment="$2"
	gen_iconname="$3"

	info "Creating MIME-type for \"${comment}\" ..."

	(cat <<- EOF > "${LOCAL_MIMEDIR}/packages/application-x-${new_type}.xml" &&\
	ok "Added new MIME-type.") ||\
	(err "Sorry, something went wrong when trying to create new MIME-type!" &&\
	return 1)
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

	create_mimetype "qpf" "Quartus project" "model"
	create_mimetype "mpf" "Questa Vsim project" "application-x-model"

	info "Telling desktop environment about changes ..."
	(
		update-mime-database "${LOCAL_MIMEDIR}" 2> /dev/null &&\
		update-desktop-database "${LOCAL_APPDIR}" 2> /dev/null &&\
		ok "Desktop environment updated changes"
	) ||\
	(
		warn "Desktop environment could not update changes automatically!"
		info " ==> Please log out and back in again after ${SCRIPT_PRETTY_NAME} finished. This works as well."
	)
}


### The setup process
#
function run_preinstaller() {
	check_platform &&\
	check_distro &&\
	check_shell &&\
	check_desktop &&\
	check_deps &&\
	check_sudo &&\
	locate_qlicense &&\
	cushion_qlicense &&\
	locate_qinstaller &&\
	verify_qinstaller &&\
	run_qinstaller &&\
	run_postinstaller
}


### Fix everything Intel forgot about
#
function apply_patches() {
	echo ""
	cat <<- EOB
		  APPLYING PATCHES (POST-INSTALL):
		   Some of the following steps you will need to confirm with your password.
		   Please enter it if prompted for.
		    ==> On most systems, nothing is echoed due to security reasons!
		   
	EOB

	create_qlaunchers
	create_qmimetypes
	setup_icons
	update_envvars
	create_udevrules

	echo ""
	cat <<- EOB
		  If you can see only green "OK" feedback below post-install headline
		  you are now ready to use your Intel FPGA suite :)
		   ==> Otherwise, please investigate the error messages
		    and fix the corresponding parts manually.
	EOB
}


### Run actual post-install assistant
#
function run_postinstaller() {
	install_q &&\
	apply_patches
}


### Display a short help
#
function show_help() {
	cat <<- EOB
		Usage:
		  ${SCRIPT_TITLE} <-i  Install Quartus | -p  Patch current installation |
		           -d <path>  Only download Quartus installer to path | -v  Show version | -h Show this help>
		  
		Options:
		  -i          Downloads Quartus installer (if not present) and install it with all extras Intel forgot about
		  
		  -p          Patch present Quartus installation. This updates Quartus' environment variables if a license
		              key has been placed afterwards
		  
		  -d <path>   Only download Quartus installer to the designated path (this won't do anything else)
		  
		  -v          Show version info of this script
		  
		  -h          Show this help
		  
	EOB
}


### Display version info
#
function show_version() {
	cat <<- EOB
		 ${SCRIPT_PRETTY_NAME} version ${SCRIPT_VERSION}
		 Copying: GPL-3.0-only
		 (c) Johannes Hüffer

	EOB
}


###### RUN THIS SCRIPT ######

### Parse arguments
#
# Available options:
# -i							Download (if necessary) and install Quartus
# -p							Patch present Quartus installation (updates env vars only; won't install anything)
# -d <path to download dir>		Only download Quartus installer (won't install nor change anything)
# -v							Show version info
# -h							Show help
#
while getopts ":ipd:vh" opt; do
	case "${opt}" in
		# Download and install Quartus
		i)
			clear
			echo -e "${HELLO_MSG}"
			run_preinstaller
			exit ${?}
			;;

		# Patch current installation (install license afterwards)
		p)
			check_platform &&\
			check_distro
			current_qinstallation="$(find_old_qrootdir)"
			(
				[ -d "${current_qinstallation}" ] &&\
				locate_qlicense &&\
				update_envvars &&\
				ok "Patching finished: License installed and environment vars have been updated." &&\
				info "You should be able to use Questa now!"
			) ||\
			(
				err "Sorry, something went wrong in the patching process."
				info " ==> Please investigate the error messages above!"
				return 1
			)
			exit ${?}
			;;

		# Only download Quartus installer (and do nothing else)
		d)
			#check_platform || exit 1
			([ -d "${OPTARG}" ] && download_qinstaller "${OPTARG}") ||\
			(
				echo -e " -d: Path does not exist! Using -d requires a valid path as positional argument!\n"
				show_help
				return 1
			)
			exit ${?}
			;;

		# Display version
		v)
			show_version
			exit
			;;

		# Display help
		h)
			show_help
			exit
			;;

		# Missing positional argument
		:)
			echo -e " -${OPTARG}: Missing argument!\n"
			show_help
			exit 1
			;;

		# Detected unknown argument
		*)
			echo -e " -${OPTARG}: Unknown argument!\n"
			show_help
			exit 1
			;;
	esac
done

# If no argument has been provided, display help message
[ -z "${*}" ] && echo -e " You must provide at least one argument!\n" && show_help && exit 1