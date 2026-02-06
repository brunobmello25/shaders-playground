package main

import "./shaders"

MAX_LIGHTS :: 8

LightKind :: enum {
	nil,
	Directional,
	Point,
	Spot,
}

// TODO: make this unmutable somehow?
zero_light: Light = {}

LightHandle :: struct {
	id:    int,
	index: int,
}

Light :: struct {
	handle:                LightHandle,
	kind:                  LightKind,
	direction:             Vec3,
	position:              Vec3,
	ambient:               Vec3,
	diffuse:               Vec3,
	specular:              Vec3,
	constant_attenuation:  f32,
	linear_attenuation:    f32,
	quadratic_attenuation: f32,
}

LightGlobals :: struct {
	lights:               [MAX_LIGHTS]Light,
	light_count:          int,
	next_available_index: int,
}

light_to_handle :: proc(l: ^Light) -> LightHandle {
	return l.handle
}

handle_to_light :: proc(lh: LightHandle) -> ^Light {
	assert(lh.index >= 0 && lh.index < MAX_LIGHTS, "Invalid light handle index")

	l := &g.light_globals.lights[lh.index]


	if l.handle.id != lh.id {
		return &zero_light
	}

	return l
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

light_destroy :: proc(l: ^Light) {
	l.kind = .nil
}

lights_to_shader_uniform :: proc() -> shaders.Fs_Lights {
	kinds := [MAX_LIGHTS][4]i32{}
	directions := [MAX_LIGHTS][4]f32{}
	positions := [MAX_LIGHTS][4]f32{}
	ambients := [MAX_LIGHTS][4]f32{}
	diffuses := [MAX_LIGHTS][4]f32{}
	speculars := [MAX_LIGHTS][4]f32{}
	attenuations := [MAX_LIGHTS][4]f32{}

	for i in 0 ..< g.light_globals.light_count {
		light := g.light_globals.lights[i]
		if light.kind == .nil {
			continue
		}

		directions[i] = {light.direction.x, light.direction.y, light.direction.z, 0.0}
		positions[i] = {light.position.x, light.position.y, light.position.z, 1.0} // TODO: could probably join directions and positions into a single array and distinguish with the w component
		ambients[i] = {light.ambient.x, light.ambient.y, light.ambient.z, 1.0}
		diffuses[i] = {light.diffuse.x, light.diffuse.y, light.diffuse.z, 1.0}
		speculars[i] = {light.specular.x, light.specular.y, light.specular.z, 1.0}
		kinds[i] = [4]i32{i32(light.kind), 0, 0, 0}
		attenuations[i] = {
			light.constant_attenuation,
			light.linear_attenuation,
			light.quadratic_attenuation,
			1.0,
		}
	}

	return shaders.Fs_Lights {
		light_count = i32(g.light_globals.light_count),
		kinds = kinds,
		directions = directions,
		positions = positions,
		ambients = ambients,
		diffuses = diffuses,
		speculars = speculars,
		attenuations = attenuations,
	}
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

	point_light := light_create()
	setup_point_light(
		point_light,
		position = Vec3{1.0, 6.0, -15.0},
		ambient = Vec3{0.2, 0.2, 0.2},
		diffuse = Vec3{0.5, 0.5, 0.5},
		specular = Vec3{1.0, 1.0, 1.0}, // TODO: check if this light is right. i can't see the specular reflections
		constant_attenuation = 1.0,
		linear_attenuation = 0.09,
		quadratic_attenuation = 0.032,
	)

	light_source := entity_create()
	setup_light_source(light_source, point_light.position, light_to_handle(point_light))
}

setup_point_light :: proc(
	l: ^Light,
	position: Vec3,
	ambient: Vec3,
	diffuse: Vec3,
	specular: Vec3,
	constant_attenuation: f32,
	linear_attenuation: f32,
	quadratic_attenuation: f32,
) {
	l.kind = .Point
	l.position = position
	l.ambient = ambient
	l.diffuse = diffuse
	l.specular = specular
	l.constant_attenuation = constant_attenuation
	l.linear_attenuation = linear_attenuation
	l.quadratic_attenuation = quadratic_attenuation
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
