@header package main;
@header import sg "../sokol/gfx";

@vs vs

in vec3 aPos;
in vec3 aColor;

out vec3 ourColor;

void main () {
	gl_Position = vec4(aPos, 1.0);
	ourColor = aColor;
}

@end

@fs fs

in vec3 ourColor;

out vec4 fragColor;

void main () {
	// fragColor = vec4(0.5, 0.0, 0.0, 1.0);
	fragColor = vec4(ourColor, 1.0);
}

@end

@program main vs fs
