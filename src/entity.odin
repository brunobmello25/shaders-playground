package main

import "core:math/linalg"

import sg "../sokol/gfx"

import shaders "shaders"

MAX_ENTITIES :: 100

EntityKind :: enum {
	nil,
	Cube,
}

EntityHandle :: struct {
	id:       int,
	index:    int,
	position: Vec3,
}

Entity :: struct {
	kind:     EntityKind,
	model:    Model,
	scale:    Vec3,
	position: Vec3,
	update:   proc(e: ^Entity),
	draw:     proc(e: ^Entity, camera: Camera),
}

EntityGlobals :: struct {
	entities:             [MAX_ENTITIES]Entity,
	next_available_index: int,
}

entity_create :: proc() -> ^Entity {
	if g.entity_globals.next_available_index >= MAX_ENTITIES {
		panic("Max entities reached")
	}

	index := g.entity_globals.next_available_index
	g.entity_globals.next_available_index += 1

	return &g.entity_globals.entities[index]
}

setup_cube :: proc(e: ^Entity) {
	e.kind = .Cube

	e.model = make_cube()
	e.scale = Vec3{1.0, 1.0, 1.0}
	e.position = Vec3{0.0, 0.0, 0.0}

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
				views = {
					shaders.VIEW_entity_diffuse_texture = g.cube_diffuse_texture.view,
					shaders.VIEW_entity_specular_texture = g.cube_specular_texture.view,
				},
				samplers = {
					shaders.SMP_entity_diffuse_sampler = g.cube_diffuse_texture.sampler,
					shaders.SMP_entity_specular_sampler = g.cube_specular_texture.sampler,
				},
				// index_buffer = quad.indices,
			},
		)
		vs_params := shaders.Entity_Vs_Params {
			model        = model_matrix,
			view         = view,
			projection   = proj,
			normalMatrix = normal_matrix,
		}
		sg.apply_uniforms(shaders.UB_Entity_VS_Params, range(&vs_params))

		fs_params := shaders.Entity_Fs_Params {
			viewPos = camera.pos,
		}
		sg.apply_uniforms(shaders.UB_Entity_FS_Params, range(&fs_params))
		cube_fs_material := shaders.Entity_Fs_Material {
			shininess = 32.0,
		}
		sg.apply_uniforms(shaders.UB_Entity_FS_Material, range(&cube_fs_material))
		cube_fs_light := shaders.Entity_Fs_Light {
			position = g.light.position,
			ambient  = g.light.ambient,
			diffuse  = g.light.diffuse,
			specular = g.light.specular,
		}
		sg.apply_uniforms(shaders.UB_Entity_FS_Light, range(&cube_fs_light))

		sg.draw(0, e.model.vertex_count, 1)
	}
}
