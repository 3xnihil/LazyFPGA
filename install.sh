### FPGA Install Helper
### for Quartus Prime Lite (23.1.1)
#
# Author: Johannes Hüffer
# Date: 15.11.2024
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
#   I)      Downloads the Quartus-installer (v. 23.1) directly from Intel;
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
#   IX)     Checks if everything is there and gives a summary to the end. :)
#
# (*) Credits to "zayronxio" who created them!
#   ==> https://github.com/zayronxio/Elementary-KDE-Icons
#

DISTRO="$(lsb_release -si)"

LOCAL_APPDIR="${HOME}/.local/share/applications"
QUARTUS_DESKTOP_LAUNCHER="com.intel.QuartusPrimeLite_23.1.1.desktop"
QUESTA_DESKTOP_LAUNCHER="com.intel.QuestaVsim_23.1.1.desktop"

LOCAL_ICONDIR="${HOME}/.local/share/icons"
QUESTA_ICON="gtkwave.svg"
QUARTUS_ICON="marble.svg"

Q_INSTALLER="qinst-lite-linux-23.1std.1-993.run"
Q_INSTALLER_CHECKSUM="3b09df589ff5577c36af02a693a49d67d7e692ff"
I_PORTAL_URL="https://cdrdv2.intel.com"
Q_INSTALLER_URL="${I_PORTAL_URL}/v1/dl/getContent/825277/825299?filename=${Q_INSTALLER}"

TMP_DOWNLOAD_DIR="/tmp/intel-setup"
Q_INSTALLER_ABS_PATH="${TMP_DOWNLOAD_DIR}/${Q_INSTALLER}"

Q_DIRNAME="intelFPGA_lite"
Q_ROOTDIR="/opt/fpga_test"  # FIXME: Change to /opt after testing!

# By default, the license key file is obtained by this setup script ('locate_license_key').
# LICENSE_FILE="LR-202898_License.dat"
# LICENSE_ABS_PATH="${HOME}/.licenses/intel/${LICENSE_FILE}"

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
            "${GREY}]${ENDCOLOR}"\
            "\t${LIGHT_GREY}$*${ENDCOLOR}" >&2
}


### Success messages also to STDERR (2)
#
function ok() {
    echo -e "${GREY}[${ENDCOLOR}"\
            "${GREEN_BOLD}OK${ENDCOLOR}"\
            "${GREY}]${ENDCOLOR}"\
            "\t\t${LIGHT_GREY}$*${ENDCOLOR}" >&2
}


### Warning messages to STERR (2)
#
function warning() {
    echo -e "${GREY}[${ENDCOLOR}"\
            "${YELLOW_BOLD}WARNING${ENDCOLOR}"\
            "${GREY}]${ENDCOLOR}"\
            "\t${LIGHT_GREY}$*${ENDCOLOR}" >&2
}


### Info messages to STOUT (1)
#
function info() {
    echo -e "\t\t${LIGHT_GREY}$*${ENDCOLOR}"
}


### Check shell compatibility
#
# Only BASH and ZSH are supported.
#
function check_shell() {
    case "$(basename ${SHELL})" in
        bash|zsh)
            ok "Your shell is »${SHELL}«."
            return 0
            ;;
        *)
            err "Sorry, your shell »${SHELL}« is not supported by this script!"
            info "Please use ZSH or BASH instead.\n"\
                "\t ==> By issuing 'chsh /path/to/shell' you can switch easily :)\n"
            return 1
            ;;
    esac
}


### Check distribution
#
function check_distro() {
    case "${DISTRO}" in
        Fedora|Debian|Ubuntu)
            ok "Running on ${DISTRO}."
            return 0
            ;;
        *)
            warning "${DISTRO} has not been tested to work with this script."
            info "You may proceed, but at no guarantee that it will work!"

            if [ "$(basename ${SHELL})" == "bash" ]; then
                read -p "Is this okay? [y/N]: " choice
            elif [ "$(basename ${SHELL})" == "zsh" ]; then
                read "choice?Is this okay? [y/N]: "
            fi

            case "${choice}" in
                y|Y|yes|Yes|YES)
                    info "Continuing this helper script without guarantee ..."
                    return 0
                    ;;
                *)
                    info "Cancelled on your decision.\n"\
                         "\t\t==> See you!\n"
                    return 1
                    ;;
            esac
            ;;
    esac
}


### Check if current user is able to gain elevated privileges
#
function check_sudo() {
    case "${DISTRO}" in
        Debian|Ubuntu|"Linux Mint")
            sudoers_group="sudo"
            ;;
        Fedora|RHEL|openSUSE)
            sudoers_group="wheel"
            ;;
    esac

    [ "$(id -Gn | grep -c ${sudoers_group})" > /dev/null ] &&\
    ok "Current user »${USER}« is allowed to perform adminstrative tasks." ||\
    (err "Sorry, user ${USER} does not have sufficient permissions to run this script!" &&\
    info "Please make sure you may gain root privileges first, then try again.\n"\
        "\t\t==> Otherwise please contact your system administration." &&\
    return 1)
}


### Check whether internet and desired domain can be connected to
#
function is_service_available() {
    service_url="$1"
    info "Checking internet connectivity ..."

    if [ ! "$(ping -c 5 1.1.1.1 2>&1 > /dev/null)" ]; then
        ok "Internet connected."
        info "Looking out for ${service_url} ..."
        http_response="$(curl -sI ${service_url} | head -n 1 | grep -so [1-5][0-9][0-9])"

        # HTTP responses between 200-299 are fine, but
        # redirections (300-399) aren't accepted here due to security reasons:
        if [ "$(echo ${http_response} | grep -c [2][0-9][0-9])" -eq 1 ]; then
            ok "Connected to ${service_url}"
            info "HTTP status: ${http_response}"
            return 0
        else
            err "Trouble connecting to ${service_url}!"
            info "HTTP status: ${http_response}"
            return 1
        fi
    else
        err "Sorry, no internet connection!"
        info "At least no echo from Cloudflare's DNS after five attempts."
        return 1
    fi
}


### Download a file from a given URL
#
# CAUTION: ${uri} must contain an absolute path to a file!
#   Examples: "/home/user/foo.txt", "/tmp/foo/bar.png"
#
# Usage: start_download "https://example.com/file.txt" "/path/to/target/file.txt"
#
function start_download() {
    url="$1"
    uri="$2"
    service_domain="$(echo ${url} | grep -oP '^(https?://[^/]+)')"

    download_dir="${uri%/*}"
    download_file="$(basename ${uri})"
    is_service_available "${service_domain}"

    if [ "$?" ]; then
        if [ ! -d "${download_dir}" ]; then
            info "Creating ${download_dir} ..."
            mkdir -p "${download_dir}"
        fi

        info "Now downloading ${url} ...\n"
        curl -L -o "${uri}" "${url}"
        # Only for debugging:
        curl_exit_code="$?"
        # info "Curl exit code: ${curl_exit_code}"

        if [ "${curl_exit_code}" ]; then
            echo ""
            ok "Download of »${download_file}« has finished."
            return 0
        else
            err "Download has failed :/"
            info "Maybe network connection has been interrupted."
            return 1
        fi
    else
        err "Sorry, download not possible :/"
        return 1
    fi
}


### Verify Intel's installer script after downloading
#
function verify_download() {
    abs_filepath="$1"
    sha1_checksum_expected="$2"
    file_to_verify="$(basename ${abs_filepath})"

    if [ -f "${abs_filepath}" ]; then
        ok "File found at »${abs_filepath}«."
        info "Checking file integrity ..."
        if [ "$(sha1sum ${abs_filepath} | grep -i ${sha1_checksum_expected})" 2>&1 > /dev/null ]; then
            ok "»${file_to_verify}« matches expected checksum and seems intact :)"
            return 0
        else
            warning "Caution: »${file_to_verify}« may be corrupted and should not be used!"
            return 1
        fi
    else
        err "Not able to verify! »${abs_filepath}« not present."
        return 1
    fi
}


### Check if user already got a license key for Questa Vsim
#
function locate_license_key() {
    LICENSE_ABS_PATH="$(find ${HOME} -maxdepth 3 -name *_License.dat -type f 2> /dev/null | head -n 1)"
    [ -f "${LICENSE_ABS_PATH}" ] &&\
    ok "Found license key for Questa at »${LICENSE_ABS_PATH}«." ||\
    (err "Could not find any license key for Questa." &&\
    info "If you are intending to run Questa, this will be required!\n"\
        "\t\tIn case you have one, ideally place it inside a hidden\n"\
        "\t\tfolder in your home dir (i.e. »${HOME}/.licenses/«).\n"\
        "\t ==> IMPORTANT: Your license can only be found if it has its default name!\n"\
        "\t (i.e. »LR-123456_License.dat«)\n" &&\
    return 1)
}


### Launch the actual Intel Quartus installer
#
function run_quartus_installer() {
    clear
    info "PLEASE NOTICE:\n"\
        "\tAt the next step, the Intel Quartus installer will be launched.\n"\
        "\tYou can use it as you'd regularly do, choosing the Quartus components you need.\n\n"\
        "\tIMPORTANT: Please, leave the install paths and any related settings at their defaults!\n"\
        "\t ==> Otherwise, this helper script won't be able to find the\n"\
        "\t     program's parts which would prevent post-install assistance!\n\n"\
        "\tAfter the installer has finished to download all selected components, this script will\n"\
        "\tcontinue and do all the rest for you as soon as the Quartus installer has done its job.\n"\
        "\t ==> First, make sure to select the checkbox regarding Intel's EULA!\n"

    if [ "$(basename ${SHELL})" == "bash" ]; then
        read -p "Got it! [Enter]: " choice
    elif [ "$(basename ${SHELL})" == "zsh" ]; then
        read "choice?Got it! [Enter]: "
    fi

    info "Making installer executable first ..."
    chmod +x "${Q_INSTALLER_ABS_PATH}"
    info "Please wait, launching Quartus installer. Continue at its window!\n"
    "${SHELL}" -c "${Q_INSTALLER_ABS_PATH}"
    #return "$?"     # Exit with Quartus installer's status ('0' if successful ;))
}


### The setup process
#
function prepare_install() {
    check_shell &&\
    check_distro &&\
    check_sudo &&\
    locate_license_key &&\
    start_download "${Q_INSTALLER_URL}" "${Q_INSTALLER_ABS_PATH}" &&\
    verify_download "${Q_INSTALLER_ABS_PATH}" "${Q_INSTALLER_CHECKSUM}" &&\
    run_quartus_installer &&\
    run_postinstall
}


### Run actual post-install assistant
#
function run_postinstall() {
    info "Starting post-installation.\n"\
        "\tSome of the following steps you will need to confirm with your password.\n"\
        "\tPlease enter it if prompted for.\n"\
        "\t ==> On most systems, nothing is echoed for security reasons!\n"

    relocate_quartus_rootdir &&\
    create_quartus_desktop_launcher &&\
    create_questa_desktop_launcher &&\
    # TODO:
    # fetch_icons &&\
    update_environment_vars &&\
    # create_mimetypes &&\ # TODO - optional
    create_udev_usbblaster_rules
}


### Move Quartus' root dir to another (and more adequate) place
#
function relocate_quartus_rootdir() {
    q_dir="$(find ${HOME} -name ${Q_DIRNAME} -type d | head -n 1)"

    if [ -d "${q_dir}" ]; then
        info "Moving ${q_dir} to ${Q_ROOTDIR} ..."
        sudo mv "${q_dir}" "${Q_ROOTDIR}/" &&\
        info "Making root the owner of Quartus ..." &&\
        sudo chown -R root:root "${Q_ROOTDIR}/${Q_DIRNAME}" &&\
        ok "Successfully relocated Quartus." ||\
        (err "Something went wrong moving Quartus to »${Q_ROOTDIR}/«!" &&\
        return 1)
    else
        err "Could not find »${Q_DIRNAME}« program folder!"
        info "Please make sure it is stored inside »${HOME}/«."
        return 1
    fi
}


### Create a desktop file for Quartus
#
function create_quartus_desktop_launcher() {
    echo -e "[Desktop Entry]"\
            "\nVersion=1.0"\
            "\nType=Application"\
            "\nName=Quartus"\
            "\nTerminal=false"\
            "\nExec=${Q_ROOTDIR}/${Q_DIRNAME}/23.1std.1/quartus/bin/quartus --64bit %f"\
            "\nComment=Intel Quartus Prime Lite 23.1.1"\
            "\nIcon=${HOME}/.local/share/icons/quartus/marble.svg"\
            "\nCategories=Education;Development;"\
            "\nMimeType=application/x-qpf;application/x-qsf;application/x-qws;"\
            "\nKeywords=intel;fpga;ide;quartus;prime;lite;"\
            "\nStartupWMClass=quartus"\
    > "${LOCAL_APPDIR}/${QUARTUS_DESKTOP_LAUNCHER}" &&\
    ok "Created Quartus launcher at ${LOCAL_APPDIR}/${QUARTUS_DESKTOP_LAUNCHER}" ||\
    (err "Failed to create desktop launcher for Quartus!" &&\
    return 1)
}


### Create a desktop file for Questa
#
function create_questa_desktop_launcher() {
    echo -e "[Desktop Entry]"\
            "\nVersion=1.0"\
            "\nType=Application"\
            "\nName=Questa"\
            "\nTerminal=false"\
            "\nExec=env LM_LICENSE_FILE=${LICENSE_ABS_PATH} "\
            "${Q_ROOTDIR}/${Q_DIRNAME}/23.1std.1/questa_fse/bin/vsim -gui %f"\
            "\nComment=Intel Questa Vsim (Prime Lite 23.1.1)"\
            "\nIcon=${HOME}/.local/share/icons/quartus/gtkwave.svg"\
            "\nCategories=Education;Development;"\
            "\nMimeType=application/x-ini;application/x-mpf;"\
            "\nKeywords=intel;fpga;ide;simulation;model;vsim;"\
            "\nStartupWMClass=Vsim"\
    > "${LOCAL_APPDIR}/${QUESTA_DESKTOP_LAUNCHER}" &&\
    ok "Created Questa launcher at ${LOCAL_APPDIR}/${QUESTA_DESKTOP_LAUNCHER}" ||\
    (err "Failed to create desktop launcher for Questa!" &&\
    return 1)
}


### Modify Questa's environment variables
#
# Intel's Questa installer automatically creates
# environment variables necessary for operation.
#  ==> Because they have to be changed if the
#   program's location changes, this is done by
#   this function.
#
function update_environment_vars() {
    shellrc="${HOME}/.$(basename ${SHELL})rc"
    info "Updating Quartus' environment variables in ${shellrc} ..."
    sed -i.old '/QSYS_ROOTDIR/d' "${shellrc}" &&\
    sed -i '/LM_LICENSE_FILE/d' "${shellrc}" &&\
    echo -e "\n#Intel FPGA environment (Quartus Prime Lite)"\
            "\nexport LM_LICENSE_FILE='${LICENSE_ABS_PATH}'"\
            "\nexport QSYS_ROOTDIR='${Q_ROOTDIR}/${Q_DIRNAME}/23.1std.1/quartus/sopc_builder/bin'"\
    >> "${shellrc}" &&\
    ok "Updated Quartus' environment variables." ||\
    (err "Someting went wrong when trying to update Quartus' environment variables!" &&\
    return 1)
}


### Create udev-rules for USB-blaster support
#
function create_udev_usbblaster_rules() {
    udev_rulepath="/etc/udev/rules.d"
    udev_file="51-usbblaster.rules"
    udev_abs_filepath="${udev_rulepath}/${udev_file}"
    info "Creating new udev rules for USB-blaster ..."
    echo -e "SUBSYSTEM==\"usb\", ATTRS{idVendor}==\"09fb\", ATTRS{idProduct}==\"6001\", MODE=\"0666\""\
        "\nSUBSYSTEM==\"usb\", ATTRS{idVendor}==\"09fb\", ATTRS{idProduct}==\"6002\", MODE=\"0666\""\
        "\nSUBSYSTEM==\"usb\", ATTRS{idVendor}==\"09fb\", ATTRS{idProduct}==\"6003\", MODE=\"0666\""\
        "\nSUBSYSTEM==\"usb\", ATTRS{idVendor}==\"09fb\", ATTRS{idProduct}==\"6010\", MODE=\"0666\""\
        "\nSUBSYSTEM==\"usb\", ATTRS{idVendor}==\"09fb\", ATTRS{idProduct}==\"6810\", MODE=\"0666\""\
    | sudo tee "${udev_abs_filepath}" > /dev/null &&\
    ok "Added udev rules for USB-blaster." ||\
    (err "Failed to create udev rules for USB-blaster!" &&\
    return 1)
}


###### MAIN ######
echo ""
info "*** Welcome to Jo's FPGA Helper ***\n"
#prepare_install
