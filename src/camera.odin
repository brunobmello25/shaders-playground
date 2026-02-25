package main

import "core:math"
import "core:math/linalg"

import sapp "vendor/sokol/sokol/app"

import "config"

camera: Camera

Camera :: struct {
	pos:              Vec3,
	up:               Vec3,
	yaw:              f32,
	pitch:            f32,
	spotlight_handle: LightHandle,
}

camera_front :: proc(cam: Camera) -> Vec3 {
	dir: Vec3
	dir.x = math.cos(math.to_radians(cam.yaw)) * math.cos(math.to_radians(cam.pitch))
	dir.y = math.sin(math.to_radians(cam.pitch))
	dir.z = math.sin(math.to_radians(cam.yaw)) * math.cos(math.to_radians(cam.pitch))
	return linalg.normalize0(dir)
}

init_camera :: proc() {
	camera = make_camera()
}

make_camera :: proc() -> Camera {
	cam := Camera {
		pos = {10, 10, 11},
		up = {0, 1, 0},
		yaw = -135,
		pitch = -30,
	}

	spotlight := light_create()

	setup_spotlight(
		spotlight,
		position = cam.pos,
		direction = camera_front(cam),
		cutoff = math.to_radians(f32(12.5)),
		outer_cutoff = math.to_radians(f32(17.5)),
		ambient = Vec3{0.2, 0.2, 0.2},
		diffuse = Vec3{0.5, 0.5, 0.5},
		specular = Vec3{1.0, 1.0, 1.0},
		constant_attenuation = 1.0,
		linear_attenuation = 0.09,
		quadratic_attenuation = 0.032,
	)

	cam.spotlight_handle = light_to_handle(spotlight)
	return cam
}

view_and_projection :: proc(camera: Camera) -> (Mat4, Mat4) {
	view := linalg.matrix4_look_at_f32(camera.pos, camera.pos + camera_front(camera), camera.up, true)
	fov := f32(45.0)

	viewWidth := sapp.width()
	viewHeight := sapp.height()
	far_plane := config.get().world_size * 2.0
	proj := linalg.matrix4_perspective_f32(fov, f32(viewWidth) / f32(viewHeight), 0.1, far_plane, true)

	return view, proj
}

update_camera :: proc(camera: ^Camera, input: ^Input) {
	camera_speed := f32(20 * sapp.frame_duration())
	mouse_sensitivity := f32(0.1)

	front := camera_front(camera^)

	if is_action_down(input^, .W) {
		camera.pos += camera_speed * front
	}
	if is_action_down(input^, .S) {
		camera.pos -= camera_speed * front
	}
	if is_action_down(input^, .A) {
		camera.pos -= camera_speed * linalg.normalize0(linalg.cross(front, camera.up))
	}
	if is_action_down(input^, .D) {
		camera.pos += camera_speed * linalg.normalize0(linalg.cross(front, camera.up))
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
	}

	camera.pitch = clamp(camera.pitch, -89, 89)

	input.mouse_delta = {0, 0}

	lantern := handle_to_light(camera.spotlight_handle)
	if lantern.kind != .nil {
		lantern.position = camera.pos
		lantern.direction = camera_front(camera^)
	}
}
