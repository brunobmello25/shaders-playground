#+feature dynamic-literals

package main

import "core:math"

import sapp "../sokol/app"
import sg "../sokol/gfx"
import stime "../sokol/time"
import linalg "core:math/linalg"

cube: Model
draw_many_cubes :: proc() {
	cube_positions: [dynamic][3]f32 = {{0.0, 0.0, 0.0}, {7.0, 0.0, 0.0}, {-7.0, 4.0, 0.0}}

	for pos in cube_positions {
		angle := f32(stime.ms(stime.now()) * 0.1)

		rotvec := linalg.normalize0([3]f32{1.0, 1.0, 0.0})
		model :=
			linalg.matrix4_translate_f32(pos) *
			linalg.matrix4_rotate_f32(math.to_radians(f32(angle)), rotvec)

		view := camera_to_view(camera)

		// fov := f32(45.0 + sin(stime.ms(stime.now()) * 0.0001) * 20.0)
		fov := f32(45.0)

		viewWidth := sapp.width()
		viewHeight := sapp.height()
		proj := linalg.matrix4_perspective_f32(
			fov,
			f32(viewWidth) / f32(viewHeight),
			0.1,
			100.0,
			false,
		)
		sg.apply_bindings(
			{
				vertex_buffers = {0 = cube.vertices},
				// index_buffer = quad.indices,
				views = {
					VIEW_containerTexture = containerTexture.view,
					VIEW_faceTexture = faceTexture.view,
				},
				samplers = {
					SMP_containerTextureSampler = containerTexture.sampler,
					SMP_faceTextureSampler = faceTexture.sampler,
				},
			},
		)
		params := Vsparams {
			model      = model,
			view       = view,
			projection = proj,
		}
		sg.apply_uniforms(UB_VSParams, range(&params))

		sg.draw(0, cube.vertex_count, 1)
	}
}

make_cube :: proc() -> Model {
	// odinfmt: disable
	vertices_data := [dynamic]f32{
		-0.5, -0.5, -0.5,  0.0, 0.0,
		 0.5, -0.5, -0.5,  1.0, 0.0,
		 0.5,  0.5, -0.5,  1.0, 1.0,
		 0.5,  0.5, -0.5,  1.0, 1.0,
		-0.5,  0.5, -0.5,  0.0, 1.0,
		-0.5, -0.5, -0.5,  0.0, 0.0,

		-0.5, -0.5,  0.5,  0.0, 0.0,
		 0.5, -0.5,  0.5,  1.0, 0.0,
		 0.5,  0.5,  0.5,  1.0, 1.0,
		 0.5,  0.5,  0.5,  1.0, 1.0,
		-0.5,  0.5,  0.5,  0.0, 1.0,
		-0.5, -0.5,  0.5,  0.0, 0.0,

		-0.5,  0.5,  0.5,  1.0, 0.0,
		-0.5,  0.5, -0.5,  1.0, 1.0,
		-0.5, -0.5, -0.5,  0.0, 1.0,
		-0.5, -0.5, -0.5,  0.0, 1.0,
		-0.5, -0.5,  0.5,  0.0, 0.0,
		-0.5,  0.5,  0.5,  1.0, 0.0,

		 0.5,  0.5,  0.5,  1.0, 0.0,
		 0.5,  0.5, -0.5,  1.0, 1.0,
		 0.5, -0.5, -0.5,  0.0, 1.0,
		 0.5, -0.5, -0.5,  0.0, 1.0,
		 0.5, -0.5,  0.5,  0.0, 0.0,
		 0.5,  0.5,  0.5,  1.0, 0.0,

		-0.5, -0.5, -0.5,  0.0, 1.0,
		 0.5, -0.5, -0.5,  1.0, 1.0,
		 0.5, -0.5,  0.5,  1.0, 0.0,
		 0.5, -0.5,  0.5,  1.0, 0.0,
		-0.5, -0.5,  0.5,  0.0, 0.0,
		-0.5, -0.5, -0.5,  0.0, 1.0,

		-0.5,  0.5, -0.5,  0.0, 1.0,
		 0.5,  0.5, -0.5,  1.0, 1.0,
		 0.5,  0.5,  0.5,  1.0, 0.0,
		 0.5,  0.5,  0.5,  1.0, 0.0,
		-0.5,  0.5,  0.5,  0.0, 0.0,
		-0.5,  0.5, -0.5,  0.0, 1.0
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
