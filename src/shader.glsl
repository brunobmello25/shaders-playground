@header package main;
@header import sg "../sokol/gfx";

@vs vs

in vec3 aPos;
in vec3 aColor;
in vec2 aTextCoord;

out vec3 ourColor;
out vec2 textCoord;

void main () {
	gl_Position = vec4(aPos, 1.0);
	ourColor = aColor;
	textCoord = aTextCoord;
}

@end

@fs fs

in vec3 ourColor;
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
		faceColor.a
	);
}

@end

@program main vs fs
