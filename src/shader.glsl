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

layout (binding=0) uniform sampler2D wallTexture;

void main () {
	// fragColor = vec4(0.5, 0.0, 0.0, 1.0);
	// fragColor = vec4(ourColor, 1.0);
	fragColor = texture(wallTexture, textCoord);
}

@end

@program main vs fs
