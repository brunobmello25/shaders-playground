package shaders

import sg "../../sokol/gfx"


Shader :: struct {
	kind:     ShaderKind,
	pipeline: sg.Pipeline,
}

ShaderKind :: enum {
	Cube,
	Light,
}

load :: proc(kind: ShaderKind) -> Shader {
	desc: sg.Shader_Desc
	layout: sg.Vertex_Layout_State

	switch kind {
	case .Cube:
		desc = cube_shader_desc(sg.query_backend())
		layout = {
			attrs = {
				ATTR_cube_aPos = {format = .FLOAT3},
				ATTR_cube_aNormal = {format = .FLOAT3},
				ATTR_cube_aUv = {format = .FLOAT2},
			},
		}
	case .Light:
		desc = light_shader_desc(sg.query_backend())
		layout = {
			buffers = {0 = {stride = size_of(f32) * (3 + 3 + 2)}},
			attrs = {ATTR_light_aPos = {format = .FLOAT3}},
		}
	}


	shader := sg.make_shader(desc)
	pipeline := sg.make_pipeline(
		{shader = shader, layout = layout, depth = {compare = .LESS_EQUAL, write_enabled = true}},
	)

	return Shader{kind = kind, pipeline = pipeline}
}
