package model

import "core:log"
import "core:math/linalg"
import "core:mem"
import "core:strings"

import assimp "../vendor/assimp"
import sg "../vendor/sokol/sokol/gfx"

Model :: struct {
	meshes:         []Mesh,
	directory:      string,
	root_node:      Node,
	global_inverse: Mat4,
	animations:     []Animation,
}

load :: proc(kind: ModelKind) -> (^Model, bool) {
	filepath := kind_to_path(kind)

	if cached, ok := &loaded_models[filepath]; ok {
		return cached, true
	}

	flags :=
		u32(assimp.aiPostProcessSteps.Triangulate) |
		u32(assimp.aiPostProcessSteps.FlipUVs) |
		u32(assimp.aiPostProcessSteps.GenNormals) |
		u32(assimp.aiPostProcessSteps.CalcTangentSpace) |
		u32(assimp.aiPostProcessSteps.LimitBoneWeights)

	filepath_cstr := strings.clone_to_cstring(filepath)
	defer delete(filepath_cstr)

	scene := assimp.import_file(filepath_cstr, flags)
	if scene == nil {
		log.errorf("Failed to load model: %s", filepath)
		return nil, false
	}
	defer assimp.release_import(scene)

	// Extract directory
	last_slash := strings.last_index(filepath, "/") // TODO: should also consider windows here. maybe make kind_to_path return filepath struct and only get os path when needed?
	directory := filepath[:last_slash] if last_slash >= 0 else "."

	// Process meshes
	meshes := make([dynamic]Mesh)

	// Try node hierarchy first
	if scene.mRootNode != nil {
		process_node(scene.mRootNode, scene, &meshes, directory)
	}

	// If no meshes from nodes, process all scene meshes directly
	if len(meshes) == 0 && scene.mNumMeshes > 0 {
		for i in 0 ..< scene.mNumMeshes {
			ai_mesh := mem.ptr_offset(scene.mMeshes, int(i))^
			mesh := process_mesh(ai_mesh, scene, directory)
			append(&meshes, mesh)
		}
	}

	root_node := extract_node(scene.mRootNode)
	global_inverse := linalg.inverse(root_node.transform) // TODO: what is this?

	animations := make([]Animation, scene.mNumAnimations)
	for i in 0 ..< scene.mNumAnimations {
		ai_anim := mem.ptr_offset(scene.mAnimations, int(i))^
		animations[i] = extract_animation(ai_anim)
	}

	log.debugf(
		"Loaded model: %s (%d meshes, %d animations)",
		filepath,
		len(meshes),
		len(animations),
	)
	loaded_models[filepath] = Model {
		meshes         = meshes[:],
		directory      = directory,
		root_node      = root_node,
		global_inverse = global_inverse,
		animations     = animations,
	}
	return &loaded_models[filepath], true
}

make_solid_texture :: proc(color: [4]u8, kind: TextureKind) -> Texture {
	pixel := color
	image := sg.make_image(
		{
			width = 1,
			height = 1,
			pixel_format = .RGBA8,
			data = {mip_levels = {0 = sg.Range{ptr = &pixel, size = size_of(pixel)}}},
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
	sampler := sg.make_sampler(
		{
			mag_filter = .LINEAR,
			min_filter = .NEAREST,
			wrap_u = .CLAMP_TO_EDGE,
			wrap_v = .CLAMP_TO_EDGE,
		},
	)
	return Texture{kind = kind, image = image, view = view, sampler = sampler}
}

// Build a flat quad Model procedurally — no Assimp required.
// Each vertex gets one bone influence (bone 0, weight 1.0) so the skinning shader
// doesn't zero out positions when all bone_transforms are identity (anim_idx = -1).
make_plane :: proc(
	size: f32,
	diffuse: [4]u8 = {150, 150, 150, 255},
	specular: [4]u8 = {30, 30, 30, 255},
) -> ^Model {
	half := size / 2.0

	vertices := []Vertex {
		{position = {-half, 0, -half}, normal = {0, 1, 0}, tex_coords = {0, 0}},
		{position = {half, 0, -half}, normal = {0, 1, 0}, tex_coords = {1, 0}},
		{position = {half, 0, half}, normal = {0, 1, 0}, tex_coords = {1, 1}},
		{position = {-half, 0, half}, normal = {0, 1, 0}, tex_coords = {0, 1}},
	}
	indices := []u32{0, 1, 2, 0, 2, 3}

	vertex_bone_data: map[int]VertexBoneData
	for i in 0 ..< 4 {
		vertex_bone_data[i] = VertexBoneData {
			influences = {0 = {bone_index = 0, weight = 1.0}},
			count = 1,
		}
	}

	textures := make([]Texture, 2)
	textures[0] = make_solid_texture(diffuse, .Diffuse)
	textures[1] = make_solid_texture(specular, .Specular)

	mesh := Mesh {
		vertices         = vertices,
		indices          = indices,
		vertex_bone_data = vertex_bone_data,
		textures         = textures,
	}
	setup_mesh(&mesh)

	m := new(Model)
	m.meshes = make([]Mesh, 1)
	m.meshes[0] = mesh
	return m
}

// Caller must apply pipeline and set global uniforms before calling
draw :: proc(m: ^Model, anim_idx: int, time_secs: f64) {
	for &mesh in m.meshes {
		bone_transforms: [MAX_BONES_PER_MESH]Mat4
		if anim_idx >= 0 && anim_idx < len(m.animations) {
			bone_transforms = compute_bone_transforms(m, &mesh, &m.animations[anim_idx], time_secs)
		} else {
			for &bt in bone_transforms do bt = linalg.identity(Mat4)
		}
		draw_mesh(&mesh, bone_transforms)
	}
}
