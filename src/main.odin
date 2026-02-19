
package main

import "base:runtime"
import "core:log"

import "./gs"
import "./shaders"
import "./ui"

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

	stime.setup()

	sg.setup(
		{
			environment      = sglue.environment(),
			logger           = sg.Logger(shelpers.logger(&our_context)),
			buffer_pool_size = 512, // Increased from default 128 to handle large models
			image_pool_size  = 512, // Also increase image pool for textures
		},
	)

	set_mouse_lock(false)

	shaders.init()
	ui.init()

	init_globals()

	init_game_state()

	ch := entity_create()
	setup_character(ch)
}

cleanup :: proc "c" () {
	context = our_context
	ui.shutdown()
}

frame :: proc "c" () {
	context = our_context

	// ==================== UPDATE ====================
	g.dt = f32(stime.sec(stime.laptime(&g.last_time)))

	toggle_debug_menu(g.input)
	toggle_mouse_lock(&g.input)

	update_camera(&g.camera, &g.input)
	// ===================== DRAW =====================

	sg.begin_pass(
		{
			swapchain = sglue.swapchain(),
			action = {
				// 497c80
				colors = {
					0 = {
						load_action = .CLEAR,
						clear_value = {224.0 / 255.0, 238.0 / 255.0, 222.0 / 255.0, 1},
					},
				},
				depth = {load_action = .CLEAR, clear_value = 1.0},
			},
		},
	)

	ui.begin_frame()

	render_debug_ui()

	draw_floor()

	for &e in entities {
		if e.kind == .nil {
			continue
		}

		e.update(&e) // TODO: should update entities above together with the other updates
		e.draw(&e, g.camera)
	}

	// Render UI on top of 3D (inside the same pass)
	ui.render()

	sg.end_pass()
	sg.commit()

	update_key_states(&g.input)
}

event :: proc "c" (event: ^sapp.Event) {
	context = our_context

	ui.handle_event(event)

	update_input_maps(event, &g.input)
	update_mouse_delta(event, &g.input)
}

init_game_state :: proc() {
	gs.init()
	gs.get().floor = init_floor()
}
