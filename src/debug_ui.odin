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

	// Camera
	if .ACTIVE in mu.header(mu_ctx, "Camera") {
		labeled_number :: proc(ctx: ^mu.Context, label: string, val: ^mu.Real, step: mu.Real) {
			mu.layout_row(ctx, {60, -1}, 0)
			mu.label(ctx, label)
			mu.number(ctx, val, step)
		}

		labeled_number(mu_ctx, "Pos X", &camera.pos.x, 0.1)
		labeled_number(mu_ctx, "Pos Y", &camera.pos.y, 0.1)
		labeled_number(mu_ctx, "Pos Z", &camera.pos.z, 0.1)
		labeled_number(mu_ctx, "Yaw", &camera.yaw, 1.0)
		labeled_number(mu_ctx, "Pitch", &camera.pitch, 1.0)

		mu.layout_row(mu_ctx, {-1}, 0)
		front := camera.front
		mu.label(
			mu_ctx,
			fmt.bprintf(buf[:], "Front: (%.2f, %.2f, %.2f)", front.x, front.y, front.z),
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
