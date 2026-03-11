# syntax=docker/dockerfile:1
#
# --- LazyFPGA Dockerfile ---
# Author: Johannes Hüffer
# Date: 27.02.2026
# Version: 0.1.0
# Copying: GPL-3.0-only
# ---------------------------
#
# Description:
#	This Dockerfile serves as the base for a LazyFPGA Image which
#	will contain the entire Quartus (and Questa) installation
#	once the build has finished.
#	The image resulting from the build will be used by distrobox
#	to set up an actual container enabling you (as an "end-user")
#	to use Quartus (and Questa) distribution-agnostic and seamlessly
#	on basically any Linux system which is compatible with Podman and/or Docker.
#	
#
# LEGAL NOTICE:
#	The final image is built by you, the end-user! Since this Dockerfile does not
#	contain any proprietary components, it can be considered free
#	software *by itself* (speaking of all the software contained in Lazy FPGA's repo).
#		Any software falling under intellectual property rights
#	(namely Intel Quartus Prime Lite and Intel Questa) is downloaded on-demand only
#	and will therefore never be contained in Lazy FPGA's repositories.
#	At no time, closed-source / proprietary software will be distributed in any
#	way which could violate Intel's EULA!
#		This is because you, the end-user - making use of this Dockerfile - are still
#	obtaining any proprietary software on her/his own behalf,
#	since these components are only downloaded at build time.
#		Doing so does not differ from any regular use case, as the end-user initiates the
#	build process, such that proprietary software is only downloaded during the actual build
#	and therefore obtained by the end-user her-/himself!
#		By using this Dockerfile, be reminded that you accept the terms of Intel's EULA
#	by doing so. 
#	The developer of Lazy FPGA is not responsible for any violation against that EULA!
#
#	See https://www.altera.com/downloads/fpga-development-tools/quartus-prime-lite-edition-design-software-version-23-1-1-linux; "Legal Notice"
#

# Get the base image first. For Quartus 23.1.1, we will choose Ubuntu 22.04 LTS
FROM ubuntu:22.04

# Make sure every argument defined in 'argfile.conf' will be consumed
# (which simply means that the value is actually taken over
# into the build process and does not remain empty)!
ARG q_installer_script="" q_installer_wrapper="" container_home="" container_setup_dir="" \
    q_setup_dir="" q_dirname="" q_rootdir="" lm_license_file="" qsys_rootdir="" qfse_rootdir=""

# Install basic tools and minimal Gnome session runtime first.
# Excluding install-recommends and suggestions reduces the image's final size.
# Because the package 'ubuntu-minimal' requires user interaction by default,
# the env vars $DEBIAN_FRONTEND and $DEBCONF_NONINTERACTIVE_SEEN are set as shown.
# Otherwise, 'apt' and the entire build would fail.
#  --> Minimal gnome-session-bin package is required to get the Intel setup running.
#  --> libxft2 package is necessary to make Questa (vsim) work.
ARG DEBIAN_FRONTEND=noninteractive
ARG DEBCONF_NONINTERACTIVE_SEEN=true
RUN apt-get update && apt-get install --no-install-recommends --no-install-suggests -y \
    software-properties-common \
    libxft2 \
    gnome-session-bin \
    ubuntu-minimal; \
    dpkg --configure -a; \
    apt-get autoremove -y; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# Copy the Intel setup directory into the image to /usr/local/bin
WORKDIR /usr/local/bin
COPY --chmod=755 $q_installer_dir .

# Copy the setup wrapper into the image.
# --> The wrapper launches the Intel setup and will create a
#	flag file (either '.setup-done' or '.setup-failed') if setup
#	exits; to be read by the 'post-install.sh' script such that it knows
#	when to continue with the finalizing steps.
COPY --chmod=755 $q_installer_wrapper_name .

# Fix broken CA certs Intel ships with their setup by linking to the system CA certs instead
WORKDIR $container_setup_dir
RUN rm -f common/misc/cacert.pem && ln -s /etc/ssl/certs/ca-certificates.crt common/misc/cacert.pem

# Set (persistent) environment variables
ENV CONTAINER_HOME=$container_home
ENV Q_SETUP_DIR=$q_setup_dir
ENV Q_DIRNAME=$q_dirname
ENV Q_ROOTDIR=$q_rootdir
ENV Q_INSTALLER_SCRIPT=$q_installer_script
ENV Q_INSTALLER_WRAPPER=$q_installer_wrapper
ENV LM_LICENSE_FILE=$lm_license_file
ENV QSYS_ROOTDIR=$qsys_rootdir
ENV QFSE_ROOTDIR=$qfse_rootdir
# Add Quartus' and Questa's binary directories to the container's system $PATH.
# Important: Curly brackets are explicitly omitted here because they cause buildx
# to insert the host system path instead of the image path, but we need the image path!
ENV PATH="$PATH:$qsys_rootdir:$qfse_rootdir"
