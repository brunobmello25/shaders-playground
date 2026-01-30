#+feature dynamic-literals

package main

import "core:math"

import sapp "../sokol/app"
import sg "../sokol/gfx"
import stime "../sokol/time"
import linalg "core:math/linalg"

cube: Model
draw_many_cubes :: proc() {
	cube_positions: [dynamic][3]f32 = {
		{0.0, 0.0, 0.0},
		{2.0, 5.0, -15.0},
		{-1.5, -2.2, -2.5},
		{-3.8, -2.0, -12.3},
		{2.4, -0.4, -3.5},
		{-1.7, 3.0, -7.5},
		{1.3, -2.0, -2.5},
		{1.5, 2.0, -2.5},
		{1.5, 0.2, -1.5},
		{-1.3, 1.0, -1.5},
	}

	for pos, i in cube_positions {
		angle: f32
		if i % 3 == 0 {
			angle = f32(stime.ms(stime.now()) * 0.1)
		} else {
			angle = 0
		}

		rotvec := linalg.normalize0([3]f32{1.0, 1.0, 0.0})
		model :=
			make_translation_matrix(pos.x, pos.y, pos.z) *
			make_rotation_matrix(math.to_radians(f32(angle)), rotvec.x, rotvec.y, rotvec.z) *
			make_identity_matrix()

		view := camera_to_view(camera, Vec3{0, 1, 0})

		// fov := f32(45.0 + sin(stime.ms(stime.now()) * 0.0001) * 20.0)
		fov := f32(45.0)

		viewWidth := sapp.width()
		viewHeight := sapp.height()
		proj := linalg.matrix4_perspective_f32(
			fov,
			f32(viewWidth) / f32(viewHeight),
			0.1,
			100.0,
			true,
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
