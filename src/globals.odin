package main

import "./shaders"

Globals :: struct {
	//shaders
	cube_shader:          shaders.Shader,
	light_shader:         shaders.Shader,

	// test cube
	cube_model:           Model,
	cube_pos:             Vec3,
	cube_diffuse_texture: Texture,

	// light
	light:                Light,

	//camera
	camera:               Camera,

	// input
	input:                Input,
}

g: Globals

init_globals :: proc() {
	g.cube_shader = shaders.load(.Cube)
	g.light_shader = shaders.load(.Light)

	g.cube_model = make_cube()
	g.cube_pos = Vec3{0.0, 0.0, 0.0}
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
