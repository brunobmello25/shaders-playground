package main

import "./shaders"

Globals :: struct {
	// timing
	dt:                   f32,
	last_time:            u64,

	//shaders
	entity_shader:        shaders.Shader,

	//camera
	camera:               Camera,

	// input
	input:                Input,

	// entities
	using entity_globals: EntityGlobals,

	// lights
	using light_globals:  LightGlobals,

	// floor
	floor:                FloorGlobals,
}

g: Globals

init_globals :: proc() {
	g.entity_shader = shaders.load(.Entity)

	g.camera = make_camera()

	setup_world_lights()

	init_floor()
}
