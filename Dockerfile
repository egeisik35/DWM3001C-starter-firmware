FROM --platform=linux/arm64 ubuntu:22.04

# Set build argument for firmware role (initiator/responder)
ARG ROLE=initiator
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

# Install GNU ARM Embedded Toolchain (aarch64 hosted cross-toolchain)
RUN set -x && \
    wget -q https://developer.arm.com/-/media/Files/downloads/gnu/14.3.rel1/bin/arm-gnu-toolchain-14.3.rel1-aarch64-aarch64-none-elf.tar.xz && \
    tar -xf arm-gnu-toolchain-14.3.rel1-aarch64-aarch64-none-elf.tar.xz -C /usr/local/ && \
    rm arm-gnu-toolchain-14.3.rel1-aarch64-aarch64-none-elf.tar.xz

ENV PATH="/usr/local/arm-gnu-toolchain-14.3.rel1-aarch64-aarch64-none-elf/bin:${PATH}"

# Install SEGGER Embedded Studio (silent, non-interactive)
RUN set -x && \
    wget -q https://www.segger.com/downloads/embedded-studio/Setup_EmbeddedStudio_ARM_v720_linux_arm64.tar.gz && \
    mkdir -p segger && \
    tar -xzf Setup_EmbeddedStudio_ARM_v720_linux_arm64.tar.gz -C segger && \
    echo "--- Contents of segger/ after tar extraction ---" && \
    ls -F segger/arm_segger_embedded_studio_v720_linux_arm64/ && \
    cd segger/arm_segger_embedded_studio_v720_linux_arm64 && \
    ./install_segger_embedded_studio --silent --accept-license --full-install --destination /usr/local/segger_embedded_studio && \
    cd / && \
    rm Setup_EmbeddedStudio_ARM_v720_linux_arm64.tar.gz && \
    rm -rf segger && \
    echo "--- Post-installation check: Expected target directory ---" && \
    if [ ! -d "/usr/local/segger_embedded_studio" ] || [ -z "$(ls -A /usr/local/segger_embedded_studio 2>/dev/null)" ]; then \
        echo "ERROR: SEGGER Embedded Studio installation directory is missing or empty!" && exit 1; \
    else \
        echo "SEGGER Embedded Studio installed successfully." && \
        echo "Contents of /usr/local/segger_embedded_studio:" && \
        ls -F /usr/local/segger_embedded_studio; \
    fi && \
    echo "--- Contents of /usr/local/segger_embedded_studio/bin/ ---" && \
    ls -R /usr/local/segger_embedded_studio/bin/ && \
    echo "--- End of bin directory listing ---"

# Install Nordic nRF Command Line Tools
RUN set -x && \
    wget -q https://nsscprodmedia.blob.core.windows.net/prod/software/nrf-command-line-tools-10.22.1-linux-arm64.tar.gz && \
    tar -xzf nrf-command-line-tools-10.22.1-linux-arm64.tar.gz -C /usr/local/ && \
    rm nrf-command-line-tools-10.22.1-linux-arm64.tar.gz

ENV PATH="/usr/local/nrf-command-line-tools/bin:${PATH}"

# Install SEGGER J-Link drivers
RUN set -x && \
    wget -q https://www.segger.com/downloads/jlink/JLink_Linux_V796f_arm64.deb -O jlink.deb && \
    dpkg -i jlink.deb || apt-get install -fy && \
    rm jlink.deb

# udevadm dummy for Docker compatibility
RUN mkdir -p /lib/udev && \
    echo '#!/bin/bash' > /lib/udev/udevadm && \
    echo 'exit 0' >> /lib/udev/udevadm && \
    chmod +x /lib/udev/udevadm

# Set project directory
WORKDIR /project

# Apply role-specific patching
RUN if [ "$ROLE" = "responder" ]; then \
        sed -i 's/#define DECA_API_INITIATOR/#define DECA_API_RESPONDER/' Src/example_selection.h && \
        sed -i 's/#define EX_02A_SIMPLE_TX/#define EX_04A_SIMPLE_RX/' Src/example_selection.h && \
        sed -i 's/static void rtc_config(void)/ /' Src/main.c && \
        echo "Configured as RESPONDER"; \
    else \
        echo "Configured as INITIATOR (default)"; \
    fi

# Default shell
CMD ["/bin/bash"]

