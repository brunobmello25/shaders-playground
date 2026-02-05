#+feature dynamic-literals

package main

import "core:c"

import stbi "vendor:stb/image"

import sg "../sokol/gfx"

Model :: struct {
	vertices:      sg.Buffer,
	indices:       sg.Buffer,
	indices_count: int,
	vertex_count:  int,
}

Texture :: struct {
	image:   sg.Image,
	sampler: sg.Sampler,
	view:    sg.View,
}

// TODO: make this reuse textures if the same path was already loaded
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

make_cube :: proc() -> Model {
	// odinfmt: disable
	vertices_data := [dynamic]f32{
		// positions       // normals        // texture coords
		-0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  0.0,  0.0,
		 0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  1.0,  0.0,
		 0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  1.0,  1.0,
		 0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  1.0,  1.0,
		-0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  0.0,  1.0,
		-0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  0.0,  0.0,

		-0.5, -0.5,  0.5,  0.0,  0.0,  1.0,  0.0,  0.0,
		 0.5, -0.5,  0.5,  0.0,  0.0,  1.0,  1.0,  0.0,
		 0.5,  0.5,  0.5,  0.0,  0.0,  1.0,  1.0,  1.0,
		 0.5,  0.5,  0.5,  0.0,  0.0,  1.0,  1.0,  1.0,
		-0.5,  0.5,  0.5,  0.0,  0.0,  1.0,  0.0,  1.0,
		-0.5, -0.5,  0.5,  0.0,  0.0,  1.0,  0.0,  0.0,

		-0.5,  0.5,  0.5, -1.0,  0.0,  0.0,  1.0,  1.0,
		-0.5,  0.5, -0.5, -1.0,  0.0,  0.0,  0.0,  1.0,
		-0.5, -0.5, -0.5, -1.0,  0.0,  0.0,  0.0,  0.0,
		-0.5, -0.5, -0.5, -1.0,  0.0,  0.0,  0.0,  0.0,
		-0.5, -0.5,  0.5, -1.0,  0.0,  0.0,  1.0,  0.0,
		-0.5,  0.5,  0.5, -1.0,  0.0,  0.0,  1.0,  1.0,

		 0.5,  0.5,  0.5,  1.0,  0.0,  0.0,  0.0,  1.0,
		 0.5,  0.5, -0.5,  1.0,  0.0,  0.0,  1.0,  1.0,
		 0.5, -0.5, -0.5,  1.0,  0.0,  0.0,  1.0,  0.0,
		 0.5, -0.5, -0.5,  1.0,  0.0,  0.0,  1.0,  0.0,
		 0.5, -0.5,  0.5,  1.0,  0.0,  0.0,  0.0,  0.0,
		 0.5,  0.5,  0.5,  1.0,  0.0,  0.0,  0.0,  1.0,

		-0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  0.0,  1.0,
		 0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  1.0,  1.0,
		 0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  1.0,  0.0,
		 0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  1.0,  0.0,
		-0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  0.0,  0.0,
		-0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  0.0,  1.0,

		-0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  0.0,  1.0,
		 0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  1.0,  1.0,
		 0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  1.0,  0.0,
		 0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  1.0,  0.0,
		-0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  0.0,  0.0,
		-0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  0.0,  1.0
	}
	// odinfmt: enable

	vertices_buffer := sg.make_buffer(
		{data = range(vertices_data[:]), size = len(vertices_data) * size_of(vertices_data[0])},
	)
	// indices_buffer := sg.make_buffer(
	// 	{
	// 		data = range(indices_data[:]),
	// 		size = len(indices_data) * size_of(indices_data[0]),
	// 		usage = {index_buffer = true},
	// 	},
	// )

	return Model{vertices = vertices_buffer, indices = {}, vertex_count = 36, indices_count = 0}
}
