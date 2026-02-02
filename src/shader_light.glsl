@header package main;
@header import sg "../sokol/gfx";

@ctype mat4 Mat4

@vs vs

in vec3 aPos;

layout (binding=0) uniform LightVSParams {
	mat4 model;
	mat4 view;
	mat4 projection;
};

void main () {
	gl_Position = projection * view * model * vec4(aPos, 1.0);
}

@end

@fs fs

layout (binding=1) uniform LightFSParams {
	vec3 lightColor;
};

out vec4 fragColor;

void main () {
	fragColor = vec4(lightColor, 1.0);
}

@end

@program light vs fs
