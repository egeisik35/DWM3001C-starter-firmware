FROM --platform=linux/arm64 ubuntu:22.04

# Set build argument for firmware role (initiator/responder)
ARG ROLE=initiator

# Set frontend to noninteractive for automated installations
ARG DEBIAN_FRONTEND=noninteractive

# Update apt, install necessary tools and dependencies
RUN set -x && \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until && \
    echo 'Acquire::AllowInsecureRepositories "true";' >> /etc/apt/apt.conf.d/99no-check-valid-until && \
    echo 'APT::Get::AllowUnauthenticated "true";' >> /etc/apt/apt.conf.d/99no-check-valid-until && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends \
        ca-certificates apt-transport-https tzdata \
        build-essential wget curl git unzip libusb-1.0-0-dev \
        minicom grep udev locales && \
    rm -rf /var/lib/apt/lists/* && \
    locale-gen en_US.UTF-8

ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

# Install GNU ARM Embedded Toolchain (using latest stable version 14.3.Rel1)
# This is the aarch64 hosted cross-toolchain for aarch64 bare-metal target.
# Suitable for building ARM64 firmware on an ARM64 host.
RUN set -x && \
    wget -q https://developer.arm.com/-/media/Files/downloads/gnu/14.3.rel1/bin/arm-gnu-toolchain-14.3.rel1-aarch64-aarch64-none-elf.tar.xz && \
    tar -xf arm-gnu-toolchain-14.3.rel1-aarch64-aarch64-none-elf.tar.xz -C /usr/local/ && \
    rm arm-gnu-toolchain-14.3.rel1-aarch64-aarch64-none-elf.tar.xz

# Add toolchain to PATH
ENV PATH="/usr/local/arm-gnu-toolchain-14.3.rel1-aarch64-aarch64-none-elf/bin:${PATH}"

# Install SEGGER Embedded Studio for ARM (non-interactive installation)
RUN set -x && \
    wget -q https://www.segger.com/downloads/embedded-studio/Setup_EmbeddedStudio_ARM_v720_linux_arm64.tar.gz && \
    mkdir -p segger && \
    tar -xzf Setup_EmbeddedStudio_ARM_v720_linux_arm64.tar.gz -C segger && \
    echo "--- Contents of segger/ after tar extraction (should contain installer) ---" && \
    ls -F segger/arm_segger_embedded_studio_v720_linux_arm64/ && \
    # Navigate into the extracted directory and run the installer silently
    cd segger/arm_segger_embedded_studio_v720_linux_arm64 && \
    # The --silent flag assumes non-interactive installation. If it fails, consult SEGGER docs.
    ./install_segger_embedded_studio --silent /usr/local/segger_embedded_studio && \
    cd / && \
    rm Setup_EmbeddedStudio_ARM_v720_linux_arm64.tar.gz && \
    rm -rf segger && \
    echo "--- Post-installation check: Expected target directory ---" && \
    if [ ! -d "/usr/local/segger_embedded_studio" ] || [ -z "$(ls -A /usr/local/segger_embedded_studio 2>/dev/null)" ]; then \
        echo "ERROR: SEGGER Embedded Studio installation directory /usr/local/segger_embedded_studio is missing or empty after install attempt!" && \
        exit 1; \
    else \
        echo "SEGGER Embedded Studio directory /usr/local/segger_embedded_studio exists and is not empty." && \
        echo "Contents of /usr/local/segger_embedded_studio:" && \
        ls -F /usr/local/segger_embedded_studio; \
    fi && \
    echo "--- Contents of /usr/local/segger_embedded_studio/bin/ ---\" && \
    ls -R /usr/local/segger_embedded_studio/bin/ && \
    echo \"--- End of bin directory contents listing --"

# Install Nordic nRF Command Line Tools (includes nrfjprog)
# Adjust version as needed
RUN set -x && \
    wget -q https://nsscprodmedia.blob.core.windows.net/prod/software/nrf-command-line-tools-10.22.1-linux-arm64.tar.gz && \
    tar -xzf nrf-command-line-tools-10.22.1-linux-arm64.tar.gz -C /usr/local/ && \
    rm nrf-command-line-tools-10.22.1-linux-arm64.tar.gz

# Add nrfjprog to PATH
ENV PATH="/usr/local/nrf-command-line-tools/bin:${PATH}"

# Install J-Link drivers (if not already included with SEGGER/nRF tools)
# This provides additional J-Link utilities
RUN set -x && \
    wget -q https://www.segger.com/downloads/jlink/JLink_Linux_V796f_arm64.deb -O jlink.deb && \
    dpkg -i jlink.deb || apt-get install -fy && \
    rm jlink.deb

# Fix for udevadm in Docker (prevents 'udevadm control --reload-rules' errors)
# This creates a dummy udevadm that doesn't actually do anything,
# which prevents errors from tools expecting udevadm functionality in a
# containerized environment where udev rules can't be reloaded.
RUN mkdir -p /lib/udev && \
    echo '#!/bin/bash' > /lib/udev/udevadm && \
    echo 'exit 0' >> /lib/udev/udevadm && \
    chmod +x /lib/udev/udevadm

# Setup project directory
WORKDIR /project

# Apply firmware role (Initiator/Responder) based on ARG
# This modifies example_selection.h and main.c based on the ROLE build argument.
RUN if [ "$ROLE" = "responder" ]; then \
        sed -i 's/#define DECA_API_INITIATOR/#define DECA_API_RESPONDER/' Src/example_selection.h && \
        sed -i 's/#define EX_02A_SIMPLE_TX/#define EX_04A_SIMPLE_RX/' Src/example_selection.h && \
        sed -i 's/static void rtc_config(void)/ /' Src/main.c && \
        echo "Configured as RESPONDER"; \
    else \
        echo "Configured as INITIATOR (default)"; \
    fi

# Set the default command when starting the container
CMD ["/bin/bash"]
