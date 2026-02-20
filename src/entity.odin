package main

import "core:log"
import "core:math/linalg"

import sg "vendor/sokol/sokol/gfx"

import model "model"
import shaders "shaders"

MAX_ENTITIES :: 100

EntityKind :: enum {
	nil,
	Character,
	Picadrill,
}

EntityHandle :: struct {
	id:       int,
	index:    int,
	position: Vec3,
}

Entity :: struct {
	kind:           EntityKind,
	handle:         EntityHandle,

	// drawing
	model:          ^model.Model,
	scale:          Vec3,
	position:       Vec3,
	animation_idx:  int,
	animation_time: f64,

	// procedures
	update:         proc(e: ^Entity),
	draw:           proc(e: ^Entity, camera: Camera),
}

entities: [MAX_ENTITIES]Entity
next_available_entity_index: int

setup_picadrill :: proc(e: ^Entity) {
	e.kind = .Picadrill

	e.model = model.load(.Picadrill) or_else panic("Failed to load picadrill model") // TODO: handle model not loading someday?

	e.animation_idx = -1

	e.draw = entity_draw
}

setup_character :: proc(e: ^Entity) {
	e.kind = .Character

	e.model = model.load(.CharacterLowPoly) or_else panic("Failed to load character model") // TODO: handle model not loading someday?

	e.animation_idx = 0
	e.update = proc(e: ^Entity) {
		if was_action_just_pressed(input, .RIGHT) {
			e.animation_idx = (e.animation_idx + 1) % len(e.model.animations)
			e.animation_time = 0.0
			log.debugf("Switched to animation index %d", e.animation_idx)
		}
		if was_action_just_pressed(input, .LEFT) {
			e.animation_idx =
				(e.animation_idx - 1 + len(e.model.animations)) % len(e.model.animations)
			e.animation_time = 0.0
			log.debugf("Switched to animation index %d", e.animation_idx)
		}

		e.animation_time += f64(dt)
	}

	e.draw = entity_draw
}

// TODO: add proper asserts here
entity_create :: proc() -> ^Entity {
	// TODO: also should create a free list
	if next_available_entity_index >= MAX_ENTITIES {
		panic("Max entities reached")
	}

	index := next_available_entity_index
	next_available_entity_index += 1

	entity := &entities[index]

	entity.handle = EntityHandle {
		id    = index, // TODO: this should be a generation id
		index = index,
	}
	entity.scale = Vec3{1.0, 1.0, 1.0}
	entity.position = Vec3{0.0, 0.0, 0.0}
	entity.animation_idx = -1

	entity.update = proc(e: ^Entity) {}
	entity.draw = proc(e: ^Entity, camera: Camera) {}

	return entity
}

entity_draw :: proc(e: ^Entity, camera: Camera) {
	model_matrix := linalg.matrix4_translate_f32(e.position) * linalg.matrix4_scale_f32(e.scale)
	normal_matrix := linalg.transpose(linalg.inverse(model_matrix))

	view, proj := view_and_projection(camera)

	sg.apply_pipeline(shaders.get(.Entity).pipeline)

	vs_params := shaders.Entity_Vs_Params {
		model         = model_matrix,
		view          = view,
		projection    = proj,
		normal_matrix = normal_matrix,
	}
	sg.apply_uniforms(shaders.UB_Entity_VS_Params, range(&vs_params))

	fs_params := shaders.Entity_Fs_Params {
		view_pos  = camera.pos,
		shininess = 32.0, // TODO: hardcoded
	}
	sg.apply_uniforms(shaders.UB_Entity_FS_Params, range(&fs_params))
	fs_lights := lights_to_shader_uniform()
	sg.apply_uniforms(shaders.UB_FS_Lights, range(&fs_lights))

	model.draw(e.model, e.animation_idx, e.animation_time)
}
