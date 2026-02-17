
package main

import "base:runtime"
import "core:log"

import sapp "vendor/sokol/sokol/app"
import sg "vendor/sokol/sokol/gfx"
import sglue "vendor/sokol/sokol/glue"
import shelpers "vendor/sokol/sokol/helpers"
import stime "vendor/sokol/sokol/time"

our_context: runtime.Context

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

	set_mouse_lock(false)

	stime.setup()

	sg.setup(
		{
			environment      = sglue.environment(),
			logger           = sg.Logger(shelpers.logger(&our_context)),
			buffer_pool_size = 512, // Increased from default 128 to handle large models
			image_pool_size  = 512, // Also increase image pool for textures
		},
	)

	init_globals()

	ch := entity_create()
	setup_character(ch)
}

cleanup :: proc "c" () {
	context = our_context
}

frame :: proc "c" () {
	context = our_context

	sg.begin_pass(
		{
			swapchain = sglue.swapchain(),
			action = {
				colors = {0 = {load_action = .CLEAR, clear_value = {0.1, 0.1, 0.1, 1}}},
				depth = {load_action = .CLEAR, clear_value = 1.0},
			},
		},
	)

	update_camera(&g.camera, &g.input)

	for &e in g.entities {
		if e.kind == .nil {
			continue
		}

		e.update(&e)
		e.draw(&e, g.camera)
	}

	sg.end_pass()

	update_key_states(&g.input)
}

event :: proc "c" (event: ^sapp.Event) {
	context = our_context

	update_input_maps(event, &g.input)
	update_mouse_delta(event, &g.input)
	toggle_mouse_lock(&g.input)
}
