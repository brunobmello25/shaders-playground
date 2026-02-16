package model

import "core:log"
import "core:mem"
import "core:strings"

import assimp "../vendor/assimp"

Model :: struct {
	meshes:    []Mesh,
	directory: string,
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
		u32(assimp.aiPostProcessSteps.CalcTangentSpace)

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

	log.infof("Loaded model: %s (%d meshes)", filepath, len(meshes))
	loaded_models[filepath] = Model {
		meshes    = meshes[:],
		directory = directory,
	}
	return &loaded_models[filepath], true
}

// Caller must apply pipeline and set global uniforms before calling
draw :: proc(m: ^Model) {
	for &mesh in m.meshes {
		draw_mesh(&mesh)
	}
}
