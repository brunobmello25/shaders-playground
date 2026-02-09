#!/bin/bash

# Setup sokol bindings
if [ ! -d "./src/vendor/sokol" ]; then
	echo "Setting up sokol bindings..."
	git submodule update --init --recursive src/vendor/sokol
	pushd ./src/vendor/sokol/sokol
	./build_clibs_linux.sh
	popd
	echo "Sokol bindings installed."
else
	echo "Sokol bindings already exist, skipping."
fi

# Setup sokol shader compiler
if [ ! -f "./bin/sokol-shdc" ]; then
	echo "Setting up sokol shader compiler..."
	git clone git@github.com:floooh/sokol-tools-bin.git
	mv ./sokol-tools-bin/bin/linux/sokol-shdc ./bin/sokol-shdc
	rm -rf ./sokol-tools-bin
	echo "Sokol shader compiler installed."
else
	echo "Sokol shader compiler already exists, skipping."
fi

