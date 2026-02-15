# New Model System - Quick Start Guide

## Basic Usage

### 1. Loading a Model

```odin
import "core:log"

// Load a 3D model file
model, ok := load_model("res/models/character.fbx")
if !ok {
    log.error("Failed to load model")
    return
}

// The model contains all meshes and their textures
log.infof("Model loaded with %d meshes", len(model.meshes))
```

### 2. Drawing a Model

```odin
// Inside your draw function:

// Apply shader pipeline
sg.apply_pipeline(g.entity_shader.pipeline)

// Set up uniforms (same as before)
model_matrix := linalg.matrix4_translate_f32(position) * linalg.matrix4_scale_f32(scale)
normal_matrix := linalg.transpose(linalg.inverse(model_matrix))
view, proj := view_and_projection(camera)

vs_params := shaders.Entity_Vs_Params {
    model = model_matrix,
    view = view,
    projection = proj,
    normal_matrix = normal_matrix,
}
sg.apply_uniforms(shaders.UB_Entity_VS_Params, range(&vs_params))

fs_params := shaders.Entity_Fs_Params {
    view_pos = camera.pos,
    shininess = 32.0,
}
sg.apply_uniforms(shaders.UB_Entity_FS_Params, range(&fs_params))

fs_lights := lights_to_shader_uniform()
sg.apply_uniforms(shaders.UB_FS_Lights, range(&fs_lights))

// Draw the model (handles all meshes and texture binding automatically)
draw_model(&model, camera)
```

### 3. Manual Mesh Creation

```odin
// Create a mesh manually
vertices := []Vertex{
    {position = {-0.5, -0.5, 0}, normal = {0, 0, 1}, tex_coords = {0, 0}},
    {position = { 0.5, -0.5, 0}, normal = {0, 0, 1}, tex_coords = {1, 0}},
    {position = { 0.0,  0.5, 0}, normal = {0, 0, 1}, tex_coords = {0.5, 1}},
}

indices := []u32{0, 1, 2}

// Load textures
diffuse := load_texture_with_kind("res/texture.png", .Diffuse)
specular := load_texture_with_kind("res/specular.png", .Specular)

mesh := Mesh{
    vertices = vertices,
    indices = indices,
    textures = []Texture{diffuse, specular},
}

// Set up GPU buffers
setup_mesh(&mesh)

// Now you can draw it
draw_mesh(&mesh, camera)
```

## Supported File Formats

The system uses Assimp, which supports:
- `.obj` - Wavefront OBJ
- `.fbx` - Autodesk FBX
- `.gltf`/`.glb` - GL Transmission Format
- `.dae` - COLLADA
- `.blend` - Blender
- `.3ds` - 3D Studio
- And many more!

## Texture Types

The system supports multiple texture types per mesh:

```odin
TextureKind :: enum {
    Diffuse,    // Base color/albedo
    Specular,   // Specular highlights
    Normal,     // Normal mapping
    Height,     // Height/bump mapping
    Ambient,    // Ambient occlusion
    Emissive,   // Emission/glow
    Roughness,  // PBR roughness
    Metallic,   // PBR metallic
    AO,         // Ambient occlusion
}
```

Currently, the shader supports **Diffuse** and **Specular** textures. The system will use the first texture of each kind found in the mesh.

## Features

### Automatic Texture Caching
```odin
// These will load the texture only once
tex1 := load_texture_with_kind("res/wood.png", .Diffuse)
tex2 := load_texture_with_kind("res/wood.png", .Diffuse)  // Uses cached version
```

### Fallback Textures
If a texture fails to load, the system automatically provides a white fallback texture, so your models always render.

### Multi-Mesh Support
Complex models with multiple sub-meshes are automatically handled:
```odin
model, _ := load_model("res/character.fbx")
// model.meshes contains all sub-meshes (head, body, weapons, etc.)
// draw_model() handles all of them automatically
```

## Migration Path

### Current (Old System)
```odin
// Old way - still works!
entity.model = make_cube()
entity.diffuse_texture = load_texture("res/texture.png")
entity.specular_texture = load_texture("res/specular.png")
```

### Future (New System)
```odin
// New way - available now for testing
model, ok := load_model("res/models/cube.obj")
// Then integrate into Entity struct (coming in future update)
```

## Performance Notes

- **CPU Data Retained**: The system keeps vertex/index arrays in memory for potential physics/debugging use
- **Texture Caching**: Textures are cached by path+kind to avoid duplicates
- **Single Draw Call per Mesh**: Each mesh uses one draw call with all its textures bound

## Example: Loading a Complex Model

```odin
// Load a character model with multiple meshes and textures
character_model, ok := load_model("res/models/warrior.fbx")
if !ok {
    log.error("Failed to load character")
    return
}

// The model automatically contains:
// - All sub-meshes (head, torso, legs, weapon, etc.)
// - All textures (diffuse, specular) from the FBX materials
// - GPU buffers ready to render

// Later in your render loop:
sg.apply_pipeline(g.entity_shader.pipeline)
// ... set uniforms ...
draw_model(&character_model, camera)  // Renders everything!
```

## Troubleshooting

### Model doesn't load
- Check the file path is correct
- Verify the file format is supported by Assimp
- Check console logs for error messages

### Textures are white
- Texture paths in the model file may be incorrect
- The system falls back to white if textures can't be loaded
- Check the model's directory contains the texture files

### Model appears black
- Check that lighting uniforms are being set
- Verify normals are correct (use `.GenNormals` flag in loader)
- Ensure the shader is receiving light data

## Next Steps

To fully integrate into your Entity system:
1. Add `new_model: Maybe(Model)` to the Entity struct
2. Create setup functions that use the new system
3. Gradually migrate entities to use loaded models
4. Test with actual 3D model files
