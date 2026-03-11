#!/usr/bin/env bash
#
# Lazy FPGA USB-blaster Setup
#
# Author: Johannes Hüffer
# Begin of development: 29.11.2024
# Version: 0.1.0
# Copying: GPL-3.0-only
#

### Create udev-rules for USB-blaster support
#
function create_udevrules() {
	udev_rulepath="/etc/udev/rules.d"
	udev_file="51-usbblaster.rules"
	udev_uri="${udev_rulepath}/${udev_file}"
	info "Creating udev rules for USB-blaster ..."
	info " (i) Please enter your password if prompted for"

	(cat <<- EOF | sudo tee "${udev_uri}" > /dev/null &&\
	ok "Rules have been added") ||\
	(err "Failed to create udev rules at \"${udev_uri}\"!" &&\
	return 1)
		SUBSYSTEM=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6001", MODE="0666"
		SUBSYSTEM=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6002", MODE="0666"
		SUBSYSTEM=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6003", MODE="0666"
		SUBSYSTEM=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6010", MODE="0666"
		SUBSYSTEM=="usb", ATTRS{idVendor}=="09fb", ATTRS{idProduct}=="6810", MODE="0666"
	EOF
}