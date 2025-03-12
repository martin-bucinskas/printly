#!/usr/bin/env bash
# This script installs printly and all its components on an Arch Linux system.

ENV_DIR="$(pwd)/.envs"
KLIPPY_ENV="${ENV_DIR}/klippy-env"
MOONRAKER_ENV="${ENV_DIR}/moonraker-env"
PRINTER_DATA_DIR="$(pwd)/.printer_data"

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

create_virtualenvs() {
    print_status_header "Creating python virtual environments..."
    source "${KLIPPY_ENV}/bin/activate"
    pip install -r "$(pwd)/services/klipper/scripts/klippy-requirements.txt"
    deactivate

    source "${MOONRAKER_ENV}/bin/activate"
    pip install -r "$(pwd)/services/moonraker/requirements.txt"
    deactivate
}

print_status_header() {
  echo -e "\n\n################### $1 ###################\n"
}