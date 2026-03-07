#!/usr/bin/env bash
#
# Lazy FPGA Resource Search
#
# Author: Johannes Hüffer
# Begin of development: 29.11.2024
# Version: 0.1.0
# Copying: GPL-3.0-only
#
# The functions found in here serve the purpose of finding
# resources inside the user's home directory more easily and
# with an appealing visual feedback if desired.
#


# Find a file with a certain name inside the user's home directory.
# If argument "verbose" is set, the function will report its status.
# By default it operates silently without any direct feedback (to stdout or sterr).
#
# Usage: 'find_file <file-name> ["verbose"]'
# Echoes: String containing the absolute file path (if any match; otherwise empty)
#
# Please note: The function will only return the first match it has spotted.
#	Any further files with a similar name will be ignored for simplicity!
#
function find_file() {
	file_name="$(basename "${1}")"
	is_verbose="${2}"

	[[ -n "${is_verbose}" ]] && info "Please wait, searching \"${HOME}\" for file \"${file_name}\" ..."
	file_found="$(find "${HOME}" -name "${file_name}" -type f 2> /dev/null | head -n 1)"

	if [[ -f "${file_found}" ]]; then
		[[ -n "${is_verbose}" ]] && ok "Found \"${file_name}\" in \"$(dirname "${file_found}")\""
	else
		[[ -n "${is_verbose}" ]] && err "No file \"${file_name}\" anywhere in \"${HOME}\"!"
	fi

	echo "${file_found}"
	[[ -n "${file_found}" ]]
}