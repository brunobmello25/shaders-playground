package shaders

import sg "../vendor/sokol/sokol/gfx"


Shader :: struct {
	kind:     ShaderKind,
	pipeline: sg.Pipeline,
}

ShaderKind :: enum {
	Entity,
}

load :: proc(kind: ShaderKind) -> Shader {
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

	return Shader{kind = kind, pipeline = pipeline}
}
