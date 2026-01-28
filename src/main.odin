#+feature dynamic-literals

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

Quad :: struct {
	vertices:      sg.Buffer,
	indices:       sg.Buffer,
	indices_count: int,
}

Texture :: struct {
	image:   sg.Image,
	sampler: sg.Sampler,
	view:    sg.View,
}

quad: Quad
containerTexture: Texture
faceTexture: Texture

range_from_slice :: proc(slice: []$T) -> sg.Range {
	return sg.Range{ptr = raw_data(slice), size = len(slice) * size_of(slice[0])}
}

range :: proc {
	range_from_slice,
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

main :: proc() {
	context.logger = log.create_console_logger()
	our_context = context

	sapp.run(
		{
			width = 800,
			height = 800,
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

	quad = make_quad()
	containerTexture = load_texture("res/container.jpg")
	faceTexture = load_texture("res/awesomeface.png")
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
		{
			vertex_buffers = {0 = quad.vertices},
			index_buffer = quad.indices,
			views = {
				VIEW_containerTexture = containerTexture.view,
				VIEW_faceTexture = faceTexture.view,
			},
			samplers = {
				SMP_containerTextureSampler = containerTexture.sampler,
				SMP_faceTextureSampler = faceTexture.sampler,
			},
		},
	)
	sg.draw(0, quad.indices_count, 1)

	sg.end_pass()
}

event :: proc "c" (event: ^sapp.Event) {}
