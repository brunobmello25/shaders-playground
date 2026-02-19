package main

Globals :: struct {
	// timing
	dt:        f32,
	last_time: u64,

	//camera
	camera:    Camera,

	// input
	input:     Input,
}

g: Globals

init_globals :: proc() {
	g.camera = make_camera()

	setup_world_lights()
}
