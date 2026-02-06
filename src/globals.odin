package main

import "./shaders"

Globals :: struct {
	//shaders
	entity_shader:         shaders.Shader,
	light_shader:          shaders.Shader,

	//camera
	camera:                Camera,

	// input
	input:                 Input,

	// entities
	using entity_globals:  EntityGlobals,
	using texture_globals: TextureGlobals,
	light_globals:         LightGlobals,
}

g: Globals

init_globals :: proc() {
	g.entity_shader = shaders.load(.Entity)

	g.camera = make_camera()

	setup_world_lights()
}
