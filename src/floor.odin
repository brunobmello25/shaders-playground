package main

import "core:math/linalg"

import sg "vendor/sokol/sokol/gfx"

import "config"
import helpers "helpers"
import model "model"
import shaders "shaders"

FLOOR_Y :: 0.0

floor_model: ^model.Model

init_floor :: proc() {
	floor_model = model.make_plane(1.0, diffuse = {12, 35, 48, 255})
}

draw_floor :: proc() {
	view, proj := view_and_projection(camera)

	sg.apply_pipeline(shaders.get(.Entity).pipeline)

	world_size := config.get().world_size
	floor_scale := linalg.matrix4_scale_f32(Vec3{world_size, 1.0, world_size})
	vs_params := shaders.Entity_Vs_Params {
		model         = floor_scale,
		view          = view,
		projection    = proj,
		normal_matrix = linalg.identity(Mat4),
	}
	sg.apply_uniforms(shaders.UB_Entity_VS_Params, helpers.range(&vs_params))

	fs_params := shaders.Entity_Fs_Params {
		view_pos  = camera.pos,
		shininess = 2.0,
		fog_start = config.get().fog.start,
		fog_end   = config.get().fog.end,
		fog_color = sky_color.rgb,
	}
	sg.apply_uniforms(shaders.UB_Entity_FS_Params, helpers.range(&fs_params))

	fs_lights := lights_to_shader_uniform()
	sg.apply_uniforms(shaders.UB_FS_Lights, helpers.range(&fs_lights))

	model.draw(floor_model, -1, 0)
}
