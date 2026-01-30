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
		right.x, right.y, right.z, 0,
		   up.x,    up.y,    up.z, 0,
		  dir.x,   dir.y,   dir.z, 0,
		   0,       0,       0,    0,
	} * Mat4{
		1, 0, 0, -camera.pos.x,
		0, 1, 0, -camera.pos.y,
		0, 0, 1, -camera.pos.z,
		0, 0, 0,        1     ,
	}
	// odinfmt: enable
	return look_at
}

make_camera :: proc() -> Camera {
	return Camera{pos = {10, 10, 10}, target = {0, 0, 0}}
}
