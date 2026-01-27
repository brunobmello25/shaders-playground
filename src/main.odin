package main

import "base:runtime"
import "core:c"
import "core:log"
import stbi "vendor:stb/image"

import sapp "../sokol/app"
import sg "../sokol/gfx"
import sglue "../sokol/glue"
import shelpers "../sokol/helpers"
import stime "../sokol/time"

our_context: runtime.Context
pipeline: sg.Pipeline
// odinfmt: disable
triangle_vertices: []f32 = {
	 // positions          colors              texture
	 0.5,  0.5, 0.0,       1.0, 0.0, 0.0,      1.0, 1.0,
	 0.5, -0.5, 0.0,       0.0, 1.0, 0.0,      1.0, 0.0,
	-0.5, -0.5, 0.0,       0.0, 0.0, 1.0,      0.0, 0.0,
	-0.5,  0.5, 0.0,       1.0, 1.0, 0.0,      0.0, 1.0,
}
triangle_buffer: sg.Buffer
triangle_indices: []u32 = {
	0, 1, 2,
	0, 2, 3,
}
// odinfmt: enable
triangle_index_buffer: sg.Buffer
wall_texture: Texture

Texture :: struct {
	image:   sg.Image,
	sampler: sg.Sampler,
	view:    sg.View,
}

main :: proc() {
	context.logger = log.create_console_logger()
	our_context = context

	sapp.run(
		{
			width = 1920 / 2,
			height = 1080 / 2,
			window_title = "Game - Shaders Playground",
			init_cb = init,
			frame_cb = frame,
			event_cb = event,
			cleanup_cb = cleanup,
			logger = sapp.Logger(shelpers.logger(&our_context)),
		},
	)
}

init :: proc "c" () {
	context = our_context

	stime.setup()

	sg.setup(
		{environment = sglue.environment(), logger = sg.Logger(shelpers.logger(&our_context))},
	)

	shader := sg.make_shader(main_shader_desc(sg.query_backend()))
	pipeline = sg.make_pipeline(
		{
			shader = shader,
			layout = {
				attrs = {
					ATTR_main_aPos = {format = .FLOAT3},
					ATTR_main_aColor = {format = .FLOAT3},
					ATTR_main_aTextCoord = {format = .FLOAT2},
				},
			},
			index_type = .UINT32,
			// depth = {compare = .LESS_EQUAL, write_enabled = true},
		},
	)

	triangle_buffer = sg.make_buffer(
		{
			data = sg.Range {
				ptr = raw_data(triangle_vertices[:]),
				size = len(triangle_vertices) * size_of(f32),
			},
		},
	)
	triangle_index_buffer = sg.make_buffer(
		{
			data = sg.Range {
				ptr = raw_data(triangle_indices[:]),
				size = len(triangle_indices) * size_of(u32),
			},
			usage = {index_buffer = true},
		},
	)


	wall_texture = load_texture("res/wall.jpg")
}

load_texture :: proc(path: string) -> Texture {
	width, height, channels: c.int

	img_bytes := stbi.load("res/wall.jpg", &width, &height, &channels, 4)
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

cleanup :: proc "c" () {}

frame :: proc "c" () {
	sg.begin_pass(
		{
			swapchain = sglue.swapchain(),
			action    = {
				// colors = {0 = {load_action = .CLEAR, clear_value = {1, 0, 1, 1}}},
				// TODO: what is this?
				// depth = {load_action = .CLEAR, clear_value = 1.0},
			},
		},
	)
	sg.apply_pipeline(pipeline)

	sg.apply_bindings(
		{vertex_buffers = {0 = triangle_buffer}, index_buffer = triangle_index_buffer},
	)
	sg.draw(0, len(triangle_indices), 1)

	sg.end_pass()
}

event :: proc "c" (event: ^sapp.Event) {}
