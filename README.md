DWM3001C Starter Firmware
=========================

A firmware for the [Qorvo DWM3001C](https://www.qorvo.com/products/p/DWM3001C) with comprehensive examples for all of the module's UWB and ranging functionality, and developer tooling that makes working with the firmware much easier than the official tooling. Features:

* **Reproducible**: built-in Docker development environment automates away most of the fragile and finicky parts of setting up the Qorvo SDK, SEGGER Embedded Studio, SEGGER J-Link, nRF52 SDK, and nRF command line tools.**This fork updates the environment for native ARM64 architectures (e.g., Raspberry Pi), replacing x86 assumptions for a smoother developer experience.**
* **Minimal**: based on a heavily-modified version of the [official Qorvo DWM3001C API software](https://www.qorvo.com/products/p/DWM3001C#documents) (2022-08 version), but significantly simpler in terms of code size and organization. Many source files and folders have been consolidated to make the project much easier to navigate.
* **Complete**: includes build system, flashing tools, and logging/debugging tools. This is the only repository you need to work with the firmware.
* **Portable**: run `make save-development-environment` to generate a 5GB tar file containing the entire development environment. In 10 years from now, when half of these dependencies disappear off the internet, run `make load-development-environment` and you'll still be able to compile this project.
* Runs directly on the DWM3001C's onboard nRF52833: the official examples target an external microcontroller that then interacts with the DWM3001C, but this firmware is designed to run directly on the DWM3001C.

The firmware and instructions in this repository somewhat assume that you're using the DWM3001CDK (the official DWM3001C devkit), but you can also run it on a standalone DWM3001C simply by not using the definitions for the devkit's onboard LEDs, button, and SEGGER J-Link (see `Src/custom_board.h`).

**See also:** if you're looking for a fully-featured firmware that you just need some minor customizations for, check out my [DWM3001CDK demo firmware repository](https://github.com/Uberi/DWM3001CDK-demo-firmware).

Quickstart
----------

```sh
# MANUAL ACTION (OPTIONAL): run this command to use my prebuilt development environment, otherwise it'll be automatically built from scratch: docker pull uberi/qorvo-nrf52833-board

make build

# MANUAL ACTION: connect the lower USB port of the DWM3001CDK (labelled J9) to this computer using a USB cable (this is the J-Link's USB port)

make flash

make stream-debug-logs

# MANUAL ACTION: run the following command in another terminal to see the debug logs: tail -f Output/debug-log.txt
```

You should now see RTT output from the DWM3001CDK, try pressing the reset buttom (labelled SW1) to re-run the example program and output more logs over RTT.

Developing
----------

You'll need Docker, and many of the hardware-facing commands in the Makefile assume you're using Linux. The `make serial-terminal` command assumes you have `minicom`, `grep`, and `udevadm` installed.

### Building and Running the Docker Environment
**Note:** This section reflects changes specific to this fork. It includes an ARM64-optimized Docker setup and updated download URLs.

While the `make build` command in the Quickstart uses a default configuration, you can explicitly build the Docker image with your desired firmware role (Initiator or Responder) and then run it with hardware access for flashing and debugging.

**1. Build the Docker Image (for Initiator or Responder):**
Choose the role for the firmware by passing the `ROLE` build argument. Replace `uberi/qorvo-nrf52833-board` with your desired image name if you prefer.

* **To build the image configured as an Initiator:**
    ```sh
    sudo docker build --build-arg ROLE=initiator -t uberi/qorvo-nrf52833-board:initiator .
    ```

* **To build the image configured as a Responder:**
    ```sh
    sudo docker build --build-arg ROLE=responder -t uberi/qorvo-nrf52833-board:responder .
    ```

    **Note:** Since your `Dockerfile` is now optimized for `linux/arm64` and you'll be building on a native ARM machine (like a Raspberry Pi), you do not need to explicitly add `--platform linux/arm64` to the `docker build` command. Docker will automatically use the correct platform.

**2. Run the Docker Container (with Hardware Access):**
To interact with your DWM3001CDK (for flashing firmware, streaming debug logs, etc.), the container needs access to your USB J-Link device.

* **To run the Initiator environment:**
    ```sh
    sudo docker run --privileged -it --name dwm_dev_env_initiator -v "$(pwd)":/project uberi/qorvo-nrf52833-board:initiator /bin/bash
    ```

* **To run the Responder environment:**
    ```sh
    sudo docker run --privileged -it --name dwm_dev_env_responder -v "$(pwd)":/project uberi/qorvo-nrf52833-board:responder /bin/bash
    ```

    **Explanation of `docker run` flags:**
    * `--privileged`: This is the easiest way to ensure the container has access to USB devices. It grants broad permissions, typically suitable for a local development environment.
    * `-it`: Runs the container in interactive mode with a pseudo-TTY, allowing you to interact with the shell inside.
    * `--name ...`: Assigns a unique, memorable name to your running container.
    * `-v "$(pwd)":/project`: Mounts your current host project directory into the `/project` directory inside the container. This means you can edit files on your host, and the changes are immediately available for building within the container.
    * `uberi/qorvo-nrf52833-board:...`: The name of the specific Docker image you built.
    * `/bin/bash`: Starts a bash shell inside the container.

    Once you are inside the container's shell (your terminal prompt will change, typically indicating `root@<container_id>:/project#`), you can then use your `make` commands:
    ```sh
    # Inside the container
    make build
    make flash
    make stream-debug-logs
    ```

---

You can develop your custom applications by modifying `Src/main.c` and other files within `Src/`.

Note that you'll have to manually edit `dw3000_api.emProject` with any file additions/removals/renames. It sounds annoying, and it is, but I still consider it an improvement over directly interacting with the proprietary SEGGER Embedded Studio.

Fork Information
----------------

This is a fork of [Uberi's DWM3001C Starter Firmware](https://github.com/Uberi/DWM3001C-starter-firmware).The primary goal of this fork is to improve support for native ARM64 systems (e.g., Raspberry Pi), replace broken tooling links, and streamline the Docker build process for constrained development environments.

Contributions and improvements welcome.


License
-------

Most of the code in this repository comes from the official Qorvo SDKs and examples published on their website. Here's the copyright notice that comes with the SDKs:

> Read the header of each file to know more about the license concerning this file.
> Following licenses are used in the SDK:
> 
> * Apache-2.0 license
> * Qorvo license
> * FreeRTOS license
> * Nordic Semiconductor ASA license
> * Garmin Canada license
> * ARM Limited license
> * Third-party licenses: All third-party code contained in SDK_BSP/external (respective licenses included in each of the imported projects)
> 
> The provided HEX files were compiled using the projects located in the folders. For license and copyright information,
> see the individual .c and .h files that are included in the projects.

Therefore, you should carefully read the copyright headers of the individual source files and follow their licenses if you decide to use them. As for the parts I've built, such as the build environment, I release those under the [Creative Commons CC0 license](https://creativecommons.org/public-domain/cc0/) ("No Rights Reserved").
