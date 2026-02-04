#+feature dynamic-literals

package main

import "core:c"
import "core:math/linalg"

import stbi "vendor:stb/image"

import sg "../sokol/gfx"

import shaders "shaders"

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

draw_model :: proc(
	model: Model,
	camera: Camera,
	shader: shaders.Shader,
	pos: Vec3 = {0, 0, 0},
	scale: Vec3 = {1, 1, 1},
) {
	model_matrix := linalg.matrix4_translate_f32(pos) * linalg.matrix4_scale_f32(scale)
	normal_matrix := linalg.transpose(linalg.inverse(model_matrix))

	view, proj := view_and_projection(camera)

	sg.apply_pipeline(shader.pipeline)
	sg.apply_bindings({vertex_buffers = {0 = model.vertices}, views = {}, samplers = {}}) // TODO: how to generalize this?
}

// TODO: generalize this into a draw_model function that takes in
// a shader, a position, a model, and whatever else is needed
draw_cube :: proc(camera: Camera) {
	model := linalg.matrix4_translate_f32(g.cube_pos)
	normal_matrix := linalg.transpose(linalg.inverse(model))

	view, proj := view_and_projection(camera)

	sg.apply_pipeline(g.cube_shader.pipeline)
	sg.apply_bindings(
		{
			vertex_buffers = {0 = g.cube_model.vertices},
			views = {shaders.VIEW_cubeDiffuseTexture = g.cube_diffuse_texture.view},
			samplers = {shaders.SMP_cubeDiffuseSampler = g.cube_diffuse_texture.sampler},
			// index_buffer = quad.indices,
		},
	)
	vs_params := shaders.Cubevsparams {
		model        = model,
		view         = view,
		projection   = proj,
		normalMatrix = normal_matrix,
	}
	sg.apply_uniforms(shaders.UB_CubeVSParams, range(&vs_params))

	fs_params := shaders.Cubefsparams {
		viewPos = camera.pos,
	}
	sg.apply_uniforms(shaders.UB_CubeFSParams, range(&fs_params))
	cube_fs_material := shaders.Cubefsmaterial {
		specular  = {0.5, 0.5, 0.5},
		shininess = 32.0,
	}
	sg.apply_uniforms(shaders.UB_CubeFSMaterial, range(&cube_fs_material))
	cube_fs_light := shaders.Cubefslight {
		position = g.light.position,
		ambient  = g.light.ambient,
		diffuse  = g.light.diffuse,
		specular = g.light.specular,
	}
	sg.apply_uniforms(shaders.UB_CubeFSLight, range(&cube_fs_light))

	sg.draw(0, g.cube_model.vertex_count, 1)
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

		-0.5,  0.5,  0.5, -1.0,  0.0,  0.0,  1.0,  0.0,
		-0.5,  0.5, -0.5, -1.0,  0.0,  0.0,  1.0,  1.0,
		-0.5, -0.5, -0.5, -1.0,  0.0,  0.0,  0.0,  1.0,
		-0.5, -0.5, -0.5, -1.0,  0.0,  0.0,  0.0,  1.0,
		-0.5, -0.5,  0.5, -1.0,  0.0,  0.0,  0.0,  0.0,
		-0.5,  0.5,  0.5, -1.0,  0.0,  0.0,  1.0,  0.0,

		 0.5,  0.5,  0.5,  1.0,  0.0,  0.0,  1.0,  0.0,
		 0.5,  0.5, -0.5,  1.0,  0.0,  0.0,  1.0,  1.0,
		 0.5, -0.5, -0.5,  1.0,  0.0,  0.0,  0.0,  1.0,
		 0.5, -0.5, -0.5,  1.0,  0.0,  0.0,  0.0,  1.0,
		 0.5, -0.5,  0.5,  1.0,  0.0,  0.0,  0.0,  0.0,
		 0.5,  0.5,  0.5,  1.0,  0.0,  0.0,  1.0,  0.0,

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
