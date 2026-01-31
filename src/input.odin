package main

import sapp "../sokol/app"

input_map: map[sapp.Keycode]struct {
	is_down:  bool,
	was_down: bool,
}

was_action_just_pressed :: proc(action: sapp.Keycode) -> bool {
	return input_map[action].is_down && !input_map[action].was_down
}

was_action_just_released :: proc(action: sapp.Keycode) -> bool {
	return !input_map[action].is_down && input_map[action].was_down
}

is_action_down :: proc(action: sapp.Keycode) -> bool {
	return input_map[action].is_down
}

update_key_states :: proc() {
	for _, &state in input_map {
		state.was_down = state.is_down
	}
}

event_input :: proc(event: ^sapp.Event) {
	if event.type == .KEY_DOWN || event.type == .KEY_UP {
		keycode := event.key_code

		input_map[keycode] = {
			is_down  = event.type == .KEY_DOWN,
			was_down = input_map[keycode].is_down,
		}
	}
}
