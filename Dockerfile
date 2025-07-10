FROM --platform=linux/arm64 ubuntu:22.04

# Set build argument for firmware role (initiator/responder)
ARG ROLE=initiator

# Set frontend to noninteractive for automated installations
ARG DEBIAN_FRONTEND=noninteractive

# Install dependencies
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

# Install SEGGER Embedded Studio for ARM (non-interactive)
RUN set -x && \
    wget -q https://www.segger.com/downloads/embedded-studio/Setup_EmbeddedStudio_ARM_v720_linux_arm64.tar.gz && \
    mkdir -p segger && \
    tar -xzf Setup_EmbeddedStudio_ARM_v720_linux_arm64.tar.gz -C segger && \
    cd segger/arm_segger_embedded_studio_v720_linux_arm64 && \
    ./install_segger_embedded_studio --silent /usr/local/segger_embedded_studio && \
    cd / && \
    rm -rf Setup_EmbeddedStudio_ARM_v720_linux_arm64.tar.gz segger

ENV PATH="/usr/local/segger_embedded_studio/bin:${PATH}"

# Install Nordic nRF Command Line Tools (includes nrfjprog)
RUN set -x && \
    wget -q https://nsscprodmedia.blob.core.windows.net/prod/software-and-other-downloads/desktop-software/nrf-command-line-tools/sw/versions-10-x-x/10-24-2/nrf-command-line-tools-10.24.2_linux-arm64.tar.gz && \
    tar -xzf nrf-command-line-tools-10.24.2_linux-arm64.tar.gz -C /usr/local/ && \
    rm nrf-command-line-tools-10.24.2_linux-arm64.tar.gz

ENV PATH="/usr/local/nrf-command-line-tools/bin:${PATH}"

# Install J-Link tools with license acceptance
RUN set -x && \
    wget --post-data "accept_license_agreement=accepted&non_emb_ctr=confirmed" \
    "https://www.segger.com/downloads/jlink/JLink_Linux_V850_arm64.tgz" -O JLink_Linux_arm64.tgz && \
    tar -xzf JLink_Linux_arm64.tgz -C /usr/local/ && \
    rm JLink_Linux_arm64.tgz

# Workaround for udevadm errors in container
RUN mkdir -p /lib/udev && \
    echo '#!/bin/bash' > /lib/udev/udevadm && \
    echo 'exit 0' >> /lib/udev/udevadm && \
    chmod +x /lib/udev/udevadm

# Set working directory
WORKDIR /project

# Apply firmware role
RUN if [ "$ROLE" = "responder" ]; then \
        sed -i 's/#define DECA_API_INITIATOR/#define DECA_API_RESPONDER/' Src/example_selection.h && \
        sed -i 's/#define EX_02A_SIMPLE_TX/#define EX_04A_SIMPLE_RX/' Src/example_selection.h && \
        sed -i 's/static void rtc_config(void)/ /' Src/main.c && \
        echo "Configured as RESPONDER"; \
    else \
        echo "Configured as INITIATOR (default)"; \
    fi

CMD ["/bin/bash"]

