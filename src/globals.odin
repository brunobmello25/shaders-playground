package main

import "core:log"

import model "model"
import "./shaders"

Globals :: struct {
	//shaders
	entity_shader:        shaders.Shader,
	light_shader:         shaders.Shader,

	//camera
	camera:               Camera,

	// input
	input:                Input,

	// entities
	using entity_globals: EntityGlobals,
	light_globals:        LightGlobals,

	// shared models
	container_model:      model.Model,
	bulb_model:           model.Model,
	backpack_model:       model.Model,
}

g: Globals

init_globals :: proc() {
	g.entity_shader = shaders.load(.Entity)

	g.camera = make_camera()

	ok: bool

	g.container_model, ok = model.load_model("res/container/container.obj")
	if !ok {
		log.panic("Failed to load container model")
	}

	g.bulb_model, ok = model.load_model("res/bulb/bulb.obj")
	if !ok {
		log.panic("Failed to load bulb model")
	}

	g.backpack_model, ok = model.load_model("res/backpack/backpack.obj")
	if !ok {
		log.panic("Failed to load backpack model")
	}

	setup_world_lights()
}
