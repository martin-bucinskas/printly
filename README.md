# Printly

All in one suite to manage your 3D printer.

## Features

- Klipper
- Moonraker
- MainSail

## Installation

```bash
git clone --recurse-submodules git@github.com:martin-bucinskas/printly.git
chmod +x scripts/01-install.sh
chmod +x scripts/02-start.sh
chmod +x scripts/03-reload-configs.sh

./scripts/01-install.sh
./scripts/02-start.sh
```

This assumes that you've got Podman installed on your system.

## Todo

- move moonraker to a container
- check if we can move klipper to a container
