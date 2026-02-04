package main

import "core:math/linalg"

import sg "../sokol/gfx"

import shaders "shaders"

Light :: struct {
	position: Vec3,
	ambient:  Vec3,
	diffuse:  Vec3,
	specular: Vec3,
	model:    Model,
}

update_light_color_over_time :: proc(light: ^Light) {
	// time := stime.sec(stime.now())
	// light_color: Vec3
	//
	// light_color.x = f32(math.sin(time * 2))
	// light_color.y = f32(math.sin(time * 0.7))
	// light_color.z = f32(math.sin(time * 1.3))
	//
	// light.diffuse = light_color * Vec3{0.5, 0.5, 0.5}
	// light.ambient = light.diffuse * Vec3{0.2, 0.2, 0.2}
}

make_global_light :: proc() -> Light {
	return Light {
		position = {1.2, 1.0, 2.0},
		ambient = {0.2, 0.2, 0.2},
		diffuse = {0.5, 0.5, 0.5},
		specular = {1.0, 1.0, 1.0},
		model = make_cube(),
	}
}

draw_light :: proc(camera: Camera) {
	model :=
		linalg.matrix4_translate_f32(g.light.position) *
		linalg.matrix4_scale_f32(Vec3{0.2, 0.2, 0.2})

	view, proj := view_and_projection(camera)

	sg.apply_pipeline(g.light_shader.pipeline)
	sg.apply_bindings({vertex_buffers = {0 = g.light.model.vertices}})

	vs_params := shaders.Lightvsparams {
		model      = model,
		view       = view,
		projection = proj,
	}
	sg.apply_uniforms(shaders.UB_LightVSParams, range(&vs_params))
	fs_params := shaders.Lightfsparams {
		lightColor = g.light.diffuse,
	}
	sg.apply_uniforms(shaders.UB_LightFSParams, range(&fs_params))

	sg.draw(0, g.light.model.vertex_count, 1)
}
