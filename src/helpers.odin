#+feature dynamic-literals

package main

import sg "../sokol/gfx"

import "core:c"
import stbi "vendor:stb/image"

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

make_quad :: proc() -> Quad {
	// odinfmt: disable
	vertices_data := [dynamic]f32{
	 0.5,  0.5, 0.0,    1.0, 0.0, 0.0,   1.0, 1.0,
	 0.5, -0.5, 0.0,    0.0, 1.0, 0.0,   1.0, 0.0,
	-0.5, -0.5, 0.0,    0.0, 0.0, 1.0,   0.0, 0.0,
	-0.5,  0.5, 0.0,    1.0, 1.0, 0.0,   0.0, 1.0,
	}
	indices_data: [dynamic]u32 = {
		0, 1, 2,
		0, 2, 3,
	}
	// odinfmt: enable

	vertices_buffer := sg.make_buffer(
		{data = range(vertices_data[:]), size = len(vertices_data) * size_of(vertices_data[0])},
	)
	indices_buffer := sg.make_buffer(
		{
			data = range(indices_data[:]),
			size = len(indices_data) * size_of(indices_data[0]),
			usage = {index_buffer = true},
		},
	)

	return Quad {
		vertices = vertices_buffer,
		indices = indices_buffer,
		indices_count = len(indices_data),
	}
}

load_texture :: proc(path: cstring) -> Texture {
	width, height, channels: c.int

	stbi.set_flip_vertically_on_load(1)
	img_bytes := stbi.load(path, &width, &height, &channels, 4)
	defer stbi.image_free(img_bytes)

	image := sg.make_image(
		{
			width = width,
			height = height,
			pixel_format = .RGBA8,
			data = {mip_levels = {0 = sg.Range{ptr = img_bytes, size = uint(width * height * 4)}}},
		},
	)
	sampler := sg.make_sampler(
		{
			mag_filter = .LINEAR,
			min_filter = .NEAREST,
			wrap_v = .CLAMP_TO_EDGE,
			wrap_u = .CLAMP_TO_EDGE,
		},
	)
	view := sg.make_view(
		{
			texture = {
				image = image,
				slices = {base = 0, count = 1},
				mip_levels = {base = 0, count = 1},
			},
		},
	)

	return Texture{image = image, sampler = sampler, view = view}
}
