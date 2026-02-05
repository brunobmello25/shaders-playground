package main

import "./shaders"

Globals :: struct {
	//shaders
	entity_shader:        shaders.Shader,
	light_shader:         shaders.Shader,

	// light
	light:                Light,

	//camera
	camera:               Camera,

	// input
	input:                Input,

	// entities
	using entity_globals: EntityGlobals,
}

g: Globals

init_globals :: proc() {
	g.entity_shader = shaders.load(.Entity)
	g.light_shader = shaders.load(.Light)

	g.light = make_global_light()

	g.camera = make_camera()
}
