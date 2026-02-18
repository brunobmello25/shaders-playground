package main

import sapp "vendor/sokol/sokol/app"

Input :: struct {
	mouse_delta:     Vec2,
	is_mouse_locked: bool,
	input_map:       map[sapp.Keycode]struct {
		is_down:  bool,
		was_down: bool,
	},
	mouse_input_map: map[sapp.Mousebutton]struct {
		is_down:  bool,
		was_down: bool,
	},
}

set_mouse_lock :: proc(lock: bool) {
	sapp.lock_mouse(lock)
	sapp.show_mouse(!lock)
	g.input.is_mouse_locked = lock
}

toggle_mouse_lock :: proc(input: ^Input) {
	if was_mouse_button_just_pressed(input^, .RIGHT) {
		set_mouse_lock(!input.is_mouse_locked)
	}
}

was_mouse_button_just_pressed :: proc(input: Input, button: sapp.Mousebutton) -> bool {
	return input.mouse_input_map[button].is_down && !input.mouse_input_map[button].was_down
}

is_action_down :: proc(input: Input, action: sapp.Keycode) -> bool {
	return input.input_map[action].is_down
}

was_action_just_pressed :: proc(input: Input, action: sapp.Keycode) -> bool {
	return input.input_map[action].is_down && !input.input_map[action].was_down
}

update_mouse_delta :: proc(event: ^sapp.Event, input: ^Input) {
	if event.type == .MOUSE_MOVE {
		input.mouse_delta.x += f32(event.mouse_dx)
		input.mouse_delta.y += f32(event.mouse_dy)
	}
}

update_input_maps :: proc(event: ^sapp.Event, input: ^Input) {
	if event.type == .KEY_DOWN || event.type == .KEY_UP {
		keycode := event.key_code

		input.input_map[keycode] = {
			is_down  = event.type == .KEY_DOWN,
			was_down = input.input_map[keycode].is_down,
		}
	}

	if event.type == .MOUSE_DOWN || event.type == .MOUSE_UP {
		button := event.mouse_button

		input.mouse_input_map[button] = {
			is_down  = event.type == .MOUSE_DOWN,
			was_down = input.mouse_input_map[button].is_down,
		}
	}
}

update_key_states :: proc(input: ^Input) {
	for _, &state in input.input_map {
		state.was_down = state.is_down
	}

	for _, &state in input.mouse_input_map {
		state.was_down = state.is_down
	}
}
