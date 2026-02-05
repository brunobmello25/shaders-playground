# Extracting Shader Blocks to Separate Files in sokol/shdc

In sokol/shdc, you can use the `@block` annotation to define reusable shader code and extract it to separate files using the `@include` directive.

## Step 1: Create a common blocks file

Create a new file: `src/shaders/common.glsl`

```glsl
@block LightUniform
layout (binding=2) uniform Entity_FS_Light {
    vec3 position;

    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
} light;
@end
```

## Step 2: Include the file in your shaders

In your `entity.glsl` (or any other shader file):

```glsl
@header package shaders;
@header import sg "../../sokol/gfx";

@include "common.glsl"

@ctype mat4 Mat4

@vs vs
// ... your vertex shader
@end

@fs fs
@include_block LightUniform

in vec3 normal;
in vec3 fragWorldPos;
in vec2 uv;

out vec4 fragColor;

// ... rest of your fragment shader
@end
```

## Key Points

- **`@include "relative/path.glsl"`** - Includes the file (path is relative to current shader file)
- **`@include_block BlockName`** - Inserts the block definition into your shader
- The included file can contain multiple `@block` definitions
- You don't need `@header` directives in the included file, just the `@block` definitions
- Binding numbers still need to be managed consistently across shaders

## Benefits

- Reuse uniform definitions across multiple shaders
- Keep common lighting/material code in one place
- Easier to maintain consistent interfaces

## Example: Reusing Across Multiple Shaders

Once you have `common.glsl` with your blocks defined, you can use them in multiple shaders:

**entity.glsl:**
```glsl
@include "common.glsl"

@fs fs
@include_block LightUniform
// ... entity-specific code
@end
```

**terrain.glsl:**
```glsl
@include "common.glsl"

@fs fs
@include_block LightUniform
// ... terrain-specific code
@end
```

Both shaders now share the same light uniform definition.
