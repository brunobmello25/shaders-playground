package main

import "base:runtime"
import "core:log"

import sapp "../sokol/app"
import sg "../sokol/gfx"
import sglue "../sokol/glue"
import shelpers "../sokol/helpers"

our_context: runtime.Context
pipeline: sg.Pipeline

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

	sg.setup(
		{environment = sglue.environment(), logger = sg.Logger(shelpers.logger(&our_context))},
	)

	shader := sg.make_shader(main_shader_desc(sg.query_backend()))
	pipeline = sg.make_pipeline(
		{
			shader = shader,
			layout = {attrs = {}},
			index_type = .UINT32,
			depth = {compare = .LESS_EQUAL, write_enabled = true},
		},
	)

}

cleanup :: proc "c" () {}

frame :: proc "c" () {
	sg.begin_pass(
		{
			swapchain = sglue.swapchain(),
			action = {
				depth = {load_action = .CLEAR, clear_value = 1.0},
				colors = {0 = {load_action = .CLEAR, clear_value = {1, 0, 1, 1}}},
			},
		},
	)
	sg.apply_pipeline(pipeline)
	sg.end_pass()
}

event :: proc "c" (event: ^sapp.Event) {}
