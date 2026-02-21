package primitives

import "core:math"
import "core:math/linalg"

import sg "../vendor/sokol/sokol/gfx"

import helpers "../helpers"
import shaders "../shaders"

MAX_PRIM_VERTICES :: 65536

Vec3 :: [3]f32
Vec4 :: [4]f32
Mat4 :: matrix[4, 4]f32

prim_vertices: [MAX_PRIM_VERTICES]Vec3
prim_vertex_count: int
prim_buffer: sg.Buffer

init :: proc() {
	prim_buffer = sg.make_buffer(
		{usage = {stream_update = true}, size = MAX_PRIM_VERTICES * size_of(Vec3)},
	)
}

push_vertex :: proc(pos: Vec3) {
	if prim_vertex_count >= MAX_PRIM_VERTICES {
		return
	}
	prim_vertices[prim_vertex_count] = pos
	prim_vertex_count += 1
}

draw_line :: proc(from, to: Vec3) {
	push_vertex(from)
	push_vertex(to)
}

draw_sphere :: proc(center: Vec3, radius: f32, segments: int = 16) {
	for i in 0 ..< segments {
		a0 := f32(i) / f32(segments) * 2.0 * math.PI
		a1 := f32(i + 1) / f32(segments) * 2.0 * math.PI

		// XY plane
		draw_line(
			center + Vec3{math.cos(a0), math.sin(a0), 0} * radius,
			center + Vec3{math.cos(a1), math.sin(a1), 0} * radius,
		)
		// XZ plane
		draw_line(
			center + Vec3{math.cos(a0), 0, math.sin(a0)} * radius,
			center + Vec3{math.cos(a1), 0, math.sin(a1)} * radius,
		)
		// YZ plane
		draw_line(
			center + Vec3{0, math.cos(a0), math.sin(a0)} * radius,
			center + Vec3{0, math.cos(a1), math.sin(a1)} * radius,
		)
	}
}

draw_capsule :: proc(from, to: Vec3, radius: f32, segments: int = 16) {
	axis := to - from
	length := linalg.length(axis)
	if length < 0.0001 {
		draw_sphere(from, radius, segments)
		return
	}

	dir := axis / length
	// Build orthonormal basis
	up := Vec3{0, 1, 0}
	if math.abs(linalg.dot(dir, up)) > 0.99 {
		up = Vec3{1, 0, 0}
	}
	right := linalg.normalize(linalg.cross(dir, up))
	forward := linalg.cross(right, dir)

	// Hemispheres
	for i in 0 ..< segments {
		a0 := f32(i) / f32(segments) * math.PI
		a1 := f32(i + 1) / f32(segments) * math.PI

		// Top hemisphere (around 'to')
		for j in 0 ..< segments {
			b0 := f32(j) / f32(segments) * 2.0 * math.PI
			b1 := f32(j + 1) / f32(segments) * 2.0 * math.PI

			if i < segments / 2 {
				p0 :=
					to +
					(right * math.cos(b0) + forward * math.sin(b0)) * math.sin(a0) * radius +
					dir * math.cos(a0) * radius
				p1 :=
					to +
					(right * math.cos(b1) + forward * math.sin(b1)) * math.sin(a0) * radius +
					dir * math.cos(a0) * radius
				draw_line(p0, p1)
			}
		}

		// Bottom hemisphere (around 'from')
		for j in 0 ..< segments {
			b0 := f32(j) / f32(segments) * 2.0 * math.PI
			b1 := f32(j + 1) / f32(segments) * 2.0 * math.PI

			if i >= segments / 2 {
				p0 :=
					from +
					(right * math.cos(b0) + forward * math.sin(b0)) * math.sin(a0) * radius -
					dir * math.cos(a0) * radius
				p1 :=
					from +
					(right * math.cos(b1) + forward * math.sin(b1)) * math.sin(a0) * radius -
					dir * math.cos(a0) * radius
				draw_line(p0, p1)
			}
		}
	}

	// 4 connecting lines
	draw_line(to + right * radius, from + right * radius)
	draw_line(to - right * radius, from - right * radius)
	draw_line(to + forward * radius, from + forward * radius)
	draw_line(to - forward * radius, from - forward * radius)
}

draw_plane :: proc(origin: Vec3, normal: Vec3, size: f32) {
	n := linalg.normalize(normal)
	up := Vec3{0, 1, 0}
	if math.abs(linalg.dot(n, up)) > 0.99 {
		up = Vec3{1, 0, 0}
	}
	right := linalg.normalize(linalg.cross(n, up)) * size * 0.5
	forward := linalg.normalize(linalg.cross(right, n)) * size * 0.5

	c0 := origin - right - forward
	c1 := origin + right - forward
	c2 := origin + right + forward
	c3 := origin - right + forward

	draw_line(c0, c1)
	draw_line(c1, c2)
	draw_line(c2, c3)
	draw_line(c3, c0)
}

draw_box :: proc(min, max: Vec3) {
	// Bottom face
	draw_line({min.x, min.y, min.z}, {max.x, min.y, min.z})
	draw_line({max.x, min.y, min.z}, {max.x, min.y, max.z})
	draw_line({max.x, min.y, max.z}, {min.x, min.y, max.z})
	draw_line({min.x, min.y, max.z}, {min.x, min.y, min.z})

	// Top face
	draw_line({min.x, max.y, min.z}, {max.x, max.y, min.z})
	draw_line({max.x, max.y, min.z}, {max.x, max.y, max.z})
	draw_line({max.x, max.y, max.z}, {min.x, max.y, max.z})
	draw_line({min.x, max.y, max.z}, {min.x, max.y, min.z})

	// Vertical edges
	draw_line({min.x, min.y, min.z}, {min.x, max.y, min.z})
	draw_line({max.x, min.y, min.z}, {max.x, max.y, min.z})
	draw_line({max.x, min.y, max.z}, {max.x, max.y, max.z})
	draw_line({min.x, min.y, max.z}, {min.x, max.y, max.z})
}

flush :: proc(view, proj: Mat4, color: Vec4 = {1, 1, 1, 1}) {
	if prim_vertex_count == 0 {
		return
	}

	sg.update_buffer(
		prim_buffer,
		{ptr = &prim_vertices, size = uint(prim_vertex_count * size_of(Vec3))},
	)

	sg.apply_pipeline(shaders.get(.Primitives).pipeline)

	vs_params := shaders.Primitives_Vs_Params {
		view       = view,
		projection = proj,
	}
	sg.apply_uniforms(shaders.UB_Primitives_Vs_Params, helpers.range(&vs_params))

	fs_params := shaders.Primitives_Fs_Params {
		color = color,
	}
	sg.apply_uniforms(shaders.UB_Primitives_Fs_Params, helpers.range(&fs_params))

	bindings: sg.Bindings
	bindings.vertex_buffers[0] = prim_buffer
	sg.apply_bindings(bindings)

	sg.draw(0, u32(prim_vertex_count), 1)

	prim_vertex_count = 0
}
