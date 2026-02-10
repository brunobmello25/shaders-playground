#+feature dynamic-literals

package main

import "core:c"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:strings"

import stbi "vendor:stb/image"

import sg "vendor/sokol/sokol/gfx"
import assimp "vendor/assimp"
import shaders "shaders"

// ============================================================================
// DEPRECATED STRUCTS (Old system - for backward compatibility)
// ============================================================================

DEPRECATED_Model :: struct {
	vertices:      sg.Buffer,
	indices:       sg.Buffer,
	indices_count: int,
	vertex_count:  int,
}

DEPRECATED_Texture :: struct {
	image:   sg.Image,
	sampler: sg.Sampler,
	view:    sg.View,
}

TextureGlobals :: struct {
	loaded_textures:     map[cstring]DEPRECATED_Texture,  // Old system
	loaded_new_textures: map[string]Texture,              // New system
}

// ============================================================================
// NEW MESH/MODEL SYSTEM
// ============================================================================

Vertex :: struct {
	position:   Vec3,
	normal:     Vec3,
	tex_coords: Vec2,
}

TextureKind :: enum {
	Diffuse,
	Specular,
	Normal,
	Height,
	Ambient,
	Emissive,
	Roughness,
	Metallic,
	AO,
}

Texture :: struct {
	kind:    TextureKind,
	image:   sg.Image,
	sampler: sg.Sampler,
	view:    sg.View,
	path:    cstring,
}

Mesh :: struct {
	vertices:      []Vertex,
	indices:       []u32,
	textures:      []Texture,
	vertex_buffer: sg.Buffer,
	index_buffer:  sg.Buffer,
}

Model :: struct {
	meshes:    []Mesh,
	directory: string,
}

// ============================================================================
// DEPRECATED TEXTURE LOADING (Old system)
// ============================================================================

load_texture :: proc(path: cstring) -> DEPRECATED_Texture {
	texture, ok := g.loaded_textures[path]
	if ok {
		return texture
	}

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

	texture = DEPRECATED_Texture {
		image   = image,
		sampler = sampler,
		view    = view,
	}
	g.loaded_textures[path] = texture
	return texture
}

make_white_texture :: proc() -> DEPRECATED_Texture {
	white_pixel := [4]u8{255, 255, 255, 255}

	image := sg.make_image(
		{
			width = 1,
			height = 1,
			pixel_format = .RGBA8,
			data = {mip_levels = {0 = sg.Range{ptr = &white_pixel, size = size_of(white_pixel)}}},
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

	return DEPRECATED_Texture{image = image, sampler = sampler, view = view}
}


make_cube :: proc() -> DEPRECATED_Model {
	// odinfmt: disable
	vertices_data := [dynamic]f32{
		// positions       // normals        // texture coords
		-0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  0.0,  0.0,
		 0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  1.0,  0.0,
		 0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  1.0,  1.0,
		 0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  1.0,  1.0,
		-0.5,  0.5, -0.5,  0.0,  0.0, -1.0,  0.0,  1.0,
		-0.5, -0.5, -0.5,  0.0,  0.0, -1.0,  0.0,  0.0,

		-0.5, -0.5,  0.5,  0.0,  0.0,  1.0,  0.0,  0.0,
		 0.5, -0.5,  0.5,  0.0,  0.0,  1.0,  1.0,  0.0,
		 0.5,  0.5,  0.5,  0.0,  0.0,  1.0,  1.0,  1.0,
		 0.5,  0.5,  0.5,  0.0,  0.0,  1.0,  1.0,  1.0,
		-0.5,  0.5,  0.5,  0.0,  0.0,  1.0,  0.0,  1.0,
		-0.5, -0.5,  0.5,  0.0,  0.0,  1.0,  0.0,  0.0,

		-0.5,  0.5,  0.5, -1.0,  0.0,  0.0,  1.0,  1.0,
		-0.5,  0.5, -0.5, -1.0,  0.0,  0.0,  0.0,  1.0,
		-0.5, -0.5, -0.5, -1.0,  0.0,  0.0,  0.0,  0.0,
		-0.5, -0.5, -0.5, -1.0,  0.0,  0.0,  0.0,  0.0,
		-0.5, -0.5,  0.5, -1.0,  0.0,  0.0,  1.0,  0.0,
		-0.5,  0.5,  0.5, -1.0,  0.0,  0.0,  1.0,  1.0,

		 0.5,  0.5,  0.5,  1.0,  0.0,  0.0,  0.0,  1.0,
		 0.5,  0.5, -0.5,  1.0,  0.0,  0.0,  1.0,  1.0,
		 0.5, -0.5, -0.5,  1.0,  0.0,  0.0,  1.0,  0.0,
		 0.5, -0.5, -0.5,  1.0,  0.0,  0.0,  1.0,  0.0,
		 0.5, -0.5,  0.5,  1.0,  0.0,  0.0,  0.0,  0.0,
		 0.5,  0.5,  0.5,  1.0,  0.0,  0.0,  0.0,  1.0,

		-0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  0.0,  1.0,
		 0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  1.0,  1.0,
		 0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  1.0,  0.0,
		 0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  1.0,  0.0,
		-0.5, -0.5,  0.5,  0.0, -1.0,  0.0,  0.0,  0.0,
		-0.5, -0.5, -0.5,  0.0, -1.0,  0.0,  0.0,  1.0,

		-0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  0.0,  1.0,
		 0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  1.0,  1.0,
		 0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  1.0,  0.0,
		 0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  1.0,  0.0,
		-0.5,  0.5,  0.5,  0.0,  1.0,  0.0,  0.0,  0.0,
		-0.5,  0.5, -0.5,  0.0,  1.0,  0.0,  0.0,  1.0
	}
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

	return DEPRECATED_Model{vertices = vertices_buffer, indices = {}, vertex_count = 36, indices_count = 0}
}

// ============================================================================
// NEW SYSTEM IMPLEMENTATION
// ============================================================================

// Phase 2: Mesh Setup
setup_mesh :: proc(mesh: ^Mesh) {
	// Convert Vertex slice to interleaved float array
	// Layout: position(3) + normal(3) + texcoord(2) = 8 floats per vertex
	vertices_flat := make([]f32, len(mesh.vertices) * 8)
	defer delete(vertices_flat)

	for v, i in mesh.vertices {
		offset := i * 8
		vertices_flat[offset + 0] = v.position.x
		vertices_flat[offset + 1] = v.position.y
		vertices_flat[offset + 2] = v.position.z
		vertices_flat[offset + 3] = v.normal.x
		vertices_flat[offset + 4] = v.normal.y
		vertices_flat[offset + 5] = v.normal.z
		vertices_flat[offset + 6] = v.tex_coords.x
		vertices_flat[offset + 7] = v.tex_coords.y
	}

	// Create vertex buffer
	mesh.vertex_buffer = sg.make_buffer(
		{data = range(vertices_flat[:]), size = len(vertices_flat) * size_of(f32)},
	)

	// Create index buffer
	mesh.index_buffer = sg.make_buffer(
		{
			data = range(mesh.indices[:]),
			size = len(mesh.indices) * size_of(u32),
		},
	)
}

// Phase 3: Texture Loading
make_white_texture_with_kind :: proc(kind: TextureKind) -> Texture {
	white_pixel := [4]u8{255, 255, 255, 255}

	image := sg.make_image(
		{
			width = 1,
			height = 1,
			pixel_format = .RGBA8,
			data = {mip_levels = {0 = sg.Range{ptr = &white_pixel, size = size_of(white_pixel)}}},
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

	return Texture{kind = kind, image = image, sampler = sampler, view = view, path = ""}
}

load_texture_with_kind :: proc(path: string, kind: TextureKind) -> Texture {
	// Cache key: "path|kind" to allow same image with different kinds
	cache_key := fmt.tprintf("%s|%v", path, kind)

	if cached, ok := g.loaded_new_textures[cache_key]; ok {
		return cached
	}

	// Load image using stb_image
	width, height, channels: c.int
	stbi.set_flip_vertically_on_load(1)
	img_bytes := stbi.load(strings.clone_to_cstring(path), &width, &height, &channels, 4)
	defer stbi.image_free(img_bytes)

	if img_bytes == nil {
		log.errorf("Failed to load texture: %s", path)
		// Return white fallback texture
		return make_white_texture_with_kind(kind)
	}

	// Create sokol resources
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

	texture := Texture {
		kind    = kind,
		image   = image,
		sampler = sampler,
		view    = view,
		path    = strings.clone_to_cstring(path),
	}

	g.loaded_new_textures[cache_key] = texture
	return texture
}

// Phase 4: Assimp Integration
aistring_to_string :: proc(ai_str: ^assimp.aiString) -> string {
	if ai_str.length == 0 do return ""
	data_ptr := cast(^u8)&ai_str.data
	bytes := make([]u8, ai_str.length)
	for i in 0 ..< ai_str.length {
		bytes[i] = mem.ptr_offset(data_ptr, i)^
	}
	return string(bytes)
}

resolve_texture_path :: proc(directory: string, texture_path: string) -> string {
	if strings.has_prefix(texture_path, "/") || strings.contains(texture_path, ":") {
		return texture_path // Absolute path
	}
	return fmt.tprintf("%s/%s", directory, texture_path)
}

texturekind_to_ai_type :: proc(kind: TextureKind) -> assimp.aiTextureType {
	#partial switch kind {
	case .Diffuse:
		return .DIFFUSE
	case .Specular:
		return .SPECULAR
	case .Normal:
		return .NORMALS
	case .Height:
		return .HEIGHT
	case .Ambient:
		return .AMBIENT
	case .Emissive:
		return .EMISSIVE
	case:
		return .NONE
	}
}

load_material_textures :: proc(
	material: ^assimp.aiMaterial,
	kind: TextureKind,
	directory: string,
	textures: ^[dynamic]Texture,
) {
	ai_type := texturekind_to_ai_type(kind)
	texture_count := assimp.get_material_textureCount(material, ai_type)

	for i in 0 ..< texture_count {
		ai_path: assimp.aiString
		result := assimp.get_material_texture(
			material,
			ai_type,
			i,
			&ai_path,
			nil,
			nil,
			nil,
			nil,
			nil,
		)

		if result != .SUCCESS do continue

		texture_path := aistring_to_string(&ai_path)
		full_path := resolve_texture_path(directory, texture_path)
		texture := load_texture_with_kind(full_path, kind)
		append(textures, texture)
	}
}

process_mesh :: proc(
	ai_mesh: ^assimp.aiMesh,
	scene: ^assimp.aiScene,
	directory: string,
) -> Mesh {
	vertices := make([dynamic]Vertex, 0, ai_mesh.mNumVertices)
	indices := make([dynamic]u32)
	textures := make([dynamic]Texture)

	// Extract vertices
	for i in 0 ..< ai_mesh.mNumVertices {
		vertex := Vertex{}

		// Position (always present)
		pos := mem.ptr_offset(ai_mesh.mVertices, int(i))
		vertex.position = Vec3{pos.x, pos.y, pos.z}

		// Normal (may be nil)
		if ai_mesh.mNormals != nil {
			normal := mem.ptr_offset(ai_mesh.mNormals, int(i))
			vertex.normal = Vec3{normal.x, normal.y, normal.z}
		} else {
			vertex.normal = Vec3{0, 0, 1}
		}

		// Texture coords (check first set, note: aiVector3D with .x, .y)
		if ai_mesh.mTextureCoords[0] != nil {
			uv := mem.ptr_offset(ai_mesh.mTextureCoords[0], int(i))
			vertex.tex_coords = Vec2{uv.x, uv.y}
		} else {
			vertex.tex_coords = Vec2{0, 0}
		}

		append(&vertices, vertex)
	}

	// Extract indices
	for i in 0 ..< ai_mesh.mNumFaces {
		face := mem.ptr_offset(ai_mesh.mFaces, int(i))
		for j in 0 ..< face.mNumIndices {
			index := mem.ptr_offset(face.mIndices, int(j))^
			append(&indices, index)
		}
	}

	// Load textures from material
	if ai_mesh.mMaterialIndex >= 0 {
		material := mem.ptr_offset(scene.mMaterials, int(ai_mesh.mMaterialIndex))^
		load_material_textures(material, .Diffuse, directory, &textures)
		load_material_textures(material, .Specular, directory, &textures)
		// Add more kinds as needed
	}

	mesh := Mesh {
		vertices = vertices[:],
		indices  = indices[:],
		textures = textures[:],
	}

	setup_mesh(&mesh)
	return mesh
}

process_node :: proc(
	node: ^assimp.aiNode,
	scene: ^assimp.aiScene,
	meshes: ^[dynamic]Mesh,
	directory: string,
) {
	// Process all meshes in this node
	for i in 0 ..< node.mNumMeshes {
		mesh_index := mem.ptr_offset(node.mMeshes, i)^
		ai_mesh := mem.ptr_offset(scene.mMeshes, int(mesh_index))^
		mesh := process_mesh(ai_mesh, scene, directory)
		append(meshes, mesh)
	}

	// Recursively process children
	for i in 0 ..< node.mNumChildren {
		child := mem.ptr_offset(node.mChildren, int(i))^
		process_node(child, scene, meshes, directory)
	}
}

load_model :: proc(filepath: string) -> (Model, bool) {
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
		return Model{}, false
	}
	defer assimp.release_import(scene)

	// Extract directory
	last_slash := strings.last_index(filepath, "/")
	directory := filepath[:last_slash] if last_slash >= 0 else "."

	// Process scene graph
	meshes := make([dynamic]Mesh)
	if scene.mRootNode != nil {
		process_node(scene.mRootNode, scene, &meshes, directory)
	}

	log.infof("Loaded model: %s (%d meshes)", filepath, len(meshes))
	return Model{meshes = meshes[:], directory = directory}, true
}

// Phase 5: Drawing
draw_mesh :: proc(mesh: ^Mesh, camera: Camera) {
	bindings := sg.Bindings {
		vertex_buffers = {0 = mesh.vertex_buffer},
		index_buffer = mesh.index_buffer,
	}

	// Bind textures by kind (use first of each kind)
	has_diffuse, has_specular := false, false

	for texture in mesh.textures {
		#partial switch texture.kind {
		case .Diffuse:
			if !has_diffuse {
				bindings.views[shaders.VIEW_entity_diffuse_texture] = texture.view
				bindings.samplers[shaders.SMP_entity_diffuse_sampler] = texture.sampler
				has_diffuse = true
			}
		case .Specular:
			if !has_specular {
				bindings.views[shaders.VIEW_entity_specular_texture] = texture.view
				bindings.samplers[shaders.SMP_entity_specular_sampler] = texture.sampler
				has_specular = true
			}
		}
	}

	// Fallback to white texture if missing
	if !has_diffuse {
		white := make_white_texture_with_kind(.Diffuse)
		bindings.views[shaders.VIEW_entity_diffuse_texture] = white.view
		bindings.samplers[shaders.SMP_entity_diffuse_sampler] = white.sampler
	}
	if !has_specular {
		white := make_white_texture_with_kind(.Specular)
		bindings.views[shaders.VIEW_entity_specular_texture] = white.view
		bindings.samplers[shaders.SMP_entity_specular_sampler] = white.sampler
	}

	sg.apply_bindings(bindings)
	sg.draw(0, i32(len(mesh.indices)), 1)
}

draw_model :: proc(model: ^Model, camera: Camera) {
	// Caller must apply pipeline and set global uniforms before calling
	for &mesh in model.meshes {
		draw_mesh(&mesh, camera)
	}
}
