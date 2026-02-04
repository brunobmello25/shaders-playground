package main

import "./shaders"

Globals :: struct {
	//shaders
	entity_shader:         shaders.Shader,
	light_shader:          shaders.Shader,

	// test cube
	cube_diffuse_texture:  Texture,
	cube_specular_texture: Texture,

	// light
	light:                 Light,

	//camera
	camera:                Camera,

	// input
	input:                 Input,

	// entities
	using entity_globals:  EntityGlobals,
}

g: Globals

init_globals :: proc() {
	g.entity_shader = shaders.load(.Entity)
	g.light_shader = shaders.load(.Light)

	g.cube_diffuse_texture = load_texture("res/container_diffuse.png")
	g.cube_specular_texture = load_texture("res/container_specular.png")

	g.light = make_global_light()

	g.camera = make_camera()
}
