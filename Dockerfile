# Base image for ARM64 (Raspberry Pi etc.)
FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until && \
    echo 'Acquire::AllowInsecureRepositories "true";' >> /etc/apt/apt.conf.d/99no-check-valid-until && \
    echo 'APT::Get::AllowUnauthenticated "true";' >> /etc/apt/apt.conf.d/99no-check-valid-until && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends \
    ca-certificates apt-transport-https tzdata build-essential wget unzip \
    libxrender1 libxext6 libusb-1.0-0 apt-utils udev sed locales xz-utils \
    libfreetype6 libfontconfig1 git && \
    ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
    echo "Etc/UTC" > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata && \
    rm -rf /var/lib/apt/lists/*

# Set locales
RUN locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Create working directory
WORKDIR /usr/local

# Install nRF5 SDK
RUN wget -q https://nsscprodmedia.blob.core.windows.net/prod/software-and-other-downloads/sdks/nrf5/binaries/nrf5_sdk_17.1.0_ddde560.zip && \
    unzip nrf5_sdk_17.1.0_ddde560.zip && \
    rm nrf5_sdk_17.1.0_ddde560.zip

# Install nRF Command Line Tools
RUN wget -q https://nsscprodmedia.blob.core.windows.net/prod/software-and-other-downloads/desktop-software/nrf-command-line-tools/sw/versions-10-x-x/10-23-2/nrf-command-line-tools_10.23.2_arm64.deb && \
    dpkg -i nrf-command-line-tools_10.23.2_arm64.deb && \
    rm nrf-command-line-tools_10.23.2_arm64.deb

# Workaround for udevadm issue in Docker
RUN echo '#!/bin/bash\necho not running udevadm "$@"' > /usr/bin/udevadm && chmod +x /usr/bin/udevadm && apt-get install -y --fix-broken

# Install J-Link Tools (ARM64)
RUN wget -q --post-data accept_license_agreement=accepted https://www.segger.com/downloads/jlink/JLink_Linux_V850_arm64.tgz && \
    tar -xzf JLink_Linux_V850_arm64.tgz --strip-components=1 && \
    rm JLink_Linux_V850_arm64.tgz

# Install SEGGER Embedded Studio version 8.24 (ARM64)
RUN wget -q --post-data accept_license_agreement=accepted https://www.segger.com/downloads/embedded-studio/Setup_EmbeddedStudio_v824_Linux_arm64.tar.gz && \
    tar -xzf Setup_EmbeddedStudio_v824_Linux_arm64.tar.gz && \
    rm Setup_EmbeddedStudio_v824_Linux_arm64.tar.gz && \
    chmod +x segger_embedded_studio_v824_linux_arm64/install_segger_embedded_studio && \
    yes yes | segger_embedded_studio_v824_linux_arm64/install_segger_embedded_studio --copy-files-to /usr/local/segger_embedded_studio_V8.24 && \
    rm -rf segger_embedded_studio_v824_linux_arm64

# Install ARM GNU Embedded Toolchain
# This installs the cross-compiler for ARM Cortex-M microcontrollers
RUN apt-get update -y && apt-get install -y --no-install-recommends gcc-arm-none-eabi && rm -rf /var/lib/apt/lists/*

# Project directory
WORKDIR /project

# Copy project files into container
COPY . .

