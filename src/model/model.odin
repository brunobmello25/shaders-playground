#+private package

package model

import "core:c"
import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:path/filepath"
import "core:strings"

import stbi "vendor:stb/image"

import shaders "../shaders"
import assimp "../vendor/assimp"
import sg "../vendor/sokol/sokol/gfx"

MAX_BONES_PER_VERTEX :: 4
MAX_BONES_PER_MESH :: 100

Vec3 :: [3]f32
Vec2 :: [2]f32
Mat4 :: matrix[4, 4]f32

ModelKind :: enum {
	Bulb,
	Backpack,
	Container,
	CharacterLowPoly,
}

// TODO: this is duplicated from helpers. maybe move this to a package
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

// Package-level caches
loaded_textures: map[string]Texture
loaded_models: map[string]Model

// ============================================================================
// Types
// ============================================================================

BoneWeight :: struct {
	vertex_id: int,
	weight:    f32,
}

Bone :: struct {
	name:          string,
	offset_matrix: Mat4,
	weights:       []BoneWeight,
}

BoneInfluence :: struct {
	bone_index: int,
	weight:     f32,
}

VertexBoneData :: struct {
	influences: [MAX_BONES_PER_VERTEX]BoneInfluence,
	count:      int,
}

Node :: struct {
	name:      string,
	transform: Mat4,
	children:  []Node,
}

VectorKey :: struct {
	time:  f64,
	value: Vec3,
}

QuatKey :: struct {
	time:        f64,
	x, y, z, w: f32,
}

NodeAnim :: struct {
	node_name:     string,
	position_keys: []VectorKey,
	rotation_keys: []QuatKey,
	scale_keys:    []VectorKey,
}

Animation :: struct {
	name:             string,
	duration:         f64,
	ticks_per_second: f64,
	channels:         []NodeAnim,
	channel_map:      map[string]int,
}

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
	vertices:         []Vertex,
	indices:          []u32,
	textures:         []Texture,
	bones:            []Bone,
	bone_map:         map[string]int,
	vertex_bone_data: map[int]VertexBoneData,
	vertex_buffer:    sg.Buffer,
	index_buffer:     sg.Buffer,
}

// ============================================================================
// Mesh Setup
// ============================================================================

// Setup mesh prepares sokol specific stuff, like the vertex_buffer and the index_buffer for a given mesh
setup_mesh :: proc(mesh: ^Mesh) {
	// Convert Vertex slice to interleaved float array
	// Layout: position(3) + normal(3) + texcoord(2) + bone indices(4) + bone weights(4) = 16 floats per vertex
	base := 16
	vertices_flat := make([]f32, len(mesh.vertices) * base)
	defer delete(vertices_flat)

	for v, i in mesh.vertices {
		offset := i * base
		vertices_flat[offset + 0] = v.position.x
		vertices_flat[offset + 1] = v.position.y
		vertices_flat[offset + 2] = v.position.z
		vertices_flat[offset + 3] = v.normal.x
		vertices_flat[offset + 4] = v.normal.y
		vertices_flat[offset + 5] = v.normal.z
		vertices_flat[offset + 6] = v.tex_coords.x
		vertices_flat[offset + 7] = v.tex_coords.y

		for j in 0 ..< mesh.vertex_bone_data[i].count {
			influence := mesh.vertex_bone_data[i].influences[j]

			vertices_flat[offset + 8 + j] = f32(influence.bone_index)
			vertices_flat[offset + 8 + MAX_BONES_PER_VERTEX + j] = influence.weight
		}
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
			usage = {index_buffer = true},
		},
	)
}

// ============================================================================
// Texture Loading
// ============================================================================

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

	if cached, ok := loaded_textures[cache_key]; ok {
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

	loaded_textures[cache_key] = texture
	return texture
}

// ============================================================================
// Assimp Integration
// ============================================================================

aistring_to_string :: proc(ai_str: ^assimp.aiString) -> string {
	if ai_str == nil || ai_str.length == 0 do return ""
	// Copy the string data from the fixed array
	bytes := make([]u8, ai_str.length)
	copy(bytes, ai_str.data[:ai_str.length])
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

process_mesh :: proc(ai_mesh: ^assimp.aiMesh, scene: ^assimp.aiScene, directory: string) -> Mesh {
	vertices := make([dynamic]Vertex, 0, ai_mesh.mNumVertices)
	indices := make([dynamic]u32)
	textures := make([dynamic]Texture)
	bones := make([dynamic]Bone)

	// Extract vertices
	for i in 0 ..< ai_mesh.mNumVertices {
		vertex := Vertex{}

		// Position (always present)
		pos := mem.ptr_offset(ai_mesh.mVertices, int(i))
		vertex.position = Vec3{pos.x, pos.y, pos.z}

		// Normal (may be nil)
		// TODO: what should we do if normals are missing?
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

	// extract bones
	for i in 0 ..< ai_mesh.mNumBones {
		bone := Bone{}
		aibone := mem.ptr_offset(ai_mesh.mBones, int(i))

		bone.name = aistring_to_string(&aibone^.mName)

		// TODO: check that this offset matrix is in the format we expect.
			// odinfmt: disable
		m := aibone^.mOffsetMatrix
		bone.offset_matrix = Mat4{
			m.a1, m.a2, m.a3, m.a4,
			m.b1, m.b2, m.b3, m.b4,
			m.c1, m.c2, m.c3, m.c4,
			m.d1, m.d2, m.d3, m.d4,
		}
		// odinfmt: enable

		bone.weights = make([]BoneWeight, aibone^.mNumWeights)
		if aibone^.mWeights != nil {
			for j in 0 ..< aibone^.mNumWeights {
				aiweight := mem.ptr_offset(aibone^.mWeights, int(j))
				bone.weights[j] = BoneWeight {
					vertex_id = int(aiweight^.mVertexId),
					weight    = aiweight^.mWeight,
				}
			}
		}

		append(&bones, bone)
	}

	// Build vertex -> bone influences map
	vertex_bone_data := make(map[int]VertexBoneData)
	for bone_idx in 0 ..< len(bones) {
		for bw in bones[bone_idx].weights {
			data := vertex_bone_data[bw.vertex_id] or_else VertexBoneData{}

			fmt.assertf(
				data.count < MAX_BONES_PER_VERTEX,
				"Too many bone influences for vertex. Please increase MAX_BONES_PER_VERTEX or clean up your model. Vertex %d has %d influences",
				bw.vertex_id,
				data.count,
			)

			data.influences[data.count] = BoneInfluence {
				bone_index = bone_idx,
				weight     = bw.weight,
			}
			data.count += 1
			vertex_bone_data[bw.vertex_id] = data
		}
	}

	// Build bone name -> index map for animation lookups
	bone_map: map[string]int
	for i in 0 ..< len(bones) {
		bone_map[bones[i].name] = i
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

	// Ensure every mesh has at least a diffuse and specular texture
	has_diffuse, has_specular := false, false
	for t in textures {
		if t.kind == .Diffuse do has_diffuse = true
		if t.kind == .Specular do has_specular = true
	}
	if !has_diffuse do append(&textures, make_white_texture_with_kind(.Diffuse))
	if !has_specular do append(&textures, make_white_texture_with_kind(.Specular))

	mesh := Mesh {
		vertices         = vertices[:],
		indices          = indices[:],
		textures         = textures[:],
		bones            = bones[:],
		bone_map         = bone_map,
		vertex_bone_data = vertex_bone_data,
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
		mesh_index := mem.ptr_offset(node.mMeshes, int(i))^
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

kind_to_path :: proc(kind: ModelKind) -> string {
	path: string
	switch kind {
	case .Bulb:
		path = ("res/bulb/bulb.obj")
	case .Backpack:
		path = ("res/backpack/backpack.obj")
	case .Container:
		path = ("res/container/container.obj")
	case .CharacterLowPoly:
		path = ("res/character-low-poly/Character.gltf")
	}

	path, _ = filepath.from_slash(path) // TEST: test that this really works on windows even though im passing slash here
	return path
}

extract_node :: proc(ai_node: ^assimp.aiNode) -> Node {
	node: Node
	node.name = aistring_to_string(&ai_node.mName)

	m := ai_node.mTransformation
	// odinfmt: disable
	node.transform = Mat4{
		m.a1, m.a2, m.a3, m.a4,
		m.b1, m.b2, m.b3, m.b4,
		m.c1, m.c2, m.c3, m.c4,
		m.d1, m.d2, m.d3, m.d4,
	}
	// odinfmt: enable

	node.children = make([]Node, ai_node.mNumChildren)
	for i in 0 ..< ai_node.mNumChildren {
		child := mem.ptr_offset(ai_node.mChildren, int(i))^
		node.children[i] = extract_node(child)
	}

	return node
}

extract_animation :: proc(ai_anim: ^assimp.aiAnimation) -> Animation {
	anim: Animation
	anim.name = aistring_to_string(&ai_anim.mName)
	anim.duration = ai_anim.mDuration
	anim.ticks_per_second = ai_anim.mTicksPerSecond

	anim.channels = make([]NodeAnim, ai_anim.mNumChannels)
	for i in 0 ..< ai_anim.mNumChannels {
		ai_ch := mem.ptr_offset(ai_anim.mChannels, int(i))^

		ch: NodeAnim
		ch.node_name = aistring_to_string(&ai_ch.mNodeName)

		ch.position_keys = make([]VectorKey, ai_ch.mNumPositionKeys)
		for j in 0 ..< ai_ch.mNumPositionKeys {
			k := mem.ptr_offset(ai_ch.mPositionKeys, int(j))^
			ch.position_keys[j] = VectorKey{time = k.mTime, value = {k.mValue.x, k.mValue.y, k.mValue.z}}
		}

		ch.rotation_keys = make([]QuatKey, ai_ch.mNumRotationKeys)
		for j in 0 ..< ai_ch.mNumRotationKeys {
			k := mem.ptr_offset(ai_ch.mRotationKeys, int(j))^
			ch.rotation_keys[j] = QuatKey {
				time = k.mTime,
				x    = k.mValue.x,
				y    = k.mValue.y,
				z    = k.mValue.z,
				w    = k.mValue.w,
			}
		}

		ch.scale_keys = make([]VectorKey, ai_ch.mNumScalingKeys)
		for j in 0 ..< ai_ch.mNumScalingKeys {
			k := mem.ptr_offset(ai_ch.mScalingKeys, int(j))^
			ch.scale_keys[j] = VectorKey{time = k.mTime, value = {k.mValue.x, k.mValue.y, k.mValue.z}}
		}

		anim.channel_map[ch.node_name] = int(i)
		anim.channels[i] = ch
	}

	return anim
}

interpolate_position :: proc(ch: ^NodeAnim, anim_time: f64) -> Vec3 {
	if len(ch.position_keys) == 1 do return ch.position_keys[0].value

	idx := len(ch.position_keys) - 2
	for i in 0 ..< len(ch.position_keys) - 1 {
		if anim_time < ch.position_keys[i + 1].time {
			idx = i
			break
		}
	}

	t := f32((anim_time - ch.position_keys[idx].time) / (ch.position_keys[idx + 1].time - ch.position_keys[idx].time))
	t = clamp(t, 0, 1)
	return ch.position_keys[idx].value + t * (ch.position_keys[idx + 1].value - ch.position_keys[idx].value)
}

interpolate_rotation :: proc(ch: ^NodeAnim, anim_time: f64) -> quaternion128 {
	k1 := ch.rotation_keys[0]
	if len(ch.rotation_keys) == 1 {
		return quaternion(w = k1.w, x = k1.x, y = k1.y, z = k1.z)
	}

	idx := len(ch.rotation_keys) - 2
	for i in 0 ..< len(ch.rotation_keys) - 1 {
		if anim_time < ch.rotation_keys[i + 1].time {
			idx = i
			break
		}
	}

	k1 = ch.rotation_keys[idx]
	k2 := ch.rotation_keys[idx + 1]
	t := f32((anim_time - k1.time) / (k2.time - k1.time))
	t = clamp(t, 0, 1)

	x := k1.x + t * (k2.x - k1.x)
	y := k1.y + t * (k2.y - k1.y)
	z := k1.z + t * (k2.z - k1.z)
	w := k1.w + t * (k2.w - k1.w)
	inv_len := 1.0 / math.sqrt(x * x + y * y + z * z + w * w)
	return quaternion(w = w * inv_len, x = x * inv_len, y = y * inv_len, z = z * inv_len)
}

interpolate_scale :: proc(ch: ^NodeAnim, anim_time: f64) -> Vec3 {
	if len(ch.scale_keys) == 1 do return ch.scale_keys[0].value

	idx := len(ch.scale_keys) - 2
	for i in 0 ..< len(ch.scale_keys) - 1 {
		if anim_time < ch.scale_keys[i + 1].time {
			idx = i
			break
		}
	}

	t := f32((anim_time - ch.scale_keys[idx].time) / (ch.scale_keys[idx + 1].time - ch.scale_keys[idx].time))
	t = clamp(t, 0, 1)
	return ch.scale_keys[idx].value + t * (ch.scale_keys[idx + 1].value - ch.scale_keys[idx].value)
}

compute_node_transforms :: proc(
	node: ^Node,
	parent_transform: Mat4,
	global_inverse: Mat4,
	mesh: ^Mesh,
	anim: ^Animation,
	anim_time: f64,
	result: ^[MAX_BONES_PER_MESH]Mat4,
) {
	local_transform := node.transform

	if ch_idx, ok := anim.channel_map[node.name]; ok {
		ch := &anim.channels[ch_idx]
		t := linalg.matrix4_translate_f32(interpolate_position(ch, anim_time))
		r := linalg.matrix4_from_quaternion(interpolate_rotation(ch, anim_time))
		s := linalg.matrix4_scale_f32(interpolate_scale(ch, anim_time))
		local_transform = t * r * s
	}

	global_transform := parent_transform * local_transform

	if bone_idx, ok := mesh.bone_map[node.name]; ok {
		result[bone_idx] = global_inverse * global_transform * mesh.bones[bone_idx].offset_matrix
	}

	for &child in node.children {
		compute_node_transforms(&child, global_transform, global_inverse, mesh, anim, anim_time, result)
	}
}

compute_bone_transforms :: proc(
	model: ^Model,
	mesh: ^Mesh,
	anim: ^Animation,
	time_secs: f64,
) -> [MAX_BONES_PER_MESH]Mat4 {
	result: [MAX_BONES_PER_MESH]Mat4
	for &m in result do m = linalg.identity(Mat4)

	tps := anim.ticks_per_second if anim.ticks_per_second != 0 else 25.0
	anim_time := math.mod(time_secs * tps, anim.duration)

	compute_node_transforms(
		&model.root_node,
		linalg.identity(Mat4),
		model.global_inverse,
		mesh,
		anim,
		anim_time,
		&result,
	)
	return result
}

draw_mesh :: proc(mesh: ^Mesh, bone_transforms: [MAX_BONES_PER_MESH]Mat4) {
	bindings := sg.Bindings {
		vertex_buffers = {0 = mesh.vertex_buffer},
		index_buffer = mesh.index_buffer,
	}

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

	sg.apply_bindings(bindings)

	bone_uniforms := shaders.Entity_Vs_Bone_Transforms {
		bone_transforms = bone_transforms,
	}
	sg.apply_uniforms(shaders.UB_Entity_VS_Bone_Transforms, range(&bone_uniforms))

	sg.draw(0, i32(len(mesh.indices)), 1)
}
