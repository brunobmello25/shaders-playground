#+feature dynamic-literals

package main

import "core:math"

import sg "../sokol/gfx"
import stime "../sokol/time"
import linalg "core:math/linalg"


global_cube_model: Model
cube_pos: Vec3 = {0.0, 0.0, 0.0}

draw_cube :: proc() {
	angle := f32(stime.ms(stime.now()) * 0.1)
	rotvec := linalg.normalize0([3]f32{1.0, 1.0, 0.0})

	model :=
		linalg.matrix4_translate_f32(cube_pos) *
		linalg.matrix4_rotate_f32(math.to_radians(f32(angle)), rotvec)

	view, proj := view_and_projection()

	sg.apply_pipeline(cube_shader.pipeline)
	sg.apply_bindings(
		{
			vertex_buffers = {0 = global_cube_model.vertices},
			// index_buffer = quad.indices,
		},
	)
	vs_params := Cubevsparams {
		model      = model,
		view       = view,
		projection = proj,
	}
	sg.apply_uniforms(UB_CubeVSParams, range(&vs_params))
	fs_params := Cubefsparams {
		cubeColor  = Vec3{1.0, 0.5, 0.31},
		lightColor = Vec3{1.0, 1.0, 1.0},
	}
	sg.apply_uniforms(UB_CubeFSParams, range(&fs_params))

	sg.draw(0, global_cube_model.vertex_count, 1)
}

make_cube :: proc() -> Model {
	// odinfmt: disable
	vertices_data := [dynamic]f32{
		-0.5, -0.5, -0.5,
		 0.5, -0.5, -0.5,
		 0.5,  0.5, -0.5,
		 0.5,  0.5, -0.5,
		-0.5,  0.5, -0.5,
		-0.5, -0.5, -0.5,

		-0.5, -0.5,  0.5,
		 0.5, -0.5,  0.5,
		 0.5,  0.5,  0.5,
		 0.5,  0.5,  0.5,
		-0.5,  0.5,  0.5,
		-0.5, -0.5,  0.5,

		-0.5,  0.5,  0.5,
		-0.5,  0.5, -0.5,
		-0.5, -0.5, -0.5,
		-0.5, -0.5, -0.5,
		-0.5, -0.5,  0.5,
		-0.5,  0.5,  0.5,

		 0.5,  0.5,  0.5,
		 0.5,  0.5, -0.5,
		 0.5, -0.5, -0.5,
		 0.5, -0.5, -0.5,
		 0.5, -0.5,  0.5,
		 0.5,  0.5,  0.5,

		-0.5, -0.5, -0.5,
		 0.5, -0.5, -0.5,
		 0.5, -0.5,  0.5,
		 0.5, -0.5,  0.5,
		-0.5, -0.5,  0.5,
		-0.5, -0.5, -0.5,

		-0.5,  0.5, -0.5,
		 0.5,  0.5, -0.5,
		 0.5,  0.5,  0.5,
		 0.5,  0.5,  0.5,
		-0.5,  0.5,  0.5,
		-0.5,  0.5, -0.5,
	}
	// indices_data: [dynamic]u32 = {
	// }
	// odinfmt: enable

	vertices_buffer := sg.make_buffer(
		{data = range(vertices_data[:]), size = len(vertices_data) * size_of(vertices_data[0])},
	)
	// indices_buffer := sg.make_buffer(
	// 	{
	// 		data = range(indices_data[:]),
	// 		size = len(indices_data) * size_of(indices_data[0]),
	// 		usage = {index_buffer = true},
	// 	},
	// )

	return Model{vertices = vertices_buffer, indices = {}, vertex_count = 36, indices_count = 0}
}
