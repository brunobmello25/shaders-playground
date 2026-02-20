package main

import "core:fmt"
import "core:log"
import mu "vendor:microui"

import "./ui"

@(private = "file")
debug_menu_open: bool = true

@(private = "file")
MenuOption :: enum {
	GameInfo,
}

@(private = "file")
draw_info_menu :: proc() {
	mu_ctx := ui.ctx_ptr()

	mu.layout_row(mu_ctx, {-1}, 0)

	buf: [128]byte

	// FPS
	mu.label(mu_ctx, fmt.bprintf(buf[:], "FPS: %f", 1.0 / dt))

	// Camera Pos and target
	{
		pos := camera.pos
		mu.label(
			mu_ctx,
			fmt.bprintf(buf[:], "camera pos: (%.1f, %.1f, %.1f)", pos.x, pos.y, pos.z),
		)
		target := camera.front
		mu.label(
			mu_ctx,
			fmt.bprintf(buf[:], "camera front: (%.2f, %.2f, %.2f)", target.x, target.y, target.z),
		)
	}
}

render_debug_ui :: proc() {
	if !debug_menu_open {
		return
	}

	mu_ctx := ui.ctx_ptr()

	if mu.begin_window(mu_ctx, "Debug Menu", {10, 10, 300, 400}, {.NO_CLOSE, .NO_RESIZE}) {
		draw_info_menu()

		mu.end_window(mu_ctx)
	}
}

toggle_debug_menu :: proc(input: Input) {
	if was_action_just_pressed(input, .GRAVE_ACCENT) {
		log.debug("Toggling debug menu")
		debug_menu_open = !debug_menu_open
	}
}
