package main

import sg "vendor/sokol/sokol/gfx"

Mat4 :: matrix[4, 4]f32
Vec4 :: [4]f32
Vec3 :: [3]f32
Vec2 :: [2]f32

range :: proc {
	range_from_slice,
	range_from_struct,
}

range_from_struct :: proc(data: ^$T) -> sg.Range {
	return sg.Range{ptr = data, size = size_of(T)}
}

range_from_slice :: proc(vertices: []$T) -> sg.Range {
	return sg.Range{ptr = raw_data(vertices), size = len(vertices) * size_of(T)}
}
