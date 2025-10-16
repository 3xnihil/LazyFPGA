# LazyFPGA

## (Nearly) fully automated setup for Intel FPGA supporting RHEL- and Debian-based GNU+Linux distros
This helper script **aims to greatly improve user experience** of the **offical Quartus Prime Lite installer**
by automatically doing all the stuff you'd still had to fix after install of which Intel forgot about.

### Requirements
* **GNU+Linux distro based on RHEL or Debian** (*Fedora Workstation* and *Ubuntu* recommended).
* **ZSH or BASH as login shell**
* **Further requirements for Quartus Prime Lite [mentioned by Intel](https://www.intel.com/content/www/us/en/support/programmable/support-resources/design-software/os-support.html)**
* If you intend to run **Questa (Vsim), a [license key file](https://licensing.intel.com)**

### Status quo
* The **original installer** does an **incomplete job**
* **Intel** does not deliver **neither a package nor a fully working installer for Linux distros** (unlike on Windows)
* **By default, Linux users are left behind** with a less than half-baked setup and have to tinker around.

### How it helps
**LazyFPGA aims to fill this gap.** It saves the hassels coming with an incomplete setup.
Sometimes, even Linux users like being lazy.

**This script** ...

1. **Searches for an installer** already stored locally on your machine
2. **Downloads the Quartus installer** (v23.1.1) directly [from Intel](https://www.intel.com/content/www/us/en/software-kit/825277/intel-quartus-prime-lite-edition-design-software-version-23-1-1-for-linux.html) if there is none
3. **Verifies and launches the installer** after it has spotted any (either the just downloaded or local one)
4. **Moves the FPGA suite directory** made by the Intel installer to the system's `/opt` directory
5. **Changes the necessary environment variables** required by Quartus and adds its binary dir to your `$PATH`
6. **Creates fully working desktop launchers** for both Quartus and Questa embedding them like any other application [1]
7. **Downloads nice icons** for both Quartus and Questa [2]
8. **Creates new Mime-types** for Quartus' and Questa's project files (*i.e. allowing these file types to be opened directly from inside file managers*)
9. **Creates necessary udev rules** for Intel "USB-blaster" support, allowing programmers to interact correctly
10. **Can install license for Questa** afterwards and will update all of its environment variables
11. **Can just download Intel's installer only** (for download mode, macOS is supported too)

### Be intuitive
You can **use LazyFPGA script right away** without reading the Readme. The script will guide you through the process and give advice whenever anything does not work as it should.

### Additional features
* **Patching**: LazyFGPA can patch an install which it has applied previously, **addressing subsequent license installs**


* If detecting a Quartus root directory under `/opt/intelFPGA_lite`, it **will offer an automatic reinstall** which can be used i.e. to **repair broken installs**


* As this aims to be a script **supporting laziness**, the impatient of us will appreciate **LazyFPGA's** ability to do pretty **any of the stuff that's time-consuming and error-prone if done manually**

### Get ready
1. **Clone** this repo: `git clone https://github.com/3xnihil/LazyFPGA`


2. **Enter directory** and make script executable: `cd ./LazyFPGA && chmod +x lazyfpga.sh`


### How to use
`./lazyfpga.sh <-i | -p | -d <path> | -v | -h>`

#### Options
* `-i` **Download Quartus installer** (if not present) and **install it automatically along all important steps Intel forgot about**


* `-p` **Patch** present Quartus installation. **Use this if you hadn't had a license during initial installation.** Will install license key file found anywhere inside your home dir and update all Quartus environment variables accordingly.


* `-d <path>` **Only download Quartus installer** to the designated **path** (this won't do anything else). Works also on macOS if GNU grep is available.


* `-v` **Show version info** of this script


* `-h` **Show this help**

#### Please note
LazyFPGA utilizes `sudo` internally whenever root privileges are required. **Running as root is discouraged and not supported.**

### Roadmap
LazyFPGA is currently still limited when it comes to distro variety. Especially rolling release distros like openSUSE Tumbleweed or so-called "immutable" distros like Fedora Silverblue and other Atomic variants are not supported until now - either due to package conflicts (Quartus relies on older versions of *glibc* for example) or to the immutable nature of the OS itself, making a smooth integration more complicated.

ℹ️ To resolve these shortcomings, **LazyFPGA** will try to change its approach and **utilize Docker or Podman to containerize Quartus inside a standard Ubuntu setup. Stay tuned!**

### Development
However, **you are welcome to improve this script** or to **make suggestions** at any time! Feel free to make a pull request.

### Legal notes
This script is **not associated to Intel company in any way** and is *by itself* free software (see license). Please note that Questa and Quartus are both proprietary software owned by Intel. **LazyFPGA only downloads** the Quartus installer from Intel's servers, but **will never contain it.**

### Final words
*"Even Linux enthusiasts sometimes don't have any objections to simply sitting back and enjoy things getting done for them."* (Developer of LazyFPGA)

#### Foot notes
1. The Intel installer offers such an option, but the resulting launcher files simply cannot work this way ...
2. **Credits to [zayronxio](https://github.com/zayronxio/Elementary-KDE-Icons)** who created the icon set!
