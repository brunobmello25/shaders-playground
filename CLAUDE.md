# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Odin + Sokol 3D graphics playground following the [Learn OpenGL Book](https://learnopengl.com/). Uses Assimp for model loading and Sokol for graphics/windowing abstraction.

## Build Commands

**Always use the build script, never run `odin build` directly:**

```bash
./bin/build.sh              # Build shaders + game (default)
./target/game               # Run the binary

BUILD_SHADERS=false ./bin/build.sh   # Skip shader compilation
BUILD_SOKOL=true ./bin/build.sh      # Rebuild Sokol C libraries (rarely needed)
BUILD_GAME=false ./bin/build.sh      # Only compile shaders
```

There are no tests or linting configured.

## Shader Pipeline

GLSL shaders in `src/shaders/*.glsl` use Sokol's `@vs`/`@fs`/`@program` annotations. The build script runs `sokol-shdc` to compile them into generated Odin files (`src/shaders/generated_*.odin`). Never edit generated files directly.

## Architecture

### Packages

- **`main` package** (`src/*.odin`): Entry point, entity system, camera, input, lighting, globals
- **`model` package** (`src/model/`): Model loading via Assimp. `public.odin` exposes the API; `model.odin` is `#+private package`
- **`shaders` package** (`src/shaders/`): Shader loading, pipeline setup, generated bindings

### Key Systems

- **Entities** (`entity.odin`): Handle-based entity system (max 100). Each entity has position, scale, model reference, and optional update/draw function pointers.
- **Lighting** (`light.odin`): Supports directional, point, and spot lights (max 8). Converts to std140 layout for shader uniforms.
- **Camera** (`camera.odin`): Free-look camera (WASD + mouse). Manages view/projection matrices and an integrated spotlight.
- **Globals** (`globals.odin`): Central state — shaders, camera, input, entity pool, lights.

### Rendering Flow

`main.odin` frame callback → updates camera → iterates entities → each entity applies its shader pipeline, sets uniform buffers (model/view/projection + lighting), and calls `model.draw()` per mesh.

### Vendors (git submodules in `src/vendor/`)

- **Sokol** (`sokol-odin`): Graphics API abstraction, windowing, input
- **Assimp** (`odin-assimp`): 3D model import (requires system `libassimp` installed)

## Conventions

- Types: `PascalCase`, Procedures: `snake_case`, Constants: `UPPER_SNAKE_CASE`
- Resources (models, textures) live in `res/`
- Models are registered in `model.ModelKind` enum with paths in `model_kind_path()`
