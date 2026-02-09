package main

import "core:math"

import "core:math/linalg"

import sapp "vendor/sokol/sokol/app"

Camera :: struct {
	pos:              Vec3,
	front:            Vec3,
	up:               Vec3,
	yaw:              f32,
	pitch:            f32,
	spotlight_handle: LightHandle,
}

make_camera :: proc() -> Camera {
	pos := Vec3{0, 0, 3}
	// pos := Vec3{1.0, 3.0, -15.0}

	front := Vec3{0, 0, -1}

	spotlight := light_create()

	setup_spotlight(
		spotlight,
		position = pos,
		direction = front,
		cutoff = math.to_radians(f32(12.5)),
		outer_cutoff = math.to_radians(f32(17.5)),
		ambient = Vec3{0.2, 0.2, 0.2},
		diffuse = Vec3{0.5, 0.5, 0.5},
		specular = Vec3{1.0, 1.0, 1.0},
		constant_attenuation = 1.0,
		linear_attenuation = 0.09,
		quadratic_attenuation = 0.032,
	)

	return Camera {
		pos = pos,
		front = front,
		up = {0, 1, 0},
		yaw = -90,
		pitch = 0,
		spotlight_handle = light_to_handle(spotlight),
	}
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

	lantern := handle_to_light(camera.spotlight_handle)
	if lantern.kind != .nil {
		lantern.position = camera.pos
		lantern.direction = camera.front
	}
}
