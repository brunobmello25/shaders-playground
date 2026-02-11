package main

import "core:math/linalg"

import sg "vendor/sokol/sokol/gfx"

import shaders "shaders"

MAX_ENTITIES :: 100

EntityKind :: enum {
	nil,
	Container,
	LightSource,
}

EntityHandle :: struct {
	id:       int,
	index:    int,
	position: Vec3,
}

Entity :: struct {
	kind:                      EntityKind,
	handle:                    EntityHandle,

	// drawing
	model:                     DEPRECATED_Model,
	scale:                     Vec3,
	position:                  Vec3,
	diffuse_texture:           DEPRECATED_Texture,
	specular_texture:          DEPRECATED_Texture,

	// procedures
	update:                    proc(e: ^Entity),
	draw:                      proc(e: ^Entity, camera: Camera),

	// light handle for light sources
	light_source_light_handle: LightHandle,
}

EntityGlobals :: struct {
	entities:             [MAX_ENTITIES]Entity,
	next_available_index: int,
}

// TODO: add proper asserts here
entity_create :: proc() -> ^Entity {
	// TODO: also should create a free list
	if g.entity_globals.next_available_index >= MAX_ENTITIES {
		panic("Max entities reached")
	}

	index := g.entity_globals.next_available_index
	g.entity_globals.next_available_index += 1

	handle := EntityHandle {
		id    = index, // TODO: this should be a generation id
		index = index,
	}

	entity := &g.entity_globals.entities[index]
	entity.handle = handle
	return entity
}

setup_light_source :: proc(e: ^Entity, pos: Vec3, light_handle: LightHandle) {
	e.kind = .LightSource
	e.model = make_cube()
	e.scale = Vec3{0.2, 0.2, 0.2}
	e.position = pos
	e.diffuse_texture = make_white_texture()
	e.specular_texture = make_white_texture()
	e.light_source_light_handle = light_handle

	e.update = proc(e: ^Entity) {
	}

	e.draw = proc(e: ^Entity, camera: Camera) {
		model_matrix :=
			linalg.matrix4_translate_f32(e.position) * linalg.matrix4_scale_f32(e.scale)
		normal_matrix := linalg.transpose(linalg.inverse(model_matrix))

		view, proj := view_and_projection(camera)

		sg.apply_pipeline(g.entity_shader.pipeline)
		sg.apply_bindings(
			{
				vertex_buffers = {0 = e.model.vertices},
				index_buffer = e.model.indices,
				views = {
					shaders.VIEW_entity_diffuse_texture = e.diffuse_texture.view,
					shaders.VIEW_entity_specular_texture = e.specular_texture.view,
				},
				samplers = {
					shaders.SMP_entity_diffuse_sampler = e.diffuse_texture.sampler,
					shaders.SMP_entity_specular_sampler = e.specular_texture.sampler,
				},
			},
		)
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

		sg.draw(0, i32(e.model.indices_count), 1)
	}
}

setup_container :: proc(e: ^Entity) {
	e.kind = .Container

	e.model = make_cube()
	e.scale = Vec3{1.0, 1.0, 1.0}
	e.position = Vec3{0.0, 0.0, 0.0}
	e.diffuse_texture = load_texture("res/container_diffuse.png")
	e.specular_texture = load_texture("res/container_specular.png")

	e.update = proc(e: ^Entity) {
	}

	e.draw = proc(e: ^Entity, camera: Camera) {
		// TODO: generalize this for other entities
		model_matrix := linalg.matrix4_translate_f32(e.position)
		normal_matrix := linalg.transpose(linalg.inverse(model_matrix))

		view, proj := view_and_projection(camera)

		sg.apply_pipeline(g.entity_shader.pipeline)
		sg.apply_bindings(
			{
				vertex_buffers = {0 = e.model.vertices},
				index_buffer = e.model.indices,
				views = {
					shaders.VIEW_entity_diffuse_texture = e.diffuse_texture.view,
					shaders.VIEW_entity_specular_texture = e.specular_texture.view,
				},
				samplers = {
					shaders.SMP_entity_diffuse_sampler = e.diffuse_texture.sampler,
					shaders.SMP_entity_specular_sampler = e.specular_texture.sampler,
				},
			},
		)
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

		sg.draw(0, i32(e.model.indices_count), 1)
	}
}
