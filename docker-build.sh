#!/bin/bash
set -e

# Script to build BalenaOS for Turing RK1 using balena-build.sh
# This handles all the Docker containerization and volume mounting properly

# Machine (default: turing-rk1)
MACHINE="${1:-turing-rk1}"
shift || true

# Clean build configuration to regenerate
echo "Cleaning build configuration..."
rm -rf build/conf
# bitbake -c cleanall balena-image

# Use balena-build.sh which handles containerized builds properly
echo "Building BalenaOS for ${MACHINE} using balena-build.sh..."
./balena-yocto-scripts/build/balena-build.sh \
  -d "${MACHINE}" \
  -s "$(pwd)" \
  "$@"

echo "Build complete! Output files in: build/tmp/deploy/images/${MACHINE}/"
