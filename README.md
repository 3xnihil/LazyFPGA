# LazyFPGA

## (Nearly) fully automated setup for Intel FPGA supporting RHEL- and Debian-based GNU+Linux distros
This helper script aims to greatly improve user experience of the offical Quartus Prime Lite installer
by automatically doing all the stuff you'd still had to fix after install of which Intel forgot about.

### Requirements
* GNU+Linux distro based on RHEL or Debian (*Fedora Workstation and Ubuntu recommended*).
* Zsh or Bash as login shell.
* Further requirements for Quartus Prime Lite [mentioned by Intel](https://www.intel.com/content/www/us/en/support/programmable/support-resources/design-software/os-support.html).
* If you intend to run Questa (Vsim), a [license key file](https://licensing.intel.com).

### Status quo
* The original installer does an incomplete job.
* Intel does not deliver neither a package nor a fully working installer for Linux distros (unlike on Windows).
* By default, Linux users are left behind with a less than half-baked setup and have to tinker around.

### How it helps
LazyFPGA aims to fill this gap. It saves the hassels coming with an incomplete setup.
Sometimes, even Linux users like being lazy. Therefore, this script ...

1. Searches for an installer already stored locally on your machine
2. Downloads the Quartus installer (v23.1.1) directly [from Intel](https://www.intel.com/content/www/us/en/software-kit/825277/intel-quartus-prime-lite-edition-design-software-version-23-1-1-for-linux.html) if there is none
3. Verifies and launches the installer after it has spotted any (either the just downloaded or local one)
3. Moves the FPGA suite directory made by the Intel installer to the system's `/opt` directory
4. Changes the necessary environment variables required by Quartus and adds its binary dir to your `$PATH`
5. Creates fully working [1] desktop launchers for both Quartus and Questa embedding them like any other application
6. Downloads nice icons [2] for both Quartus and Questa
7. Creates new Mime-types for Quartus' and Questa's project files (*i.e. allowing these file types to be opened directly in file managers*)
8. Creates necessary udev rules for Intel "USB-blaster" support, allowing programmers to interact correctly
9. Finally presents an install summary to the end.

### Be intuitive
You can use LazyFPGA script right away without reading the Readme. The script will guide you through the process,
as long as you are patient enough to read some text lines ;)

### Additional features
* Patching: LazyFGPA can patch an install which it has applied previously.
* If it detects a Quartus root directory under `/opt/intelFPGA_lite`, it will ask whether to perform a reinstall or patching.
* Patching primarily addresses installs which have been performed in a hurry without a license key file for Questa.
* As this aims to be a script supporting laziness, the impatient of us will appreciate LazyFPGA's ability to update the `$LM_LICENSE_FILE` environment variable.

### How to use
1. Make script executable first: `chmod +x lazyfpga.sh`
2. Just run it by: `./lazyfpga.sh`

**Important**: *Do not run LazyFPGA as root!* If uses `sudo` whenever root privileges are required. 

### Roadmap
Currently, LazyFPGA has its focus on *installing* Intel's FPGA suite. The patching feature mentioned above will likely be extended in future, offering users to either install or patch their setup right at the script's startup.
However, you are welcome to improve this script or to make suggestions.

### Legal notes
This script is not associated to Intel company in any way and is *by itself* free software (see license). Please note that Questa and Quartus are both proprietary software owned by Intel. LazyFPGA only downloads the Quartus installer from Intel's servers, but will never contain it.

### Final words
*"Even Linux enthusiasts sometimes don't have any objections to simply sitting back and enjoy things getting done for them."* (Developer of LazyFPGA)

#### Foot notes
1. The Intel installer offers such an option, but the resulting launcher files simply do not work this way.
2. Credits to [zayronxio](https://github.com/zayronxio/Elementary-KDE-Icons) who created the icon set!
