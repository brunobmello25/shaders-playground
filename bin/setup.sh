#!/bin/bash

set -e

echo "=== Shaders Playground Setup ==="
echo

# Check for assimp library
echo "Checking for assimp library..."
if ! pkg-config --exists assimp; then
	echo "ERROR: Assimp library not found on system."
	echo "Please install assimp library using your package manager:"
	echo "  Fedora: sudo dnf install assimp-devel"
	echo "  Ubuntu/Debian: sudo apt install libassimp-dev"
	echo "  Arch: sudo pacman -S assimp"
	exit 1
else
	echo "✓ Assimp library found: $(pkg-config --modversion assimp)"
fi
echo

# Initialize all submodules
if [ ! -d "./src/vendor/sokol" ] || [ ! -d "./src/vendor/assimp" ]; then
	echo "Initializing git submodules..."
	git submodule update --init --recursive
	echo "✓ Submodules initialized"
else
	echo "✓ Submodules already initialized"
fi
echo

# Build sokol C libraries
if [ -d "./src/vendor/sokol/sokol" ]; then
	echo "Building sokol C libraries..."
	pushd ./src/vendor/sokol/sokol > /dev/null
	./build_clibs_linux.sh
	popd > /dev/null
	echo "✓ Sokol C libraries built"
else
	echo "ERROR: Sokol directory not found"
	exit 1
fi
echo

# Setup sokol shader compiler
if [ ! -f "./bin/sokol-shdc" ]; then
	echo "Setting up sokol shader compiler..."
	git clone --quiet git@github.com:floooh/sokol-tools-bin.git
	mv ./sokol-tools-bin/bin/linux/sokol-shdc ./bin/sokol-shdc
	rm -rf ./sokol-tools-bin
	echo "✓ Sokol shader compiler installed"
else
	echo "✓ Sokol shader compiler already exists"
fi
echo

echo "=== Setup complete! ==="
echo "Run './bin/build.sh' to build the project"
