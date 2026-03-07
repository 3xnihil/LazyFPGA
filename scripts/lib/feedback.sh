#!/usr/bin/env bash
#
# Lazy FPGA Feedback to/from User
#
# Author: Johannes Hüffer
# Begin of development: 29.11.2024
# Version: 0.1.0
# Copying: GPL-3.0-only
#


# Text formatting variables
RED_BOLD="\e[1;31m"
YELLOW_BOLD="\e[1;33m"
GREEN_BOLD="\e[1;32m"
CYAN_BOLD="\e[1;36m"
GREY="\e[90m"
ENDCOLOR="\e[0m"
DIND="\t\t"	# Double INDentation


### Display error message
#
function err() {
	echo -e "${GREY}[${ENDCOLOR}"\
			"${RED_BOLD}ERROR${ENDCOLOR}"\
			"${GREY}]${ENDCOLOR}\t$*" >&2
}


### Display success message
#
function ok() {
	echo -e "${GREY}[${ENDCOLOR}"\
			"${GREEN_BOLD}OK${ENDCOLOR}"\
			"${GREY}]${ENDCOLOR}"\
			"${DIND}$*" >&2
}


### Display warning
#
function warn() {
	echo -e "${GREY}[${ENDCOLOR}"\
			"${YELLOW_BOLD}WARNING${ENDCOLOR}"\
			"${GREY}]${ENDCOLOR}"\
			"\t$*" >&2
}


### Display arbitrary info
#
function info() {
	echo -e "${DIND}$*" >&2
}


### Display heading
#
function heading() {
	echo -e "\n${CYAN_BOLD} --- $* ---${ENDCOLOR}\n"
}


### Display important hint
#
function important_note() {
	echo -e "\n${YELLOW_BOLD} >>> $* <<<${ENDCOLOR}\n"
}


### Greet the user (1)
# Take care of the blanks when modifying Heredocs ;)
#
function greet_long() {
	cat <<- EOB
		    
		 *-*-*-*-*-*-*-*-*-*-*-* Welcome to ${SCRIPT_PRETTY_NAME} *-*-*-*-*-*-*-*-*-*-*-*
		    
		   You will be guided through the process to install Intel's FPGA suite,
		   Quartus Prime Lite, on your GNU+Linux system.
		   While performing all the steps Intel has missed out, it goes much further
		   and decouples Quartus' system requirements from the used distribution almost entirely.
		    
		   It achieves this by installing Quartus' core components to a containerized
		   environment, maximizing flexibility and freedom of distro choice at the same time.
		    
		   By this approach, possible incompatibilities shrink to
		    
		       - CPU architecture (x86_64 only),
		       - out-of-the-box desktop integration (XDG Base Directory Specification),
		    
		   resulting in an almost seamless experience with Quartus across a variety
		   of very different GNU+Linux distros!
		    
		  (i) Found a bug or have any ideas for improvement? Feel free
		      to contribute! Join this project on ${LAZYFPGA_PROJECTPAGE}
		    
		 *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
		    
	EOB
}


### Greet the user (2)
#
function greet_short() {
	echo -e "\n${CYAN_BOLD} *-*-* Welcome to ${SCRIPT_PRETTY_NAME} *-*-* ${ENDCOLOR}\n"
}


### Display usage help
#
function show_help() {
	cat <<- EOB
		Usage:
		  ${SCRIPT_TITLE} [-s <setup-file>  Use custom Quartus setup file] [-l <license-key-file>  Provide Questa license]
		            [-c <container-home-path>  Set custom container home] |
		            [-u  Uninstall container and other components] | [-h  Show help] | [-v  Show version]
		  
		Options:
		  (none)                  No options at all - the lazy variant ;)
		                          ${SCRIPT_PRETTY_NAME} tries to figure out configuration on its own:
		                            1) Search locally for a Quartus setup file. If none can be found in ${USER}'s home dir,
		                               it will download one from Intel automatically.
		                               --> For a different behaviour, please use the -s option and specify a setup file manually!
		                            2) Search locally for a Questa license key file and accept its path automatically if found one.
		                               If no key file has been found, the environment variable "\$LM_LICENSE_KEY" remains empty.
		                               --> Please keep in mind that you have to obtain such a key from Intel by yourself if you need Questa!
		                               Your key file will only be found if it has its default name (like "LR-123456_License.dat").
		                               --> In other cases, please use the -l option and specify the key manually!
		  
		  -s <setup-file>         Use a custom Quartus setup (with non-default file name) the auto-search cannot find
		  
		  -l <license-key-file>   Provide Questa license key (with non-default file name) the auto-search cannot find
		  
		  -c <container-home-path>     Change home path for the Quartus Container (defaults to "${CONTAINER_HOME}")
		  
		  -u                      Uninstall present Quartus and remove its desktop integration (container, launchers, mimes, udev rules)
		  
		  -v                      Show version info of this script
		  
		  -h                      Show this help
		  
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


### Ask if user decision required
#
function ask_yn() {
	prompt="$1"
	answer_on_y="$2"
	answer_on_n="$3"

	[ -z "${prompt}" ] && prompt="Is this okay?"
	[ -z "${answer_on_y}" ] && answer_on_y="Moving on, but less lazy ..."
	[ -z "${answer_on_n}" ] && answer_on_n="Cancelled on your decision."

	printf " %s [y/N]: " "${prompt}"
	read -r choice
	echo ""
	case "${choice}" in
		y|Y|yes|Yes|YES)
			echo -e "  ${answer_on_y}\n"
			return 0
			;;
		*)
			echo -e "  ${answer_on_n}\n"
			return 1
			;;
	esac
}