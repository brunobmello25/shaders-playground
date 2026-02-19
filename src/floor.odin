package main

import "core:math/linalg"

import sg "vendor/sokol/sokol/gfx"

import model "model"
import shaders "shaders"

FLOOR_Y :: 0.0
FLOOR_SIZE :: 100.0

floor_model: ^model.Model

init_floor :: proc() {
	floor_model = model.make_plane(FLOOR_SIZE, diffuse = {12, 35, 48, 255})
}

draw_floor :: proc() {
	view, proj := view_and_projection(camera)

	sg.apply_pipeline(shaders.get(.Entity).pipeline)

	vs_params := shaders.Entity_Vs_Params {
		model         = linalg.identity(Mat4),
		view          = view,
		projection    = proj,
		normal_matrix = linalg.identity(Mat4),
	}
	sg.apply_uniforms(shaders.UB_Entity_VS_Params, range(&vs_params))

	fs_params := shaders.Entity_Fs_Params {
		view_pos  = camera.pos,
		shininess = 32.0,
	}
	sg.apply_uniforms(shaders.UB_Entity_FS_Params, range(&fs_params))

	fs_lights := lights_to_shader_uniform()
	sg.apply_uniforms(shaders.UB_FS_Lights, range(&fs_lights))

	model.draw(floor_model, -1, 0)
}
