package main

import "core:math/linalg"

Camera :: struct {
	pos:    Vec3,
	target: Vec3,
}

camera_to_view :: proc(camera: Camera, world_up: Vec3) -> Mat4 {
	dir := linalg.normalize0(camera.pos - camera.target)
	right := linalg.normalize0(linalg.cross(world_up, dir))
	up := linalg.cross(dir, right)
	
	// odinfmt: disable
	look_at := Mat4{
		right.x,    right.y,    right.z,    camera.pos.x,
		up.x,       up.y,       up.z,       camera.pos.y,
		dir.x,      dir.y,      dir.z,      camera.pos.z,
		0,          0,          0,          1,
	}
	// odinfmt: enable

	return look_at
}

make_camera :: proc() -> Camera {
	return Camera{pos = {0, 0, 10}, target = {0, 0, 0}}
}

