package model

import "core:log"
import "core:math/linalg"
import "core:mem"
import "core:strings"

import assimp "../vendor/assimp"

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
