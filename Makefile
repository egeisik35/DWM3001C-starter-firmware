# Define the image name you're actually using
DOCKER_IMAGE := dwm-firmware

# Build the firmware using GCC inside Docker
build: development-environment
	docker run -it --rm -v "$$(pwd)":/project $(DOCKER_IMAGE) \
	/usr/local/segger_embedded_studio_V8.24/bin/emBuild -config Common /project/dw3000_api.emProject

# # Clean build outputs
clean: development-environment
	docker run -it --rm -v "$$(pwd)":/project $(DOCKER_IMAGE) bash -c "cd /project && make clean"

# Flash the DWM3001CDK
flash: development-environment
	docker run --privileged \
		-v /dev/bus/usb:/dev/bus/usb \
		-v "$(PWD)/Output":/project/Output:ro \
		$(DOCKER_IMAGE) \
		nrfjprog --force -f nrf52 --program /project/Output/Common/Exe/dw3000_api.hex --sectorerase --verify

# Read RTT logs
stream-debug-logs:
	echo "Run this command to view debug logs: tail -f Output/debug-log.txt"
	docker run --privileged -it \
		-v /dev/bus/usb:/dev/bus/usb \
		-v "$(PWD)/Output":/project/Output \
		$(DOCKER_IMAGE) \
		/usr/local/JLinkRTTLogger -Device NRF52833_XXAA -if SWD -Speed 4000 -RTTChannel 0 /project/Output/debug-log.txt

# Open a minicom UART terminal to the board
serial-terminal:
	DEVICE_FILE=$$(ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null | while read -r dev; do if udevadm info -a -n $$dev | grep -q 'ATTRS{idVendor}=="1915"' && udevadm info -a -n $$dev | grep -q 'ATTRS{idProduct}=="520f"'; then echo "$$dev"; break; fi; done); \
	if [ -z "$$DEVICE_FILE" ]; then echo "Device not found"; exit 1; fi; \
	minicom --device $$DEVICE_FILE

# Open an interactive shell inside the dev container
development-shell: development-environment
	docker run -it -v "$(PWD)":/project $(DOCKER_IMAGE) bash

# Build the container image
development-environment:
	docker build -t $(DOCKER_IMAGE) .

# Save the dev environment image
save-development-environment:
	docker image save -o dwm-firmware.tar $(DOCKER_IMAGE)

# Load the image back later if needed
load-development-environment:
	docker image load -i dwm-firmware.tar
