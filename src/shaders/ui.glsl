@header package shaders
@header import sg "../vendor/sokol/sokol/gfx"

@vs vs

layout(binding=0) uniform UI_VS_Params {
    vec2 screen_size;
};

in vec2 a_pos;
in vec2 a_uv;
in vec4 a_color;

out vec2 v_uv;
out vec4 v_color;

void main() {
    gl_Position = vec4(
        (a_pos.x / screen_size.x) * 2.0 - 1.0,
        1.0 - (a_pos.y / screen_size.y) * 2.0,
        0.0,
        1.0
    );
    v_uv = a_uv;
    v_color = a_color;
}

@end

@fs fs

layout(binding=0) uniform texture2D ui_atlas;
layout(binding=0) uniform sampler ui_sampler;

in vec2 v_uv;
in vec4 v_color;

out vec4 frag_color;

void main() {
    float a = texture(sampler2D(ui_atlas, ui_sampler), v_uv).r;
    frag_color = vec4(v_color.rgb, v_color.a * a);
}

@end

@program ui vs fs
