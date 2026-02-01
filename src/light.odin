package main

import sg "../sokol/gfx"
import linalg "core:math/linalg"


global_light_model: Model
light_pos: Vec3 = {5, 5, 5}

draw_light :: proc() {
	model :=
		linalg.matrix4_scale_f32(Vec3{0.2, 0.2, 0.2}) * linalg.matrix4_translate_f32(light_pos)

	view, proj := view_and_projection()

	sg.apply_pipeline(light_shader.pipeline)
	sg.apply_bindings({vertex_buffers = {0 = global_light_model.vertices}})

	vs_params := Lightvsparams {
		model      = model,
		view       = view,
		projection = proj,
	}
	sg.apply_uniforms(UB_LightVSParams, range(&vs_params))

	sg.draw(0, global_light_model.vertex_count, 1)
}
