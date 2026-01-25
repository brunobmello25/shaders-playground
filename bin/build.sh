#!/bin/bash

BUILD_SOKOL=${BUILD_SOKOL:-false}
BUILD_SHADERS=${BUILD_SHADERS:-true}
BUILD_GAME=${BUILD_GAME:-true}

mkdir -p ./target

if [ "$BUILD_SOKOL" = "true" ]; then
	pushd ./sokol
	./build_clibs_linux.sh
	popd
fi

if [ "$BUILD_SHADERS" = "true" ]; then
	pushd ./src
	../bin/sokol-shdc --input ./shader.glsl --output ./shader_generated.odin --slang glsl430:glsl300es --format sokol_odin
	popd
fi

if [ "$BUILD_GAME" = "true" ]; then
	pushd ./target
	odin build ../src -out=./game -debug -vet -error-pos-style:unix
	popd
fi

