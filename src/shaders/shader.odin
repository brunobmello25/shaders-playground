package shaders

import "core:fmt"

import sg "../vendor/sokol/sokol/gfx"


Shader :: struct {
	kind:     ShaderKind,
	pipeline: sg.Pipeline,
}

ShaderKind :: enum {
	Entity,
}

loaded_shaders: map[ShaderKind]Shader = {}

init :: proc() {
	for kind in ShaderKind {
		load(kind)
	}
}

load :: proc(kind: ShaderKind) -> Shader {
	cached, ok := loaded_shaders[kind]
	if ok {
		return cached
	}

	desc: sg.Shader_Desc
	layout: sg.Vertex_Layout_State

	switch kind {
	case .Entity:
		desc = entity_shader_desc(sg.query_backend())
		layout = {
			attrs = {
				ATTR_entity_a_pos = {format = .FLOAT3},
				ATTR_entity_a_normal = {format = .FLOAT3},
				ATTR_entity_a_uv = {format = .FLOAT2},
				ATTR_entity_bone_ids = {format = .FLOAT4},
				ATTR_entity_bone_weights = {format = .FLOAT4},
			},
		}
	}


	shader := sg.make_shader(desc)
	pipeline := sg.make_pipeline(
		{
			shader = shader,
			layout = layout,
			index_type = .UINT32,
			depth = {compare = .LESS_EQUAL, write_enabled = true},
		},
	)

	s := Shader {
		kind     = kind,
		pipeline = pipeline,
	}

	loaded_shaders[kind] = s

	return s
}

get :: proc(kind: ShaderKind) -> Shader {
	s, ok := loaded_shaders[kind]

	fmt.assertf(ok, "Shader of kind %v not loaded", kind)

	return s
}
