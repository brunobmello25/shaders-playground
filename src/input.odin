package main

import sapp "../sokol/app"

is_mouse_locked: bool

input_map: map[sapp.Keycode]struct {
	is_down:  bool,
	was_down: bool,
}

mouse_input_map: map[sapp.Mousebutton]struct {
	is_down:  bool,
	was_down: bool,
}

was_action_just_pressed :: proc(action: sapp.Keycode) -> bool {
	return input_map[action].is_down && !input_map[action].was_down
}

was_action_just_released :: proc(action: sapp.Keycode) -> bool {
	return !input_map[action].is_down && input_map[action].was_down
}

was_mouse_button_just_pressed :: proc(button: sapp.Mousebutton) -> bool {
	return mouse_input_map[button].is_down && !mouse_input_map[button].was_down
}

was_mouse_button_just_released :: proc(button: sapp.Mousebutton) -> bool {
	return !mouse_input_map[button].is_down && mouse_input_map[button].was_down
}

is_action_down :: proc(action: sapp.Keycode) -> bool {
	return input_map[action].is_down
}

update_key_states :: proc() {
	for _, &state in input_map {
		state.was_down = state.is_down
	}

	for _, &state in mouse_input_map {
		state.was_down = state.is_down
	}
}

update_input_maps :: proc(event: ^sapp.Event) {
	if event.type == .KEY_DOWN || event.type == .KEY_UP {
		keycode := event.key_code

		input_map[keycode] = {
			is_down  = event.type == .KEY_DOWN,
			was_down = input_map[keycode].is_down,
		}
	}

	if event.type == .MOUSE_DOWN || event.type == .MOUSE_UP {
		button := event.mouse_button

		mouse_input_map[button] = {
			is_down  = event.type == .MOUSE_DOWN,
			was_down = mouse_input_map[button].is_down,
		}
	}
}

toggle_mouse_lock :: proc() {
	if was_mouse_button_just_pressed(.RIGHT) {
		is_mouse_locked = !is_mouse_locked
		sapp.lock_mouse(is_mouse_locked)
		sapp.show_mouse(!is_mouse_locked)
	}
}
