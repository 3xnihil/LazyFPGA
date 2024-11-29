#!/usr/bin/env bash
#
#######################################
### FPGA Install Helper             ###
### for Quartus Prime Lite (23.1.1) ###
#######################################
#
# Author: Johannes Hüffer
# Date: 15.11.2024
# Version: 0.1
#
# Automated postinstall-setup for RHEL- and Debian-based
# Linux distros installing Intel FPGA components aiming post-installation
# support after the original installer did its incomplete job.
# Why? Because Intel for any reason (unlike on Windows) doesn't
# deliver a complete install on Linux systems and leaves its users
# with a kind of half-baked setup.
#
# ==> This skript aims to fix the hassels coming with this incomplete setup.
#
# After the regular install handeled by Intel, it ...
#
#   I)      Downloads the Quartus-installer (v. 23.1.1) directly from Intel;
#   II)     Launches the installer after the download has finished;
#   III)    Moves the Intel installation to the systems '/opt' directory;
#   IV)     Changes the necessary environment variables pointing to
#           this new directory;
#   V)      Creates desktop entries for Quartus and Questa such that
#           they could be launched from the desktop's menus easily;
#   VI)     Downloads nice icons for both Quartus and Questa from Github(*);
#   VII)    Creates new MIME-types for Quartus' and Questa's project files
#           allowing these file types to be opened directly in file managers;
#   VIII)   Creates the necessary udev-rules for Intel "USB-blaster" support;
#   IX)     Gives a short hint and summary to the end. :)
#
# (*) Credits to zayronxio who created this set!
#   ==> https://github.com/zayronxio/Elementary-KDE-Icons
#

SCRIPT_TITLE="Lazy FPGA Helper"
HELLO_MSG="\n\t\t~~~ Welcome to Jo's ${SCRIPT_TITLE} ~~~\n"
trap "echo -e \"\n\t\t~~~ ${SCRIPT_TITLE} quit. Bye for now! :) ~~~\n\"" EXIT

# 'lsb_release' command is too rare for serving as a reliable distro id tool.
# DISTRO="$(lsb_release -si)"
DISTRO="$(grep -oP '(?<=")[^ ]*' /etc/os-release | head -n 1)"

LOCAL_APPDIR="${HOME}/.local/share/applications"
LOCAL_MIMEDIR="${HOME}/.local/share/mime"
QUARTUS_DESKTOP_LAUNCHER="com.intel.QuartusPrimeLite_23.1.1.desktop"
QUESTA_DESKTOP_LAUNCHER="com.intel.QuestaVsim_23.1.1.desktop"

LOCAL_ICONDIR="${HOME}/.local/share/icons"
QUESTA_ICON="${LOCAL_ICONDIR}/elementary-kde/scalable/gtkwave.svg"
QUARTUS_ICON="${LOCAL_ICONDIR}/elementary-kde/scalable/marble.svg"

Q_INSTALLER="qinst-lite-linux-23.1std.1-993.run"
Q_INSTALLER_CHECKSUM="3b09df589ff5577c36af02a693a49d67d7e692ff"
Q_INSTALLER_URL="https://downloads.intel.com/akdlm/software/acdsinst/23.1std.1/993/qinst/${Q_INSTALLER}"

G_ICON_REPO="https://github.com/zayronxio/Elementary-KDE-Icons.git"

TMP_SETUP_DIR="/tmp/fpga-setup"
Q_INSTALLER_LOCAL_URI="${TMP_SETUP_DIR}/${Q_INSTALLER}"

Q_DIRNAME="intelFPGA_lite"
Q_ROOTDIR="/opt/fpga_test/${Q_DIRNAME}"  # FIXME: Remove "/fpga_test" after testing!

# Color codes for text output
RED_BOLD="\e[1;31m"
YELLOW_BOLD="\e[1;33m"
GREEN_BOLD="\e[1;32m"
LIGHT_GREY="\e[37m"
GREY="\e[90m"
ENDCOLOR="\e[0m"


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
            "\t\t$*" >&2
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
    echo -e "\t\t$*"
}


### Check running kernel
#
function check_platform() {
    [ "$(uname)" == "Linux" ] ||\
    (echo "  /!\\ This script only works on GNU+Linux!" &&\
    return 1)
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
            err "Sorry, your login shell \"${SHELL}\" is not supported by ${SCRIPT_TITLE}!"
            info "Please use ZSH or BASH instead.\n"\
                "\t ==> I.e. by issuing \"chsh $(which bash)\" you can switch easily :)\n"
            return 1
            ;;
    esac
}


### Check distribution
#
function check_distro() {
    case "${DISTRO}" in
        Fedora|Ubuntu)
            ok "Running on ${DISTRO}."
            return 0
            ;;
        *)
            warn "${SCRIPT_TITLE} has not been tested to work with ${DISTRO}."
            info " ==> You may proceed, but please don't expect things to work overall smoothly!"
            ask_for_cancel
            ;;
    esac
}


### Determine which desktop environment is used
#
function check_desktop() {
    case "${XDG_CURRENT_DESKTOP}" in
        GNOME)
            ok "Desktop environment is Gnome."
            return 0
            ;;
        *)
            warn "${SCRIPT_TITLE} could work on ${XDG_CURRENT_DESKTOP} desktop, but has not been tested yet!"
            info " ==> Proceed if you like tinkering and are seasoned with your desktop environment!"
            ask_for_cancel
            ;;
    esac
}


### Ask if script should cancel
#
function ask_for_cancel() {
    prompt="$1"
    [ -z "${prompt}" ] && prompt="Is this okay?"
    read -p "${prompt} [y/N]: " choice
            
    case "${choice}" in
        y|Y|yes|Yes|YES)
            info "Moving on, but without guarantee ..."
            return 0
            ;;
        *)
            info "Cancelled on your decision.\n"\
                "\t\t==> Feel free to improve ${SCRIPT_TITLE} :)\n"
            return 1
            ;;
    esac
}


### Verify dependencies on curl and git
#
function check_deps() {
    git_path="$(which git)"
    curl_path="$(which curl)"
    [ -f "${git_path}" ] &&\
    ok "Git installed." ||\
    (err "Git not found!" &&\
    info " ==> Please install Git first and run this skript again." &&\
    return 1)
    [ -f "${curl_path}" ] &&\
    ok "Curl installed." ||\
    (err "Curl not found!" &&\
    info " ==> Please install Curl first and run this skript again." &&\
    return 1)
}


### Check if current user is able to gain elevated privileges
#
function check_sudo() {
    case "${DISTRO}" in
        Ubuntu|Debian|"Linux Mint"|LMDE|elementaryOS)
            sudoers_group="sudo"
            ;;
        Fedora|RHEL|openSUSE)
            sudoers_group="wheel"
            ;;
        *)
            # If we are going off-road entirely ^^
            warn "Sorry, not knowing sudoers group on ${DISTRO}!"
            info " ==> Only answer 'yes' if you know that for your distro.\n"\
                "\t\t Otherwise, ${SCRIPT_TITLE} will fail to make Quartus ready for use!\n"
            ask_for_cancel "Are you really sure having sudo access?"
            ;;
    esac

    # User must not be root
    if [ "${USER}" == "root" ]; then
        err "Running as root!"
        info "This is highly discouraged, as it puts your system to unnecessary risks!\n"\
            "\t\t ==> Please login as a regular user having access to sudo and try again."
        return 1
    fi

    if [ ! -z "${sudoers_group}" ]; then
        [ "$(id -Gn | grep -c "${sudoers_group}")" > /dev/null ] &&\
        ok "Current user \"${USER}\" may gain elevated permissions." ||\
        (err "Sorry, user ${USER} does not have sufficient permissions to run ${SCRIPT_TITLE}!" &&\
        info "Please make sure you may gain root privileges first, then try again.\n"\
            "\t\t ==> Otherwise please contact your system administration." &&\
        return 1)
    else
        info "Relying on your answer!\n"\
            "\t\t ==> If things don't work out later on, don't cry. You have been warned ;)"
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
    # ping -c 3 1.1.1.1 2>&1 > /dev/null
    # For any reason, the above statement doesn't mute ping's output,
    # but this awful solution works:
    ping -c 3 1.1.1.1 2> /dev/null > /dev/null

    if [ "$?" -eq 0 ]; then
        ok "Internet connected."
        info "Looking out for ${service_url} ..."
        http_response="$(curl -sI "${service_url}" | head -n 1 | grep -so [1-5][0-9][0-9])"

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
                return 1
                ;;
        esac
    else
        err "Sorry, no internet connection!"
        info "At least no echo from Cloudflare's DNS after three attempts."
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
    service_domain="$(echo "${download_url}" | grep -oP '^(https?://[^/]+)')"

    download_dir="${local_uri%/*}"
    download_file="$(basename "${local_uri}")"
    is_webresource_avail "${download_url}"

    if [ "$?" -eq 0 ]; then
        if [ ! -d "${download_dir}" ]; then
            info "Creating ${download_dir} ..."
            mkdir -p "${download_dir}"
        fi

        info "Now downloading from \"${service_domain}\" ...\n"
        curl -L -o "${local_uri}" "${download_url}"

        if [ "$?" -eq 0 ]; then
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
function download_qinstaller() {
    download "${Q_INSTALLER_URL}" "${Q_INSTALLER_LOCAL_URI}"
}


### Clone icon repository from Github to user's icon dir
#
function setup_icons() {
    if [ ! -d "${LOCAL_ICONDIR}/elementary-kde" ]; then
        is_webresource_avail "${G_ICON_REPO}" &&\
        mkdir -p "${LOCAL_ICONDIR}" &&\
        info "Please wait, downloading icon set from Github ..." &&\
        git clone "${G_ICON_REPO}" "${LOCAL_ICONDIR}/elementary-kde" 2> /dev/null &&\
        ok "Icons have been set up, yay :)" ||\
        (err "Something went wrong during icon setup! :/" &&\
        return 1)
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
        if [ "$(sha1sum "${local_uri}" 2> /dev/null | grep -i "${sha1_checksum_expected}")" 2>&1 > /dev/null ]; then
            ok "\"${file_to_verify}\" matches expected checksum and seems intact :)"
            return 0
        else
            warn "Caution: \"${local_uri}\"\n\t\tmay be corrupted and should not be used!"
            info " ==> If you received this message after a local installer file has been spotted,\n"\
                "\t\t  please delete that file first and run ${SCRIPT_TITLE} again :)"
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
    verify "${Q_INSTALLER_LOCAL_URI}" "${Q_INSTALLER_CHECKSUM}"
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
        q_filesize_bytes="$(du "${q_inst}" 2> /dev/null | grep -oP '^[0-9]+')"
        if [ "$?" -eq 0 ]; then
            [ "${q_filesize_bytes}" -ge 16000 ] &&\
            ok "Installer fits minimum file size (${q_filesize_bytes}B >= 16000B)." &&\
            Q_INSTALLER_LOCAL_URI="${q_inst}" ||\
            (warn "Installer candidate's file size is too small for being intact!" &&\
            info "Murmle, murmle! Trying to download from Intel instead ..." &&\
            download_qinstaller)
        else
            err "Could not determine the file size (maybe this is a permission issue)!"
            info "Skip. Trying to download from Intel instead ..."
            download_qinstaller
        fi
    else
        info "No Quartus installer seems present on your system.\n"\
            "\t\tTrying to download it from Intel ..."
        download_qinstaller
    fi
}


### Check if user already got a license key for Questa Vsim
#
function locate_qlicense() {
    Q_LICENSE_LOCAL_URI="$(find "${HOME}" -maxdepth 3 -name LR-*_License.dat -type f 2> /dev/null | head -n 1)"
    [ -f "${Q_LICENSE_LOCAL_URI}" ] &&\
    ok "Found license key for Questa at \"${Q_LICENSE_LOCAL_URI}\"." ||\
    (err "Could not find any license key for Questa." &&\
    info "If you are intending to run Questa, this will be required!\n"\
        "\t\tIn case you have one, ideally place it inside a hidden\n"\
        "\t\tfolder in your home dir (i.e. \"${HOME}/.licenses/\").\n\n"\
        "\t\t ==> IMPORTANT: Your license can only be found if\n"\
        "\t\t  it has its default name (i.e. \"LR-123456_License.dat\")!\n\n" &&\
    read -p "Got it! [Enter]: " gotit;
    Q_LICENSE_LOCAL_URI="/Put/path/to/Questa/license/here!")
}


### Launch the actual Quartus installer
#
function run_qinstaller() {
    echo ""
    info "PLEASE READ CAREFULLY:\n"\
        "\tAt next, the Intel Quartus installer will be launched.\n"\
        "\tYou can use it as you'd regularly do, choosing the FPGA components you need.\n\n"\
        "\tIMPORTANT: Please, leave the install paths and any related settings at their defaults.\n"\
        "\t ==> Otherwise, ${SCRIPT_TITLE} might not be able to find the\n"\
        "\t  directory containing Quartus, preventing post-install assistance!\n\n"\
        "\t ==> Make sure to select the checkbox regarding Intel's EULA!\n"\
        "\t  If for some reason Quartus installer doesn't do anything after downloading and verifying your\n"\
        "\t  selected components, please click the \"Download\" button again. This will launch the tasks.\n\n"\
        "\t ==> After confirming \"OK\" when Quartus installer tells it finished, just click on \"Close\"\n"\
        "\t  at the lower right corner of the installer's main window.\n"\
        "\t  Once Quartus installer quit, ${SCRIPT_TITLE} will move on and tries to do all the rest for you :)\n"

    read -p 'Got it! [Enter]: ' gotit
    info "Making installer executable first ..."
    chmod +x "${Q_INSTALLER_LOCAL_URI}"
    info "Please wait, launching Quartus installer. Continue at its window!\n"
    "${SHELL}" -c "${Q_INSTALLER_LOCAL_URI}"
}


### Move Quartus' root dir to another (and more adequate) place
#
function relocate_qrootdir() {
    q_dir="$(find "${HOME}" -name "${Q_DIRNAME}" -type d 2> /dev/null | head -n 1)"

    if [ -d "${q_dir}" ]; then
        info "Creating Quartus' root directory ..."
        sudo mkdir -p "${Q_ROOTDIR}" &&\
        info "Please wait a moment while moving ${q_dir} to ${Q_ROOTDIR}/ ..." &&\
        sudo mv "${q_dir}"/* "${Q_ROOTDIR}/" &&\
        info "Making root the owner of Quartus ..." &&\
        sudo chown -R root:root "${Q_ROOTDIR}" &&\
        ok "Successfully relocated Quartus." ||\
        (err "Something went wrong moving Quartus to \"${Q_ROOTDIR}/\"!" &&\
        return 1)
    else
        err "Could not find \"${Q_DIRNAME}\" program folder!"
        info " ==> Most likely, Quartus installer has just quit without installing anything."
        return 1
    fi
}


### Create a desktop file for Quartus
#
function create_quartus_launcher() {
    echo -e "[Desktop Entry]"\
            "\nVersion=1.0"\
            "\nType=Application"\
            "\nName=Quartus"\
            "\nTerminal=false"\
            "\nExec=${Q_ROOTDIR}/23.1std/quartus/bin/quartus --64bit %f"\
            "\nComment=Intel Quartus Prime Lite 23.1.1"\
            "\nIcon=${QUARTUS_ICON}"\
            "\nCategories=Education;Development;Programming;"\
            "\nMimeType=application/x-qpf"\
            "\nKeywords=intel;fpga;ide;quartus;prime;lite;"\
            "\nStartupWMClass=quartus"\
    > "${LOCAL_APPDIR}/${QUARTUS_DESKTOP_LAUNCHER}" &&\
    ok "Created Quartus launcher at ${LOCAL_APPDIR}/${QUARTUS_DESKTOP_LAUNCHER}" ||\
    (err "Failed to create desktop launcher for Quartus!" &&\
    return 1)
}


### Create a desktop file for Questa
#
function create_questa_launcher() {
    echo -e "[Desktop Entry]"\
            "\nVersion=1.0"\
            "\nType=Application"\
            "\nName=Questa"\
            "\nTerminal=false"\
            "\nExec=env LM_LICENSE_FILE=\"${Q_LICENSE_LOCAL_URI}\""\
            "${Q_ROOTDIR}/23.1std/questa_fse/bin/vsim -gui %f"\
            "\nComment=Intel Questa Vsim (Prime Lite 23.1.1)"\
            "\nIcon=${QUESTA_ICON}"\
            "\nCategories=Education;Development;Programming;"\
            "\nMimeType=application/x-mpf;"\
            "\nKeywords=intel;fpga;ide;simulation;model;vsim;"\
            "\nStartupWMClass=Vsim"\
    > "${LOCAL_APPDIR}/${QUESTA_DESKTOP_LAUNCHER}" &&\
    ok "Created Questa launcher at ${LOCAL_APPDIR}/${QUESTA_DESKTOP_LAUNCHER}" ||\
    (err "Failed to create desktop launcher for Questa!" &&\
    return 1)
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
    info "Updating Quartus' environment variables in ${shellrc} ..."
    sed -i.old '/QSYS_ROOTDIR/d' "${shellrc}" 2> /dev/null
    sed -i '/LM_LICENSE_FILE/d' "${shellrc}" 2> /dev/null
    echo -e "\n#Intel FPGA environment (Quartus Prime Lite)"\
            "\nexport LM_LICENSE_FILE='${Q_LICENSE_LOCAL_URI}'"\
            "\nexport QSYS_ROOTDIR='${Q_ROOTDIR}/23.1std/quartus/sopc_builder/bin'"\
    >> "${shellrc}" &&\
    ok "Updated Quartus' environment variables." ||\
    (err "Someting went wrong when trying to update Quartus' environment variables!" &&\
    return 1)
}


### Create udev-rules for USB-blaster support
#
function create_udevrules() {
    udev_rulepath="/etc/udev/rules.d"
    udev_file="51-usbblaster.rules"
    udev_local_uri="${udev_rulepath}/${udev_file}"
    info "Creating new udev rules for USB-blaster ..."
    echo -e "SUBSYSTEM==\"usb\", ATTRS{idVendor}==\"09fb\", ATTRS{idProduct}==\"6001\", MODE=\"0666\""\
        "\nSUBSYSTEM==\"usb\", ATTRS{idVendor}==\"09fb\", ATTRS{idProduct}==\"6002\", MODE=\"0666\""\
        "\nSUBSYSTEM==\"usb\", ATTRS{idVendor}==\"09fb\", ATTRS{idProduct}==\"6003\", MODE=\"0666\""\
        "\nSUBSYSTEM==\"usb\", ATTRS{idVendor}==\"09fb\", ATTRS{idProduct}==\"6010\", MODE=\"0666\""\
        "\nSUBSYSTEM==\"usb\", ATTRS{idVendor}==\"09fb\", ATTRS{idProduct}==\"6810\", MODE=\"0666\""\
    | sudo tee "${udev_local_uri}" 2>&1 > /dev/null &&\
    ok "Rules have been added." ||\
    (err "Failed to create udev rules at \"${udev_local_uri}\"!" &&\
    return 1)
}


### Create new MIME-type
#
# 'new_type': Base of both MIME-type's identifier and file extension
# (i.e. 'x-qpf' resp. '.qpf' for Qaurtus project files);
# 'comment': Short description (i.e. 'Quartus project file');
# 'gen_iconname': Determines what icon the desktop will choose for such files.
#
function create_mimetype() {
    new_type="$1"
    comment="$2"
    gen_iconname="$3"

    info "Creating MIME-type for \"${comment}\" ..."
    echo -e "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"\
            "\n<mime-info xmlns=\"http://www.freedesktop.org/standards/shared-mime-info\">"\
            "\n\t<mime-type type=\"application/x-${new_type}\">"\
            "\n\t\t<comment>${comment}</comment>"\
            "\n\t\t<generic-icon name=\"${gen_iconname}\"/>"\
            "\n\t\t<glob pattern=\"*.${new_type}\"/>"\
            "\n\t</mime-type>"\
            "\n</mime-info>"\
    > "${LOCAL_MIMEDIR}/packages/application-x-${new_type}.xml" &&\
    ok "Added new MIME-type." ||\
    (err "Sorry, something went wrong when trying to create new MIME-type!" &&\
    return 1)
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
    update-mime-database "${LOCAL_MIMEDIR}" 2> /dev/null &&\
    update-desktop-database "${LOCAL_APPDIR}" 2> /dev/null &&\
    ok "Desktop got it :)" ||\
    (err "Troubles when trying to instruct desktop!" &&\
    return 1)
}


### The setup process
#
function run_preinstaller() {
    check_platform &&\
    check_shell &&\
    check_distro &&\
    check_desktop &&\
    check_deps &&\
    check_sudo &&\
    locate_qlicense &&\
    locate_qinstaller &&\
    verify_qinstaller &&\
    run_qinstaller &&\
    run_postinstaller
}


### Run actual post-install assistant
#
function run_postinstaller() {
    echo ""
    info "PERFORMING POST-INSTALLATION:\n"\
        "\tSome of the following steps you will need to confirm with your password.\n"\
        "\tPlease enter it if prompted for.\n"\
        "\t ==> On most systems, nothing is echoed due to security reasons!\n"

    relocate_qrootdir &&\
    (create_qlaunchers;
    create_qmimetypes;
    setup_icons;
    update_envvars;
    create_udevrules)
    
    echo ""
    info "If you can see only green \"OK\" feedback below post-install headline\n"\
        "\t\tyou are now ready to use your Intel FPGA suite :)\n"\
        "\t\t ==> Otherwise, please investigate the error messages\n"\
        "\t\t  and fix the corresponding parts manually."
}


### RUN THIS SKRIPT ###
clear
echo -e "${HELLO_MSG}"
run_preinstaller