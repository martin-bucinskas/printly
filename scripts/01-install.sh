#!/usr/bin/env bash
# This script installs printly and all its components on an Arch Linux system.

ENV_DIR="$(pwd)/.envs"
KLIPPY_ENV="${ENV_DIR}/klippy-env"
MOONRAKER_ENV="${ENV_DIR}/moonraker-env"
PRINTER_DATA_DIR="$(pwd)/.printer_data"
SERVICE_USER="$USER"

VAR_MCU_SERIAL="/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0"
VAR_VIRTUAL_SDCARD_PATH="${PRINTER_DATA_DIR}/gcodes"

PRINTER_DATA_DIRS=(
    "comms"
    "config"
    "database"
    "gcodes"
    "logs"
    "misc"
    "systemd"
)

create_directories() {
    print_status_header "Creating printer data directories in ${PRINTER_DATA_DIR}"
    mkdir -p "${PRINTER_DATA_DIR}"
    for dir in "${PRINTER_DATA_DIRS[@]}"; do
        mkdir -p "${PRINTER_DATA_DIR}/${dir}"
    done

    print_status_header "Setting up printer data files..."
    cp "$(pwd)/templates/printer.cfg" "${PRINTER_DATA_DIR}/config/printer.cfg"
    cp "$(pwd)/templates/mainsail.cfg" "${PRINTER_DATA_DIR}/config/mainsail.cfg"
    cp "$(pwd)/templates/moonraker.cfg" "${PRINTER_DATA_DIR}/config/moonraker.cfg"
    cp "$(pwd)/templates/mainsail-config.json" "${PRINTER_DATA_DIR}/config/mainsail-config.json"

    sed -i "s|###MCU_SERIAL###|${VAR_MCU_SERIAL}|g" "${PRINTER_DATA_DIR}/config/printer.cfg"
    sed -i "s|###VIRTUAL_SDCARD_PATH###|${VAR_VIRTUAL_SDCARD_PATH}|g" "${PRINTER_DATA_DIR}/config/printer.cfg"
    sed -i "s|###VIRTUAL_SDCARD_PATH###|${VAR_VIRTUAL_SDCARD_PATH}|g" "${PRINTER_DATA_DIR}/config/mainsail.cfg"

    print_status_header "Creating virtual environments in ${ENV_DIR}"
    mkdir -p "${ENV_DIR}"
    python3 -m venv "${KLIPPY_ENV}"
    python3 -m venv "${MOONRAKER_ENV}"
}

install_packages() {
    print_status_header "Installing system packages..."
    sudo pacman -S \
      python-virtualenv \
      libffi \
      base-devel \
      ncurses \
      libusb \
      avrdude avr-gcc avr-binutils avr-libc \
      arm-none-eabi-newlib arm-none-eabi-gcc arm-none-eabi-binutils
}

user_permissions() {
  sudo usermod -aG uucp "${SERVICE_USER}"
}

apply_patches() {
    print_status_header "Applying patches..."
    patch -p1 < "$(pwd)/patches/klippy-requirements.txt.diff"
    patch -p1 < "$(pwd)/patches/moonraker-requirements.txt.diff"
}

create_virtualenvs() {
    print_status_header "Creating python virtual environments..."
    source "${KLIPPY_ENV}/bin/activate"
    pip install -r "$(pwd)/services/klipper/scripts/klippy-requirements.txt"
    deactivate

    source "${MOONRAKER_ENV}/bin/activate"
    pip install -r "$(pwd)/services/moonraker/requirements.txt"
    deactivate
}

install_systemd_services() {
    print_status_header "Installing systemd services..."
    sudo /bin/sh -c "cat > /etc/systemd/system/klipper.service" << EOF
#Systemd service file for klipper
[Unit]
Description=Starts klipper on startup
After=network.target

[Install]
WantedBy=multi-user.target

[Service]
Type=simple
User=${SERVICE_USER}
RemainAfterExit=yes
WorkingDirectory=$(pwd)/services/klipper
ExecStart=${KLIPPY_ENV}/bin/python $(pwd)/services/klipper/klippy/klippy.py ${PRINTER_DATA_DIR}/config/printer.cfg -l ${PRINTER_DATA_DIR}/logs/klippy.log -I ${PRINTER_DATA_DIR}/comms/klippy.serial -a ${PRINTER_DATA_DIR}/comms/klippy.sock
EOF

    sudo /bin/sh -c "cat > /etc/systemd/system/moonraker.service" << EOF
#Systemd service file for moonraker
[Unit]
Description=API Server for Klipper SV1
Requires=network-online.target
After=network-online.target

[Install]
WantedBy=multi-user.target

[Service]
Type=simple
User=${SERVICE_USER}
SupplementaryGroups=moonraker-admin
RemainAfterExit=yes
WorkingDirectory=$(pwd)/services/moonraker
ExecStart=${MOONRAKER_ENV}/bin/python $(pwd)/services/moonraker/moonraker/moonraker.py -d ${PRINTER_DATA_DIR}
Restart=always
RestartSec=10
EOF

  sudo systemctl enable klipper.service
  sudo systemctl enable moonraker.service

  print_status_header "Make sure to add ${SERVICE_USER} to the user group controlling your serial printer port"
}

start_software() {
  print_status_header "Launching Klipper and Moonraker host software..."
  sudo systemctl start klipper
  sudo systemctl start moonraker

  print_status_header "Launching mainsail container..."
  podman run \
    --detach \
    --replace \
    --name mainsail \
    -v "${PRINTER_DATA_DIR}/config/mainsail-config.json:/usr/share/nginx/html/config.json" \
    -p "8080:80" \
    ghcr.io/mainsail-crew/mainsail
}

print_status_header() {
  echo -e "\n\n################### $1 ###################\n"
}

set -e

create_directories
install_packages
user_permissions
apply_patches
create_virtualenvs
install_systemd_services
start_software
