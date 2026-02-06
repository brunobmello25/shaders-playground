package main

MAX_LIGHTS :: 8

LightKind :: enum {
	nil,
	Directional,
	Point,
	Spot,
}

Light :: struct {
	kind:      LightKind,
	direction: Vec3,
	ambient:   Vec3,
	diffuse:   Vec3,
	specular:  Vec3,
}

LightGlobals :: struct {
	lights:               [MAX_LIGHTS]Light,
	light_count:          int,
	next_available_index: int,
}

setup_world_lights :: proc() {

	dir_light := light_create()
	setup_directional_light(
		dir_light,
		direction = Vec3{-0.2, -1.0, -0.3},
		ambient = Vec3{0.2, 0.2, 0.2},
		diffuse = Vec3{0.5, 0.5, 0.5},
		specular = Vec3{1.0, 1.0, 1.0},
	)
}

// TODO: add proper asserts here
light_create :: proc() -> ^Light {
	// TODO: also should create a free list
	if g.light_globals.next_available_index >= MAX_LIGHTS {
		panic("Max lights reached")
	}

	index := g.light_globals.next_available_index
	g.light_globals.next_available_index += 1
	g.light_globals.light_count += 1

	return &g.light_globals.lights[index]
}

setup_directional_light :: proc(
	l: ^Light,
	direction: Vec3,
	ambient: Vec3,
	diffuse: Vec3,
	specular: Vec3,
) {
	l.kind = .Directional
	l.direction = direction
	l.ambient = ambient
	l.diffuse = diffuse
	l.specular = specular
}
