@header package main;
@header import sg "../sokol/gfx";

@vs vs

void main () {}

@end

@fs fs

out vec4 frag_color;

void main () {
	frag_color = vec4(1.0, 0.0, 0.0, 1.0);
}

@end

@program main vs fs
