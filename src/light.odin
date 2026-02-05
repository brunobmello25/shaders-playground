package main

Light :: struct {
	position: Vec3,
	ambient:  Vec3,
	diffuse:  Vec3,
	specular: Vec3,
	model:    Model,
}

make_global_light :: proc() -> Light {
	return Light {
		position = {1.2, 1.0, 2.0},
		ambient = {0.2, 0.2, 0.2},
		diffuse = {0.5, 0.5, 0.5},
		specular = {1.0, 1.0, 1.0},
		model = make_cube(),
	}
}
