#+feature dynamic-literals

package main

import "base:runtime"
import "core:log"
import "core:math"
import linalg "core:math/linalg"

import sapp "../sokol/app"
import sg "../sokol/gfx"
import sglue "../sokol/glue"
import shelpers "../sokol/helpers"
import stime "../sokol/time"

our_context: runtime.Context
pipeline: sg.Pipeline

Quad :: struct {
	vertices:      sg.Buffer,
	indices:       sg.Buffer,
	indices_count: int,
	vertex_count:  int,
}

Texture :: struct {
	image:   sg.Image,
	sampler: sg.Sampler,
	view:    sg.View,
}

quad: Quad
containerTexture: Texture
faceTexture: Texture

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

main :: proc() {
	context.logger = log.create_console_logger()
	our_context = context

	sapp.run(
		{
			width = 800,
			height = 800,
			window_title = "Game - Shaders Playground",
			init_cb = init,
			frame_cb = frame,
			event_cb = event,
			cleanup_cb = cleanup,
			logger = sapp.Logger(shelpers.logger(&our_context)),
		},
	)
}

init :: proc "c" () {
	context = our_context

	pos := Vec4{1.0, 0.0, 0.0, 1.0}

	pos = make_translation_matrix(1, 1, 0) * pos
	log.debug(pos)

	stime.setup()

	sg.setup(
		{environment = sglue.environment(), logger = sg.Logger(shelpers.logger(&our_context))},
	)

	shader := sg.make_shader(main_shader_desc(sg.query_backend()))
	pipeline = sg.make_pipeline(
		{
			shader = shader,
			layout = {
				attrs = {
					ATTR_main_aPos = {format = .FLOAT3},
					ATTR_main_aTextCoord = {format = .FLOAT2},
				},
			},
			// index_type = .UINT32,
			depth = {compare = .LESS_EQUAL, write_enabled = true},
		},
	)

	quad = make_quad()
	containerTexture = load_texture("res/container.jpg")
	faceTexture = load_texture("res/awesomeface.png")
}

cleanup :: proc "c" () {
	context = our_context
}

frame :: proc "c" () {
	context = our_context


	sg.begin_pass(
		{
			swapchain = sglue.swapchain(),
			action    = {
				// colors = {0 = {load_action = .CLEAR, clear_value = {1, 0, 1, 1}}},
				// TODO: what is this?
				// depth = {load_action = .CLEAR, clear_value = 1.0},
			},
		},
	)
	sg.apply_pipeline(pipeline)

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

		view := make_translation_matrix(0.0, 0.0, -5.0) * make_identity_matrix()

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
				vertex_buffers = {0 = quad.vertices},
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

		sg.draw(0, quad.vertex_count, 1)
	}

	sg.end_pass()
}

event :: proc "c" (event: ^sapp.Event) {
	context = our_context
}
