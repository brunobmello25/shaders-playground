#!/bin/bash

BUILD_SOKOL=${BUILD_SOKOL:-false}
BUILD_SHADERS=${BUILD_SHADERS:-true}
BUILD_GAME=${BUILD_GAME:-true}

mkdir -p ./target

if [ "$BUILD_SOKOL" = "true" ]; then
	pushd ./src/vendor/sokol/sokol
	./build_clibs_linux.sh
	popd
fi

if [ "$BUILD_SHADERS" = "true" ]; then
	pushd ./src/shaders
	for shader in ./*.glsl; do
		basename="${shader##*/}"
		basename="${basename%.glsl}"
		name="${basename#shader_}"
		../../bin/sokol-shdc --input "$shader" --output "generated_${name}.odin" --slang glsl430:glsl300es --format sokol_odin
	done
	popd
fi

if [ "$BUILD_GAME" = "true" ]; then
	pushd ./target
	# odin build ../src -out=./game -vet-packages:main,model -vet-unused -vet-unused-imports -vet-unused-procedures -vet-unused-variables -vet-using-param -vet-using-stmt -debug -error-pos-style:unix
	odin build ../src -out=./game -debug -error-pos-style:unix
	popd
fi

