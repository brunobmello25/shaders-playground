package main

import "base:runtime"
import "core:log"

import sapp "../sokol/app"
import shelpers "../sokol/helpers"

our_context: runtime.Context

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

init :: proc "c" () {}

cleanup :: proc "c" () {}

frame :: proc "c" () {}

event :: proc "c" (event: ^sapp.Event) {}
