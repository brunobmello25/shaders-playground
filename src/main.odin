package main

import "base:runtime"
import "core:log"

import sapp "../sokol/app"
import sg "../sokol/gfx"
import sglue "../sokol/glue"
import shelpers "../sokol/helpers"
import stime "../sokol/time"

our_context: runtime.Context
pipeline: sg.Pipeline
// odinfmt: disable
triangle_vertices: []f32 = {
	 // positions
	 0.5, -0.5, 0.0, 1.0, 0.0, 0.0,
	-0.5, -0.5, 0.0, 0.0, 1.0, 0.0,
	 0.0,  0.5, 0.0, 0.0, 0.0, 1.0,
}
triangle_buffer: sg.Buffer
triangle_indices: []u32 = {
	0, 1, 2,
}
// odinfmt: enable
triangle_index_buffer: sg.Buffer

main :: proc() {
	context.logger = log.create_console_logger()
	our_context = context

	sapp.run(
		{
			width = 1920 / 2,
			height = 1080 / 2,
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
					ATTR_main_aColor = {format = .FLOAT3},
				},
			},
			index_type = .UINT32,
			// depth = {compare = .LESS_EQUAL, write_enabled = true},
		},
	)

	triangle_buffer = sg.make_buffer(
		{
			data = sg.Range {
				ptr = raw_data(triangle_vertices[:]),
				size = len(triangle_vertices) * size_of(f32),
			},
		},
	)
	triangle_index_buffer = sg.make_buffer(
		{
			data = sg.Range {
				ptr = raw_data(triangle_indices[:]),
				size = len(triangle_indices) * size_of(u32),
			},
			usage = {index_buffer = true},
		},
	)
}

cleanup :: proc "c" () {}

frame :: proc "c" () {
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

	sg.apply_bindings(
		{vertex_buffers = {0 = triangle_buffer}, index_buffer = triangle_index_buffer},
	)
	sg.draw(0, len(triangle_indices), 1)

	sg.end_pass()
}

event :: proc "c" (event: ^sapp.Event) {}
