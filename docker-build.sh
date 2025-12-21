#!/bin/bash
set -e

# Build the Docker image
echo "Building Docker image..."
docker build -t yocto-rk1-builder \
  --build-arg USER_ID=$(id -u) \
  --build-arg GROUP_ID=$(id -g) \
  .

# Clean only conf to regenerate for Docker environment
# Keep sstate-cache and downloads to speed up rebuilds
echo "Cleaning build configuration for Docker environment..."
rm -rf build/conf

# Run the build in Docker container
echo "Starting Docker container..."
docker run -it --rm \
  -v "$(pwd):/workdir" \
  -w /workdir \
  --user $(id -u):$(id -g) \
  yocto-rk1-builder \
  bash -c './build.sh'
