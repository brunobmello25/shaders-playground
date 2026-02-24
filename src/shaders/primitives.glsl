@header package shaders
@header import sg "../vendor/sokol/sokol/gfx";

@ctype mat4 Mat4
@ctype vec4 Vec4

@vs vs_primitives

in vec3 a_pos;

layout(binding=0) uniform Primitives_Vs_Params {
	mat4 model;
	mat4 view;
	mat4 projection;
};

void main() {
	gl_Position = projection * view * model * vec4(a_pos, 1.0);
}

@end

@fs fs_primitives

layout(binding=1) uniform Primitives_Fs_Params {
	vec4 color;
};

out vec4 frag_color;

void main() {
	frag_color = color;
}

@end

@program primitives vs_primitives fs_primitives
