package main

import sapp "../sokol/app"
import "core:math/linalg"

Camera :: struct {
	pos:   Vec3,
	front: Vec3,
	up:    Vec3,
}

camera_to_view :: proc(camera: Camera) -> Mat4 {
	return linalg.matrix4_look_at_f32(camera.pos, camera.pos + camera.front, camera.up, false)
}

make_camera :: proc() -> Camera {
	return Camera{pos = {0, 0, 3}, front = {0, 0, -1}, up = {0, 1, 0}}
}

update_camera :: proc(camera: ^Camera) {
	camera_speed := f32(5 * sapp.frame_duration())

	if is_action_down(.W) {
		camera.pos += camera_speed * camera.front
	}
	if is_action_down(.S) {
		camera.pos -= camera_speed * camera.front
	}
	if is_action_down(.A) {
		camera.pos -= camera_speed * linalg.normalize0(linalg.cross(camera.front, camera.up))
	}
	if is_action_down(.D) {
		camera.pos += camera_speed * linalg.normalize0(linalg.cross(camera.front, camera.up))
	}
}
