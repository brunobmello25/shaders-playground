#+feature dynamic-literals

package main

import "base:runtime"
import "core:c"
import "core:log"
import "core:math"
import "core:math/linalg"

import sapp "../sokol/app"
import sg "../sokol/gfx"
import sglue "../sokol/glue"
import shelpers "../sokol/helpers"
import stime "../sokol/time"
import stbi "vendor:stb/image"

import shaders "shaders"

// :types

Mat4 :: matrix[4, 4]f32
Vec4 :: [4]f32
Vec3 :: [3]f32
Vec2 :: [2]f32

Light :: struct {
	position: Vec3,
	ambient:  Vec3,
	diffuse:  Vec3,
	specular: Vec3,
	model:    Model,
}

Model :: struct {
	vertices:      sg.Buffer,
	indices:       sg.Buffer,
	indices_count: int,
	vertex_count:  int,
}

Texture :: struct {
	image:   sg.Image,
	sampler: sg.Sampler,
	view:    sg.View,
}

// :globals

our_context: runtime.Context

containerTexture: Texture
faceTexture: Texture

// :main

main :: proc() {
	context.logger = log.create_console_logger()
	our_context = context

	sapp.run(
		{
			width = 800,
			height = 800,
			window_title = "Game - Shaders Playground",
			init_cb = init,
			frame_cb = frame,
			event_cb = event,
			cleanup_cb = cleanup,
			logger = sapp.Logger(shelpers.logger(&our_context)),
		},
	)
}

init :: proc "c" () {
	context = our_context

	sapp.lock_mouse(true)
	sapp.show_mouse(false)
	is_mouse_locked = true

	stime.setup()

	sg.setup(
		{environment = sglue.environment(), logger = sg.Logger(shelpers.logger(&our_context))},
	)

	init_globals()

	containerTexture = load_texture("res/container.jpg")
	faceTexture = load_texture("res/awesomeface.png")
}

cleanup :: proc "c" () {
	context = our_context
}

frame :: proc "c" () {
	context = our_context

	sg.begin_pass(
		{
			swapchain = sglue.swapchain(),
			action    = {
				// colors = {0 = {load_action = .CLEAR, clear_value = {1, 0, 1, 1}}},
				// TODO: what is this?
				// depth = {load_action = .CLEAR, clear_value = 1.0},
			},
		},
	)

	update_camera(&g.camera)
	update_light_color_over_time(&g.light)
	draw_cube(g.camera)
	draw_light(g.camera)

	sg.end_pass()

	if was_action_just_pressed(.SPACE) {
		log.debug("Space key was just pressed")
	} else if was_action_just_released(.SPACE) {
		log.debug("Space key was just released")
	}

	update_key_states()
}

event :: proc "c" (event: ^sapp.Event) {
	context = our_context

	update_input_maps(event)
	update_mouse_delta(event)
	toggle_mouse_lock()
}

// :helpers

range :: proc {
	range_from_slice,
	range_from_struct,
}

range_from_struct :: proc(data: ^$T) -> sg.Range {
	return sg.Range{ptr = data, size = size_of(T)}
}

range_from_slice :: proc(vertices: []$T) -> sg.Range {
	return sg.Range{ptr = raw_data(vertices), size = len(vertices) * size_of(T)}
}

load_texture :: proc(path: cstring) -> Texture {
	width, height, channels: c.int

	stbi.set_flip_vertically_on_load(1)
	img_bytes := stbi.load(path, &width, &height, &channels, 4)
	defer stbi.image_free(img_bytes)

	image := sg.make_image(
		{
			width = width,
			height = height,
			pixel_format = .RGBA8,
			data = {mip_levels = {0 = sg.Range{ptr = img_bytes, size = uint(width * height * 4)}}},
		},
	)
	sampler := sg.make_sampler(
		{
			mag_filter = .LINEAR,
			min_filter = .NEAREST,
			wrap_v = .CLAMP_TO_EDGE,
			wrap_u = .CLAMP_TO_EDGE,
		},
	)
	view := sg.make_view(
		{
			texture = {
				image = image,
				slices = {base = 0, count = 1},
				mip_levels = {base = 0, count = 1},
			},
		},
	)

	return Texture{image = image, sampler = sampler, view = view}
}

// :input

is_mouse_locked: bool

input_map: map[sapp.Keycode]struct {
	is_down:  bool,
	was_down: bool,
}

mouse_input_map: map[sapp.Mousebutton]struct {
	is_down:  bool,
	was_down: bool,
}

was_action_just_pressed :: proc(action: sapp.Keycode) -> bool {
	return input_map[action].is_down && !input_map[action].was_down
}

was_action_just_released :: proc(action: sapp.Keycode) -> bool {
	return !input_map[action].is_down && input_map[action].was_down
}

was_mouse_button_just_pressed :: proc(button: sapp.Mousebutton) -> bool {
	return mouse_input_map[button].is_down && !mouse_input_map[button].was_down
}

was_mouse_button_just_released :: proc(button: sapp.Mousebutton) -> bool {
	return !mouse_input_map[button].is_down && mouse_input_map[button].was_down
}

is_action_down :: proc(action: sapp.Keycode) -> bool {
	return input_map[action].is_down
}

update_key_states :: proc() {
	for _, &state in input_map {
		state.was_down = state.is_down
	}

	for _, &state in mouse_input_map {
		state.was_down = state.is_down
	}
}

update_input_maps :: proc(event: ^sapp.Event) {
	if event.type == .KEY_DOWN || event.type == .KEY_UP {
		keycode := event.key_code

		input_map[keycode] = {
			is_down  = event.type == .KEY_DOWN,
			was_down = input_map[keycode].is_down,
		}
	}

	if event.type == .MOUSE_DOWN || event.type == .MOUSE_UP {
		button := event.mouse_button

		mouse_input_map[button] = {
			is_down  = event.type == .MOUSE_DOWN,
			was_down = mouse_input_map[button].is_down,
		}
	}
}

toggle_mouse_lock :: proc() {
	if was_mouse_button_just_pressed(.RIGHT) {
		is_mouse_locked = !is_mouse_locked
		sapp.lock_mouse(is_mouse_locked)
		sapp.show_mouse(!is_mouse_locked)
	}
}

// :shader

// :camera

mouse_delta: Vec2

Camera :: struct {
	pos:   Vec3,
	front: Vec3,
	up:    Vec3,
	yaw:   f32,
	pitch: f32,
}

make_camera :: proc() -> Camera {
	return Camera{pos = {0, 0, 3}, front = {0, 0, -1}, up = {0, 1, 0}, yaw = -90, pitch = 0}
}

view_and_projection :: proc(camera: Camera) -> (Mat4, Mat4) {
	view := linalg.matrix4_look_at_f32(camera.pos, camera.pos + camera.front, camera.up, true)
	fov := f32(45.0)

	viewWidth := sapp.width()
	viewHeight := sapp.height()
	proj := linalg.matrix4_perspective_f32(fov, f32(viewWidth) / f32(viewHeight), 0.1, 100.0, true)

	return view, proj
}

update_camera :: proc(camera: ^Camera) {
	camera_speed := f32(5 * sapp.frame_duration())
	mouse_sensitivity := f32(0.1)

	if is_action_down(.W) {
		camera.pos += camera_speed * camera.front
	}
	if is_action_down(.S) {
		camera.pos -= camera_speed * camera.front
	}
	if is_action_down(.A) {
		camera.pos -= camera_speed * linalg.normalize0(linalg.cross(camera.front, camera.up))
	}
	if is_action_down(.D) {
		camera.pos += camera_speed * linalg.normalize0(linalg.cross(camera.front, camera.up))
	}

	if is_mouse_locked {
		x_offset := mouse_delta.x * mouse_sensitivity
		y_offset := mouse_delta.y * mouse_sensitivity

		camera.yaw += x_offset
		camera.pitch -= y_offset

		if camera.pitch > 89 {
			camera.pitch = 89
		}
		if camera.pitch < -89 {
			camera.pitch = -89
		}

		new_direction: Vec3
		new_direction.x =
			math.cos(math.to_radians(camera.yaw)) * math.cos(math.to_radians(camera.pitch))
		new_direction.y = math.sin(math.to_radians(camera.pitch))
		new_direction.z =
			math.sin(math.to_radians(camera.yaw)) * math.cos(math.to_radians(camera.pitch))
		camera.front = linalg.normalize0(new_direction)
	}

	mouse_delta = {0, 0}
}

update_mouse_delta :: proc(event: ^sapp.Event) {
	if event.type == .MOUSE_MOVE {
		mouse_delta.x = f32(event.mouse_dx)
		mouse_delta.y = f32(event.mouse_dy)
	}
}

// :cube

draw_cube :: proc(camera: Camera) {
	model := linalg.matrix4_translate_f32(g.cube_pos)
	normal_matrix := linalg.transpose(linalg.inverse(model))

	view, proj := view_and_projection(camera)

	sg.apply_pipeline(g.cube_shader.pipeline)
	sg.apply_bindings(
		{
			vertex_buffers = {0 = g.cube_model.vertices},
			// index_buffer = quad.indices,
		},
	)
	vs_params := shaders.Cubevsparams {
		model        = model,
		view         = view,
		projection   = proj,
		normalMatrix = normal_matrix,
	}
	sg.apply_uniforms(shaders.UB_CubeVSParams, range(&vs_params))
	fs_params := shaders.Cubefsparams {
		viewPos = camera.pos,
	}
	sg.apply_uniforms(shaders.UB_CubeFSParams, range(&fs_params))
	cube_fs_material := shaders.Cubefsmaterial {
		ambient   = {1.0, 0.5, 0.31},
		diffuse   = {1.0, 0.5, 0.31},
		specular  = {0.5, 0.5, 0.5},
		shininess = 32.0,
	}
	sg.apply_uniforms(shaders.UB_CubeFSMaterial, range(&cube_fs_material))
	cube_fs_light := shaders.Cubefslight {
		position = g.light.position,
		ambient  = g.light.ambient,
		diffuse  = g.light.diffuse,
		specular = g.light.specular,
	}
	sg.apply_uniforms(shaders.UB_CubeFSLight, range(&cube_fs_light))

	sg.draw(0, g.cube_model.vertex_count, 1)
}

make_cube :: proc() -> Model {
	// odinfmt: disable
	vertices_data := [dynamic]f32{
		-0.5, -0.5, -0.5,  0.0, 0.0, -1.0,
		 0.5, -0.5, -0.5,  0.0, 0.0, -1.0,
		 0.5,  0.5, -0.5,  0.0, 0.0, -1.0,
		 0.5,  0.5, -0.5,  0.0, 0.0, -1.0,
		-0.5,  0.5, -0.5,  0.0, 0.0, -1.0,
		-0.5, -0.5, -0.5,  0.0, 0.0, -1.0,

		-0.5, -0.5,  0.5,  0.0, 0.0, 1.0,
		 0.5, -0.5,  0.5,  0.0, 0.0, 1.0,
		 0.5,  0.5,  0.5,  0.0, 0.0, 1.0,
		 0.5,  0.5,  0.5,  0.0, 0.0, 1.0,
		-0.5,  0.5,  0.5,  0.0, 0.0, 1.0,
		-0.5, -0.5,  0.5,  0.0, 0.0, 1.0,

		-0.5,  0.5,  0.5, -1.0, 0.0, 0.0,
		-0.5,  0.5, -0.5, -1.0, 0.0, 0.0,
		-0.5, -0.5, -0.5, -1.0, 0.0, 0.0,
		-0.5, -0.5, -0.5, -1.0, 0.0, 0.0,
		-0.5, -0.5,  0.5, -1.0, 0.0, 0.0,
		-0.5,  0.5,  0.5, -1.0, 0.0, 0.0,

		 0.5,  0.5,  0.5,  1.0, 0.0, 0.0,
		 0.5,  0.5, -0.5,  1.0, 0.0, 0.0,
		 0.5, -0.5, -0.5,  1.0, 0.0, 0.0,
		 0.5, -0.5, -0.5,  1.0, 0.0, 0.0,
		 0.5, -0.5,  0.5,  1.0, 0.0, 0.0,
		 0.5,  0.5,  0.5,  1.0, 0.0, 0.0,

		-0.5, -0.5, -0.5,  0.0, -1.0, 0.0,
		 0.5, -0.5, -0.5,  0.0, -1.0, 0.0,
		 0.5, -0.5,  0.5,  0.0, -1.0, 0.0,
		 0.5, -0.5,  0.5,  0.0, -1.0, 0.0,
		-0.5, -0.5,  0.5,  0.0, -1.0, 0.0,
		-0.5, -0.5, -0.5,  0.0, -1.0, 0.0,

		-0.5,  0.5, -0.5,  0.0, 1.0, 0.0,
		 0.5,  0.5, -0.5,  0.0, 1.0, 0.0,
		 0.5,  0.5,  0.5,  0.0, 1.0, 0.0,
		 0.5,  0.5,  0.5,  0.0, 1.0, 0.0,
		-0.5,  0.5,  0.5,  0.0, 1.0, 0.0,
		-0.5,  0.5, -0.5,  0.0, 1.0, 0.0,
	}
	// indices_data: [dynamic]u32 = {
	// }
	// odinfmt: enable

	vertices_buffer := sg.make_buffer(
		{data = range(vertices_data[:]), size = len(vertices_data) * size_of(vertices_data[0])},
	)
	// indices_buffer := sg.make_buffer(
	// 	{
	// 		data = range(indices_data[:]),
	// 		size = len(indices_data) * size_of(indices_data[0]),
	// 		usage = {index_buffer = true},
	// 	},
	// )

	return Model{vertices = vertices_buffer, indices = {}, vertex_count = 36, indices_count = 0}
}

// :light

update_light_color_over_time :: proc(light: ^Light) {
	time := stime.sec(stime.now())
	light_color: Vec3

	light_color.x = f32(math.sin(time * 2))
	light_color.y = f32(math.sin(time * 0.7))
	light_color.z = f32(math.sin(time * 1.3))

	light.diffuse = light_color * Vec3{0.5, 0.5, 0.5}
	light.ambient = light.diffuse * Vec3{0.2, 0.2, 0.2}
}

draw_light :: proc(camera: Camera) {
	model :=
		linalg.matrix4_translate_f32(g.light.position) *
		linalg.matrix4_scale_f32(Vec3{0.2, 0.2, 0.2}) // TODO: pq caraios ta estranho quando bota esse scale aqui?

	view, proj := view_and_projection(camera)

	sg.apply_pipeline(g.light_shader.pipeline)
	sg.apply_bindings({vertex_buffers = {0 = g.light.model.vertices}})

	vs_params := shaders.Lightvsparams {
		model      = model,
		view       = view,
		projection = proj,
	}
	sg.apply_uniforms(shaders.UB_LightVSParams, range(&vs_params))
	fs_params := shaders.Lightfsparams {
		lightColor = g.light.diffuse,
	}
	sg.apply_uniforms(shaders.UB_LightFSParams, range(&fs_params))

	sg.draw(0, g.light.model.vertex_count, 1)
}
