package main

import "core:math"

cos :: math.cos
sin :: math.sin

make_scale_matrix :: proc(x, y, z: f32) -> Mat4 {
	// odinfmt: disable
	return Mat4{
		  x,  0.0,  0.0, 0.0,
		0.0,    y,  0.0, 0.0,
		0.0,  0.0,  z,   0.0,
		0.0,  0.0,  0.0, 1.0,
	}
	// odinfmt: enable
}

make_translation_matrix :: proc(x, y, z: f32) -> Mat4 {
	// odinfmt: disable
	return Mat4{
		1.0, 0.0, 0.0,   x,
		0.0, 1.0, 0.0,   y,
		0.0, 0.0, 1.0,   z,
		0.0, 0.0, 0.0, 1.0,
	}
	// odinfmt: enable
}

make_rotation_matrix :: proc(w, x, y, z: f32) -> Mat4 {
	// odinfmt: disable
	return Mat4{
		cos(w) + x * x * (1 - cos(w)),     x * y * (1 - cos(w)) - z * sin(w),   x * z * (1 - cos(w)) + y * sin(w),  0.0,
		y * x * (1 - cos(w)) + z * sin(w), cos(w) + y * y * (1 - cos(w)),       y * z * (1 - cos(w)) - x * sin(w),  0.0,
		z * x * (1 - cos(w)) - y * sin(w), z * y * (1 - cos(w)) + x * sin(w),   cos(w) + z * z * (1 - cos(w)),      0.0,
		0.0,                               0.0,                                 0.0,                                1.0,
	}
	// odinfmt: enable
}

make_identity_matrix :: proc() -> Mat4 {
	return make_scale_matrix(1.0, 1.0, 1.0)
}
