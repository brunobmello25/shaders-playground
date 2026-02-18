package main

import "core:math/linalg"
import sg "vendor/sokol/sokol/gfx"

import shaders "shaders"

FLOOR_Y :: f32(0.0)
FLOOR_SIZE :: f32(100.0)

FloorGlobals :: struct {
	vertex_buffer:    sg.Buffer,
	index_buffer:     sg.Buffer,
	diffuse_view:     sg.View,
	diffuse_sampler:  sg.Sampler,
	specular_view:    sg.View,
	specular_sampler: sg.Sampler,
}

make_floor_texture :: proc(r, g_val, b: u8) -> (sg.View, sg.Sampler) {
	pixel := [4]u8{r, g_val, b, 255}
	image := sg.make_image(
		{
			width = 1,
			height = 1,
			pixel_format = .RGBA8,
			data = {mip_levels = {0 = sg.Range{ptr = &pixel, size = size_of(pixel)}}},
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
	sampler := sg.make_sampler(
		{
			mag_filter = .LINEAR,
			min_filter = .NEAREST,
			wrap_u = .CLAMP_TO_EDGE,
			wrap_v = .CLAMP_TO_EDGE,
		},
	)
	return view, sampler
}

init_floor :: proc() {
	half := FLOOR_SIZE / 2.0

	// Vertex layout: pos(3) + normal(3) + uv(2) + bone_ids(4) + bone_weights(4) = 16 floats per vertex
	// Bone setup: bone_ids all 0, bone_weights (1,0,0,0) → each vertex fully driven by bone slot 0,
	// which we send as an identity matrix → no skinning deformation.
	// odinfmt: disable
	vertices := [64]f32{
		-half, FLOOR_Y, -half,  0, 1, 0,  0, 0,  0, 0, 0, 0,  1, 0, 0, 0,
		 half, FLOOR_Y, -half,  0, 1, 0,  1, 0,  0, 0, 0, 0,  1, 0, 0, 0,
		 half, FLOOR_Y,  half,  0, 1, 0,  1, 1,  0, 0, 0, 0,  1, 0, 0, 0,
		-half, FLOOR_Y,  half,  0, 1, 0,  0, 1,  0, 0, 0, 0,  1, 0, 0, 0,
	}
	indices := [6]u32{0, 1, 2, 0, 2, 3}
	// odinfmt: enable

	g.floor.vertex_buffer = sg.make_buffer({data = range(vertices[:]), size = size_of(vertices)})
	g.floor.index_buffer = sg.make_buffer(
		{data = range(indices[:]), size = size_of(indices), usage = {index_buffer = true}},
	)

	g.floor.diffuse_view, g.floor.diffuse_sampler = make_floor_texture(144, 238, 144) // #90EE90 light green
	g.floor.specular_view, g.floor.specular_sampler = make_floor_texture(30, 30, 30)
}

draw_floor :: proc() {
	view, proj := view_and_projection(g.camera)

	sg.apply_pipeline(g.entity_shader.pipeline)

	vs_params := shaders.Entity_Vs_Params {
		model         = linalg.identity(Mat4),
		view          = view,
		projection    = proj,
		normal_matrix = linalg.identity(Mat4),
	}
	sg.apply_uniforms(shaders.UB_Entity_VS_Params, range(&vs_params))

	fs_params := shaders.Entity_Fs_Params {
		view_pos  = g.camera.pos,
		shininess = 32.0,
	}
	sg.apply_uniforms(shaders.UB_Entity_FS_Params, range(&fs_params))

	fs_lights := lights_to_shader_uniform()
	sg.apply_uniforms(shaders.UB_FS_Lights, range(&fs_lights))

	// No skinning: bone slot 0 = identity, all vertices weighted 100% to slot 0
	bone_uniforms := shaders.Entity_Vs_Bone_Transforms{}
	bone_uniforms.bone_transforms[0] = linalg.identity(Mat4)
	sg.apply_uniforms(shaders.UB_Entity_VS_Bone_Transforms, range(&bone_uniforms))

	bindings := sg.Bindings {
		vertex_buffers = {0 = g.floor.vertex_buffer},
		index_buffer = g.floor.index_buffer,
		views = {
			shaders.VIEW_entity_diffuse_texture = g.floor.diffuse_view,
			shaders.VIEW_entity_specular_texture = g.floor.specular_view,
		},
		samplers = {
			shaders.SMP_entity_diffuse_sampler = g.floor.diffuse_sampler,
			shaders.SMP_entity_specular_sampler = g.floor.specular_sampler,
		},
	}
	sg.apply_bindings(bindings)

	sg.draw(0, 6, 1)
}
