@header package main;
@header import sg "../sokol/gfx";

@ctype mat4 Mat4

@vs vs

in vec3 aPos;
in vec2 aTextCoord;

layout (binding=0) uniform VSParams {
	mat4 model;
	mat4 view;
	mat4 projection;
};

out vec2 textCoord;

void main () {
	gl_Position = projection * view * model * vec4(aPos, 1.0);
	textCoord = aTextCoord;
}

@end

@fs fs

in vec2 textCoord;

out vec4 fragColor;

layout (binding=0) uniform texture2D containerTexture;
layout (binding=0) uniform sampler containerTextureSampler;

layout (binding=1) uniform texture2D faceTexture;
layout (binding=1) uniform sampler faceTextureSampler;

void main () {
	vec4 containerColor = texture(sampler2D(containerTexture, containerTextureSampler), textCoord);
	vec4 faceColor = texture(sampler2D(faceTexture, faceTextureSampler), textCoord);
	fragColor = mix(
		containerColor,
		faceColor, 
		0.2
	);
}

@end

@program main vs fs
