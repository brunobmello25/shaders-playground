
package main

import "base:runtime"
import "core:log"
import "core:math/linalg"

import sapp "vendor/sokol/sokol/app"
import sg "vendor/sokol/sokol/gfx"
import sglue "vendor/sokol/sokol/glue"
import shelpers "vendor/sokol/sokol/helpers"
import stime "vendor/sokol/sokol/time"

import shaders "shaders"

our_context: runtime.Context

test_backpack_model: Model

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

	sapp.lock_mouse(true)
	sapp.show_mouse(false)
	g.input.is_mouse_locked = true

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
	ok: bool
	test_backpack_model, ok = load_model("res/backpack/backpack.obj")
	if !ok {
		log.panic("Failed to load model")
	}
	log.infof("Model loaded successfully: %d meshes", len(test_backpack_model.meshes))

	cube_positions := []Vec3 {
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
	for position in cube_positions {
		container := entity_create()
		setup_container(container)
		container.position = position
	}
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

	// Draw the backpack model
	{
		model_matrix := linalg.matrix4_translate_f32(Vec3{0, 0, -5})
		normal_matrix := linalg.transpose(linalg.inverse(model_matrix))
		view, proj := view_and_projection(g.camera)

		sg.apply_pipeline(g.entity_shader.pipeline)

		// Apply global uniforms
		vs_params := shaders.Entity_Vs_Params {
			model         = model_matrix,
			view          = view,
			projection    = proj,
			normal_matrix = normal_matrix,
		}
		sg.apply_uniforms(shaders.UB_Entity_VS_Params, range(&vs_params))

		fs_params := shaders.Entity_Fs_Params {
			view_pos  = g.camera.pos,
			shininess = 32.0,
		}
		sg.apply_uniforms(shaders.UB_Entity_FS_Params, range(&fs_params))

		fs_lights := lights_to_shader_uniform()
		sg.apply_uniforms(shaders.UB_FS_Lights, range(&fs_lights))

		// Now draw the model
		draw_model(&test_backpack_model, g.camera)
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
