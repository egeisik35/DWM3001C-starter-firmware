#
# Dockerfile for DWM3001C on ARM64 (e.g., Raspberry Pi)
#
# Build Initiator:  docker build --build-arg ROLE=initiator -t dwm-initiator .
# Build Responder: docker build --build-arg ROLE=responder -t dwm-responder .
#

# 1. Use an ARM64 (aarch64) version of Ubuntu
FROM --platform=linux/arm64 ubuntu:22.04

# Set a build argument for ROLE, defaulting to 'initiator'
ARG ROLE=initiator
ARG DEBIAN_FRONTEND=noninteractive

# Install base dependencies, which are multi-arch
RUN apt-get -y update && \
    apt-get install -y \
    build-essential \
    wget \
    unzip \
    libxrender1 \
    libxext6 \
    libusb-1.0-0 \
    apt-utils \
    udev \
    sed && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /usr/local

# install nRF5 SDK (architecture independent)
RUN wget -q https://nsscprodmedia.blob.core.windows.net/prod/software-and-other-downloads/sdks/nrf5/binaries/nrf5_sdk_17.1.0_ddde560.zip && \
    unzip nrf5_sdk_17.1.0_ddde560.zip && \
    rm nrf5_sdk_17.1.0_ddde560.zip

# 2. Install SEGGER Embedded Studio for ARM64 (v5.42a was not available, using a newer version)
# NOTE: The original x64 URL was changed to the ARM64 URL
RUN wget -q https://www.segger.com/downloads/embedded-studio/Setup_EmbeddedStudio_ARM_v720_linux_arm64.tar.gz && \
    tar xf Setup_EmbeddedStudio_ARM_v720_linux_arm64.tar.gz --strip-components=1 arm_segger_embedded_studio_720_linux_arm64/install_segger_embedded_studio && \
    rm Setup_EmbeddedStudio_ARM_v720_linux_arm64.tar.gz
RUN yes yes | ./install_segger_embedded_studio --copy-files-to /usr/local/segger_embedded_studio

# 3. Install nRF command line tools for ARM64
# NOTE: The original amd64 .deb was changed to the arm64 .deb
RUN wget -q https://nsscprodmedia.blob.core.windows.net/prod/software-and-other-downloads/desktop-software/nrf-command-line-tools/sw/versions-10-x-x/10-23-2/nrf-command-line-tools_10.23.2_arm64.deb && \
    dpkg -i nrf-command-line-tools_10.23.2_arm64.deb && \
    rm nrf-command-line-tools_10.23.2_arm64.deb
# Workaround for udevadm in Docker
RUN echo '#!/bin/bash\necho not running udevadm "$@"' > /usr/bin/udevadm && chmod +x /usr/bin/udevadm && apt-get install -y --fix-broken

# 4. Install J-Link tools for ARM64
# NOTE: The original x86_64 .tgz was changed to the aarch64 .tgz
RUN wget -q --post-data accept_license_agreement=accepted https://www.segger.com/downloads/jlink/JLink_Linux_V794o_aarch64.tgz && \
    tar xf JLink_Linux_V794o_aarch64.tgz --strip-components=1 && \
    rm JLink_Linux_V794o_aarch64.tgz

# Set up the project directory
WORKDIR /project

# Copy your source code into the container
COPY . .

# 5. Automatically modify source files based on the ROLE argument before building
RUN echo "INFO: Configuring build for ROLE=${ROLE}" && \
    if [ "$ROLE" = "initiator" ]; then \
        # Configure for Initiator
        sed -i 's|//#define TEST_SS_TWR_INITIATOR|#define TEST_SS_TWR_INITIATOR|' Src/example_selection.h && \
        sed -i 's|#define TEST_READING_DEV_ID|//#define TEST_READING_DEV_ID|' Src/example_selection.h && \
        sed -i 's|extern int read_dev_id(void); read_dev_id();|// extern int read_dev_id(void); read_dev_id();|' Src/main.c && \
        sed -i 's|// extern int ss_twr_initiator(void); ss_twr_initiator();|extern int ss_twr_initiator(void); ss_twr_initiator();|' Src/main.c; \
    elif [ "$ROLE" = "responder" ]; then \
        # Configure for Responder
        sed -i 's|//#define TEST_SS_TWR_RESPONDER|#define TEST_SS_TWR_RESPONDER|' Src/example_selection.h && \
        sed -i 's|#define TEST_READING_DEV_ID|//#define TEST_READING_DEV_ID|' Src/example_selection.h && \
        sed -i 's|extern int read_dev_id(void); read_dev_id();|// extern int read_dev_id(void); read_dev_id();|' Src/main.c && \
        sed -i 's|// extern int ss_twr_responder(void); ss_twr_responder();|extern int ss_twr_responder(void); ss_twr_responder();|' Src/main.c; \
    else \
        echo "ERROR: ROLE must be 'initiator' or 'responder'. Found: '${ROLE}'" && exit 1; \
    fi

# Build the firmware
RUN make
