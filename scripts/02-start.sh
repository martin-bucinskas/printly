#!/usr/bin/env bash
# This script starts all the services needed to run a 3D printer

PRINTER_DATA_DIR="$(pwd)/.printer_data"

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

start_software
