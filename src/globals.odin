package main

import "./shaders"

Globals :: struct {
	//shaders
	entity_shader:        shaders.Shader,
	light_shader:         shaders.Shader,

	// test cube
	cube_diffuse_texture: Texture,

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

	g.cube_diffuse_texture = load_texture("res/container2.png")

	g.light = Light {
		position = {1.2, 1.0, 2.0},
		ambient  = {0.2, 0.2, 0.2},
		diffuse  = {0.5, 0.5, 0.5},
		specular = {1.0, 1.0, 1.0},
		model    = make_cube(),
	}

	g.camera = make_camera()
}
