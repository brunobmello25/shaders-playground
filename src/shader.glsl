@header package main;
@header import sg "../sokol/gfx";

@vs vs

in vec3 aPos;

void main () {
	gl_Position= vec4(aPos.x, aPos.y, aPos.z, 1.0);
}

@end

@fs fs

out vec4 frag_color;

void main () {
	frag_color = vec4(1.0, 0.5, 0.2, 1.0);
}

@end

@program main vs fs
