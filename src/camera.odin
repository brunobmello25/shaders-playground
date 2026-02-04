package main

import "core:math"

import "core:math/linalg"

import sapp "../sokol/app"

Camera :: struct {
	pos:   Vec3,
	front: Vec3,
	up:    Vec3,
	yaw:   f32,
	pitch: f32,
}

make_camera :: proc() -> Camera {
	return Camera{pos = {0, 0, 3}, front = {0, 0, -1}, up = {0, 1, 0}, yaw = -90, pitch = 0}
}

view_and_projection :: proc(camera: Camera) -> (Mat4, Mat4) {
	view := linalg.matrix4_look_at_f32(camera.pos, camera.pos + camera.front, camera.up, true)
	fov := f32(45.0)

	viewWidth := sapp.width()
	viewHeight := sapp.height()
	proj := linalg.matrix4_perspective_f32(fov, f32(viewWidth) / f32(viewHeight), 0.1, 100.0, true)

	return view, proj
}

update_camera :: proc(camera: ^Camera, input: ^Input) {
	camera_speed := f32(5 * sapp.frame_duration())
	mouse_sensitivity := f32(0.1)

	if is_action_down(input^, .W) {
		camera.pos += camera_speed * camera.front
	}
	if is_action_down(input^, .S) {
		camera.pos -= camera_speed * camera.front
	}
	if is_action_down(input^, .A) {
		camera.pos -= camera_speed * linalg.normalize0(linalg.cross(camera.front, camera.up))
	}
	if is_action_down(input^, .D) {
		camera.pos += camera_speed * linalg.normalize0(linalg.cross(camera.front, camera.up))
	}

	if is_action_down(input^, .SPACE) {
		camera.pos += camera_speed * camera.up
	}

	if is_action_down(input^, .LEFT_SHIFT) {
		camera.pos -= camera_speed * camera.up
	}

	if input.is_mouse_locked {
		x_offset := input.mouse_delta.x * mouse_sensitivity
		y_offset := input.mouse_delta.y * mouse_sensitivity

		camera.yaw += x_offset
		camera.pitch -= y_offset

		if camera.pitch > 89 {
			camera.pitch = 89
		}
		if camera.pitch < -89 {
			camera.pitch = -89
		}

		new_direction: Vec3
		new_direction.x =
			math.cos(math.to_radians(camera.yaw)) * math.cos(math.to_radians(camera.pitch))
		new_direction.y = math.sin(math.to_radians(camera.pitch))
		new_direction.z =
			math.sin(math.to_radians(camera.yaw)) * math.cos(math.to_radians(camera.pitch))
		camera.front = linalg.normalize0(new_direction)
	}

	input.mouse_delta = {0, 0}
}
