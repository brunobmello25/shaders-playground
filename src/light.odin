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
	cutoff:                f32,
	outer_cutoff:          f32,
}

lights:                     [MAX_LIGHTS]Light
light_count:                int
next_available_light_index: int

light_to_handle :: proc(l: ^Light) -> LightHandle {
	return l.handle
}

handle_to_light :: proc(lh: LightHandle) -> ^Light {
	assert(lh.index >= 0 && lh.index < MAX_LIGHTS, "Invalid light handle index")

	l := &lights[lh.index]


	if l.handle.id != lh.id {
		return &zero_light
	}

	return l
}

// TODO: add proper asserts here
light_create :: proc() -> ^Light {
	// TODO: also should create a free list
	if next_available_light_index >= MAX_LIGHTS {
		panic("Max lights reached")
	}

	index := next_available_light_index
	next_available_light_index += 1
	light_count += 1

	return &lights[index]
}

lights_to_shader_uniform :: proc() -> shaders.Fs_Lights {
	kinds := [MAX_LIGHTS][4]i32{}
	directions := [MAX_LIGHTS][4]f32{}
	positions := [MAX_LIGHTS][4]f32{}
	ambients := [MAX_LIGHTS][4]f32{}
	diffuses := [MAX_LIGHTS][4]f32{}
	speculars := [MAX_LIGHTS][4]f32{}
	attenuations := [MAX_LIGHTS][4]f32{}
	cutoffs := [MAX_LIGHTS][4]f32{}


	for i in 0 ..< light_count {
		light := lights[i]
		if light.kind == .nil {
			continue
		}

		directions[i] = {light.direction.x, light.direction.y, light.direction.z, 0.0}
		positions[i] = {light.position.x, light.position.y, light.position.z, 1.0} // TODO: could probably join directions and positions into a single array and distinguish with the w component
		ambients[i] = {light.ambient.x, light.ambient.y, light.ambient.z, 1.0}
		diffuses[i] = {light.diffuse.x, light.diffuse.y, light.diffuse.z, 1.0}
		speculars[i] = {light.specular.x, light.specular.y, light.specular.z, 1.0}
		cutoffs[i] = {light.cutoff, light.outer_cutoff, 0.0, 0.0}
		kinds[i] = [4]i32{i32(light.kind), 0, 0, 0}
		attenuations[i] = {
			light.constant_attenuation,
			light.linear_attenuation,
			light.quadratic_attenuation,
			1.0,
		}
	}

	return shaders.Fs_Lights {
		light_count = i32(light_count),
		kinds = kinds,
		directions = directions,
		positions = positions,
		ambients = ambients,
		diffuses = diffuses,
		speculars = speculars,
		attenuations = attenuations,
		cutoffs = cutoffs,
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
}

setup_spotlight :: proc(
	l: ^Light,
	position: Vec3,
	direction: Vec3,
	cutoff: f32,
	outer_cutoff: f32,
	ambient: Vec3,
	diffuse: Vec3,
	specular: Vec3,
	constant_attenuation: f32,
	linear_attenuation: f32,
	quadratic_attenuation: f32,
) {
	l.kind = .Spot
	l.position = position
	l.direction = direction
	l.cutoff = cutoff
	l.outer_cutoff = outer_cutoff
	l.ambient = ambient
	l.diffuse = diffuse
	l.specular = specular
	l.constant_attenuation = constant_attenuation
	l.linear_attenuation = linear_attenuation
	l.quadratic_attenuation = quadratic_attenuation
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
