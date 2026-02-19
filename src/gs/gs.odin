package gs

import "../model/"

GameState :: struct {
	floor: ^model.Model,
}

_state: ^GameState

init :: proc() {
	_state = new(GameState)
}

get :: proc() -> ^GameState {
	return _state
}
