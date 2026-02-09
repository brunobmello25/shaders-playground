#!/bin/bash

# Check for assimp library first
if ! pkg-config --exists assimp; then
	echo "Assimp library not found on system."
	echo "Please install assimp library using your package manager:"
	echo "  Fedora: sudo dnf install assimp-devel"
	echo "  Ubuntu/Debian: sudo apt install libassimp-dev"
	echo "  Arch: sudo pacman -S assimp"
	exit 1
else
	echo "Assimp library found: $(pkg-config --modversion assimp)"
fi

# Setup assimp bindings
if [ ! -d "./src/vendor/assimp" ]; then
	echo "Setting up assimp bindings..."
	git submodule update --init --recursive src/vendor/assimp
	if [ $? -ne 0 ]; then
		echo "Failed to initialize assimp submodule."
		exit 1
	fi
	echo "Assimp bindings installed."
else
	echo "Assimp bindings already exist, skipping."
fi
