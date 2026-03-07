#!/usr/bin/env bash
#
# Lazy FPGA Intel Setup Downloader
#
# Author: Johannes Hüffer
# Begin of development: 29.11.2024
# Version: 0.1.0
# Copying: GPL-3.0-only
#


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

	if ping -c3 9.9.9.9 &> /dev/null; then
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
		err "Sorry, likely no internet connection!"
		info " ==> At least no echo from Quad9's DNS after three attempts"
		return 1
	fi
}


### Download a file from a given URL
#
# CAUTION: ${local_uri} must contain an absolute path to a file!
#   Examples: "/home/user/foo.txt", "/tmp/foo/bar.png"
#
# Usage: 'download <url> <abs-path-to-target-file>'
# Example: 'download https://resource.net/file.txt /path/to/target/file.txt'
#
function download() {
	download_url="$1"
	local_uri="$2"
	service_domain="$(echo "${download_url}" | grep -oP '^(https?://[^/]+)')"

	download_dir="${local_uri%/*}"
	download_file="$(basename "${local_uri}")"

	if is_webresource_avail "${download_url}"; then
		if [[ ! -d "${download_dir}" ]]; then
			info "Creating ${download_dir} ..."
			mkdir -p "${download_dir}"
		fi

		info "Now downloading from \"${service_domain}\" ...\n"
		if curl -L -o "${local_uri}" "${download_url}"; then
			echo ""
			ok "Download of \"${download_file}\" has finished."
			return 0
		else
			err "Download had hickups!"
			return 1
		fi
	else
		err "Sorry, download not possible!"
		return 1
	fi
}


### Download Quartus installer
#
# Usage: 'download_qinstaller <to-path>'
#
function download_qinstaller() {
	download "${Q_INSTALLER_URL}" "${1}/${Q_INSTALLER_NAME}"
}


### Verify a file's checksum
#
# Using SHA1, because ... icecream.
# Seriously, for the scope of this
# helper script it's sufficient I guess,
# as Intel only provides an SHA1 checksum.
#
# Usage: 'verify <abs-path-to-file> <expected-sha1-checksum>'
#
function verify() {
	local_uri="$1"
	sha1_checksum_expected="$2"
	file_to_verify="$(basename "${local_uri}")"

	if [[ -f "${local_uri}" ]]; then
		info "Checking file integrity ..."
		if sha1sum "${local_uri}" 2> /dev/null | grep -qi "${sha1_checksum_expected}"; then
			ok "\"${file_to_verify}\" matches expected checksum and seems intact"
			return 0
		else
			err "CAUTION: \"${local_uri}\"\n${DIND}may be corrupted and should not be used!"
			return 1
		fi
	else
		err "Not able to verify! \"${local_uri}\" not present."
		return 1
	fi
}
