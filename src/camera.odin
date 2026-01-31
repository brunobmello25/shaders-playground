package main

import stime "../sokol/time"
import "core:math"
import "core:math/linalg"

Camera :: struct {
	pos:    Vec3,
	target: Vec3,
}

camera_to_view :: proc(camera: Camera, world_up: Vec3) -> Mat4 {
	return linalg.matrix4_look_at_f32(camera.pos, camera.target, world_up, false)
}

make_camera :: proc() -> Camera {
	return Camera{pos = {0, 0, 3}, target = {0, 0, 0}}
}

update_camera :: proc(camera: ^Camera) {
	radius :: 30.0

	x := f32(radius * math.cos(stime.sec(stime.now())))
	z := f32(radius * math.sin(stime.sec(stime.now())))

	camera.pos = Vec3{x, camera.pos.y, z}
}
