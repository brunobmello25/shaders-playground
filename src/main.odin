
package main

import "base:runtime"
import "core:log"
import "core:math/linalg"

import "./primitives"
import "./shaders"
import "./ui"

import sapp "vendor/sokol/sokol/app"
import sg "vendor/sokol/sokol/gfx"
import sglue "vendor/sokol/sokol/glue"
import shelpers "vendor/sokol/sokol/helpers"
import stime "vendor/sokol/sokol/time"

our_context: runtime.Context

dt: f32

Mat4 :: matrix[4, 4]f32
Vec4 :: [4]f32
Vec3 :: [3]f32
Vec2 :: [2]f32

sky_color: Vec4 = {224.0 / 255.0, 238.0 / 255.0, 222.0 / 255.0, 1}

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

	init_camera()
	setup_world_lights()

	primitives.init()
	init_game_state()

	ch := entity_create()
	setup_character(ch)

	pd := entity_create()
	setup_picadrill(pd)
	pd.position = {0, 0, -5}
}

cleanup :: proc "c" () {
	context = our_context
	ui.shutdown()
}

frame :: proc "c" () {
	context = our_context

	// ==================== Startup ====================
	@(static) last_time: u64
	dt = f32(stime.sec(stime.laptime(&last_time)))

	sg.begin_pass(
		{
			swapchain = sglue.swapchain(),
			action = {
				colors = {
					0 = {
						load_action = .CLEAR,
						clear_value = sg.Color{sky_color.r, sky_color.g, sky_color.b, sky_color.a},
					},
				},
				depth = {load_action = .CLEAR, clear_value = 1.0},
			},
		},
	)

	ui.begin_frame()

	// ==================== Input ====================
	toggle_debug_menu(input)
	toggle_mouse_lock(&input)
	update_camera(&camera, &input)

	// ===================== Bunch of stuff...? =====================
	render_debug_ui()
	draw_floor()

	for &e in entities {
		if e.kind == .nil {
			continue
		}

		e.update(&e)
		e.draw(&e, camera)
	}

	// ===================== Wrap up =====================

	// Render UI on top of 3D (inside the same pass)
	ui.render()

	update_key_states(&input)

	sg.end_pass()
	sg.commit()
}

event :: proc "c" (event: ^sapp.Event) {
	context = our_context

	ui.handle_event(event)

	update_input_maps(event, &input)
	update_mouse_delta(event, &input)
}

init_game_state :: proc() {
	init_floor()
}
