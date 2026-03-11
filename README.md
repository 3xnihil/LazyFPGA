# Install Quartus Prime the lazy way

## Lazy FPGA Containerized: automated setup for Intel's FPGA suite, supporting a wide range of different GNU+Linux distributions
**This CLI tool aims to elevate user experience** of the offical **Quartus Prime Lite** FPGA software and its installer **to a new level** and enables to **run the FPGA suite on almost any GNU+Linux distro** of your choice.

### 🎯 Features

* 🐚 **100% Bash** shell code for native support
* 📦 **Containerized approach** for maximum flexibility and reliability
* 💡 **Utilizes [Distrobox](https://distrobox.it/)** as a frontend to **support both [Podman](https://podman.io/) and [Docker](https://www.docker.com/)**
* 🐧 **Supports distro freedom**
* 🪶 **Smooth operation** as containerization solves most compatibility issues


### ℹ️ Requirements

* **GNU+Linux distro** supporting and have **Podman** or **Docker** installed (1)
* **Distrobox** installed (2)
* **CPU featuring x86 architecture** with 64 bits
* **ZSH or BASH as login shell** (3)
* **Further requirements for Quartus Prime Lite [mentioned by Intel](https://www.intel.com/content/www/us/en/support/programmable/support-resources/design-software/os-support.html)**, but only regarding hardware limitations!
* If you intend to run **Questa (Vsim), a [license key file](https://licensing.intel.com)**

(1) *In case you don't have a certain preference yet, I recommend Podman.*\
(2) *It serves as a frontend and I'm sure you will get to love it independently from its purpose for Lazy FPGA Containerized, as it's very versatile.*\
(3) *Currently. This will be fixed soon, as it is only relevant if you want automatic integration of the FPGA CLI tools, too.*


### 🌱 Motivation

* The **original "installer" is entirely insufficient.** Unlike on Windows, on Linux it is limited to download Quartus' components and does a kind of preparation, but won't actually *install* all the stuff. **Making it usable Intel lets up to you ...**

* **Nor Intel provides a (closed-source) package for Linux distros.**

* **Information on how to make Quartus eventually work is spread across a bunch of different places** and mostly incomplete.

* **From scratch, you are limited to certain distros** (Ubuntu, RHEL) and versions

➡️ **By default, Linux users are left behind** with a less than half-baked setup, have to tinker around and **must fear their setup could break** if they upgrade their OS to a (more) recent version.


### 💡 How it helps

**Lazy FPGA Containerized solves these shortcomings.** It saves the hassels coming with an incomplete setup and missing/broken dependencies.

It puts all the information out there right into a single CLI tool, leveraging not only the install process, but your entire user experience:

* ✅ **Your FPGA suite now runs in its own environment**, unaffected by potentially breaking changes in your main OS.

* ✅ **Containerization extends support to so-called atomic distributions** as well like [Fedora Silverblue](https://fedoraproject.org/atomic-desktops/silverblue/) & Co.

* ✅ **Far improved portability** as you can easily migrate containers between systems.

Last, but not least, **Linux users value their freedom**. You are no longer tied to a certain distro only because a certain program might require that.


### Be intuitive

You can **use Lazy FPGA Containerized right away** without reading the Readme. The tool will guide you through the process and give advice whenever anything does not work as intended.


### Get ready

1. **Clone** this repo:
```
git clone https://github.com/3xnihil/LazyFPGA
```

2. **Enter directory** and make script executable:
```
cd ./LazyFPGA
chmod +x lazyfpga
```


### How to use

```
./lazyfpga [-s <setup-file>  Use custom Quartus setup file]
	[-l <license-key-file>  Provide Questa license]
	[-c <container-home-path>  Set custom container home]
	| [-u  Uninstall container and other components]
	| [-h  Show help] | [-v  Show version]
```

#### Available options

* *(none given)* **No options at all** - the lazy variant ;)\
Lazy FPGA Containerized tries to figure out configuration on its own:
  1) **Search locally for a Quartus setup file**. If none can be found in your home dir, it will download one from Intel automatically.\
  💡 For a different behaviour, you can use the `-s` option and specify a setup file manually.

  2) **Search locally for a Questa license key file** and update its path automatically if found one.\
  ⚠️ **Please keep in mind** that *you have to obtain such a key from Intel* if you need Questa!\
  Your key file *can only be found automatically* if it has its default name (like `LR-123456_License.dat`).\
  💡 In other cases, please use the `-l` option and specify the key manually!


* `-s <setup-file>` **Use a custom Intel setup file** for Quartus (with non-default file name) the auto-search cannot find


* `-l <license-key-file>` **Provide Questa license** key file (with non-default file name) the auto-search cannot find


* `-c <container-home-path>` **Change container home path** for the Quartus container


* `-u` **Uninstall present Quartus setup** and remove its desktop integration (container, container home, launchers, mimes, udev rules)


* `-v` **Show version info** of this script


* `-h` **Show this help**


#### Please note

LazyFPGA utilizes `sudo` internally whenever root privileges are required. **Running as root is discouraged and not supported.**


### 🚧 Roadmap

**Lazy FPGA Containerized** fixed the shortcomings of its predecessor, *LazyFPGA*. With its help you can install Intel's FPGA suite on any distro which supports one of the widely-known container providers Podman and Docker, utilizing the great Distrobox as a frontend - to make you even more independent in your decisions.

However, this first *containerized* version is not perfect. In a single point, it is currently less flexible than the script, namely *updating a license key for Questa*.

💡 **This will be fixed in future versions** by adding an entry-point script to the container image which will load license key files dynamically from a certain (and customizable) directory, making re-installs related to key file updates superfluous. **Stay tuned!**


### 🛠️ Development

However, **you are welcome to improve this tool** or to **make suggestions** at any time! Feel free to make a pull request.


### Legal notes

This script is **not associated to Intel company in any way** and is *by itself* free software (see license). Please note that Questa and Quartus are both proprietary software owned by Intel. **Lazy FPGA Containerized only downloads** the Quartus installer from Intel's servers at build time, but **will never contain it.**


### Final words

*"Even Linux enthusiasts sometimes don't have any objections to simply sitting back and enjoy things getting done for them."* (Developer of LazyFPGA)


### 🏆 Credits

* **Thanks to [zayronxio](https://github.com/zayronxio/Elementary-KDE-Icons)** who created the icon set used for the desktop launchers!
