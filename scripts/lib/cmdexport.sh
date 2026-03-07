#!/usr/bin/env bash
#
# Lazy FPGA Command Exporter
#
# Author: Johannes Hüffer
# Begin of development: 29.11.2024
# Version: 0.1.0
# Copying: GPL-3.0-only
#
# Integrates the CLI commands for Quartus and Questa well into
# the user's shell by using distrobox's export feature.
#

function export_qcmds() {
	exit_status=0
	info "Exporting Quartus and Questa CLI tools ..."

	# Add local binary directory to the user's $PATH
	bin_dir="${HOME}/.local/bin"
	shellrc=".$(basename "${SHELL}")rc"
	printf "# Add local binary dir to \$PATH\nexport PATH=\${PATH}:%s" "${bin_dir}" >> "${shellrc}"

	# Peform actual export
	if distrobox enter "${CONTAINER_NAME}" -- distrobox-export --bin "\$(which quartus)" --export-path "${bin_dir}"; then
		ok "Exported Quartus command (quartus)"
	else
		err "Could not export Quartus command (quartus)!"
		exit_status=1
	fi
	if distrobox enter "${CONTAINER_NAME}" -- distrobox-export --bin "\$(which vsim)" --export-path "${bin_dir}"; then
		ok "Exported Questa command (vsim)"
	else
		err "Could not export Questa command (vsim)!"
		exit_status=1
	fi
	return "${exit_status}"
}