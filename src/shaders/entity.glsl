@header package shaders
@header import sg "../../sokol/gfx";

@ctype mat4 Mat4

@vs vs

in vec3 a_pos;
in vec3 a_normal;
in vec2 a_uv;

out vec3 normal;
out vec3 frag_world_pos;
out vec2 uv;

layout (binding=0) uniform Entity_VS_Params {
	mat4 model;
	mat4 view;
	mat4 projection;
	mat4 normal_matrix;
};

void main () {
	gl_Position = projection * view * model * vec4(a_pos, 1.0);
	frag_world_pos = vec3(model * vec4(a_pos, 1.0));
	normal = mat3(normal_matrix) * a_normal;
	uv = a_uv;
}

@end

@fs fs

in vec3 normal;
in vec3 frag_world_pos;
in vec2 uv;

out vec4 frag_color;

layout (binding=1) uniform Entity_FS_Params {
	vec3 view_pos;
	float shininess;
};

layout (binding=0) uniform texture2D entity_diffuse_texture;
layout (binding=1) uniform texture2D entity_specular_texture;

layout (binding=0) uniform sampler entity_diffuse_sampler;
layout (binding=1) uniform sampler entity_specular_sampler;

#define MAX_LIGHTS 8
#define LIGHT_DIRECTIONAL 1
#define LIGHT_POINT 2
#define LIGHT_SPOT 3

layout (std140, binding=2) uniform FS_Lights {
	int light_count;
	ivec4 kinds[MAX_LIGHTS];
	vec4 directions[MAX_LIGHTS];
	vec4 positions[MAX_LIGHTS];
	vec4 ambients[MAX_LIGHTS];
	vec4 diffuses[MAX_LIGHTS];
	vec4 speculars[MAX_LIGHTS];
	vec4 attenuations[MAX_LIGHTS]; // x: constant, y: linear, z: quadratic
	vec4 cutoffs[MAX_LIGHTS]; // x: cutoff
} fs_lights;

struct Light {
	int kind;
	vec3 direction;
	vec3 position;
	vec3 ambient;
	vec3 diffuse;
	vec3 specular;
	float constant_attenuation;
	float linear_attenuation;
	float quadratic_attenuation;
	float cutoff;
	float outer_cutoff;
};

Light get_light(int i) {
	Light light;
	light.kind = fs_lights.kinds[i].x;
	light.direction = fs_lights.directions[i].xyz;
	light.position = fs_lights.positions[i].xyz;
	light.ambient = fs_lights.ambients[i].xyz;
	light.diffuse = fs_lights.diffuses[i].xyz;
	light.specular = fs_lights.speculars[i].xyz;
	light.constant_attenuation = fs_lights.attenuations[i].x;
	light.linear_attenuation = fs_lights.attenuations[i].y;
	light.quadratic_attenuation = fs_lights.attenuations[i].z;
	light.cutoff = fs_lights.cutoffs[i].x;
	light.outer_cutoff = fs_lights.cutoffs[i].y;
	return light;
}

float get_attenuation(Light light, float distance) {
	return 1.0 / (light.constant_attenuation + light.linear_attenuation * distance + light.quadratic_attenuation * (distance * distance));
}

vec3 calculate_phong_lighting(Light light, float attenuation, vec3 direction) {
	vec3 diffuse_color = vec3(texture(sampler2D(entity_diffuse_texture, entity_diffuse_sampler), uv));
	vec3 specular_color = vec3(texture(sampler2D(entity_specular_texture, entity_specular_sampler), uv));

	// ambient
	vec3 ambient = light.ambient * diffuse_color;

	// diffuse
	vec3 norm = normalize(normal);
	vec3 light_dir = normalize(direction);
	float diff = max(dot(norm, light_dir), 0.0);
	vec3 diffuse = light.diffuse * diff * diffuse_color;

	// specular
	vec3 view_dir = normalize(view_pos - frag_world_pos);
	vec3 reflect_dir = reflect(-light_dir, norm);
	float spec = pow(max(dot(view_dir, reflect_dir), 0.0), shininess);
	vec3 specular = light.specular * spec * specular_color;

	return (ambient + diffuse + specular) * attenuation;
}

void main () {
	int light_count = fs_lights.light_count;

	vec3 result = vec3(0.0);
	for (int i = 0; i < light_count; i++) {
		Light light = get_light(i);

		if(light.kind == LIGHT_DIRECTIONAL) {
			result += calculate_phong_lighting(light, 1.0, -light.direction);
		} else if (light.kind == LIGHT_POINT) {
			float distance = length(light.position - frag_world_pos);
			float attenuation = get_attenuation(light, distance);
			result += calculate_phong_lighting(light, attenuation, light.position - frag_world_pos);
		} else if (light.kind == LIGHT_SPOT) {
			vec3 light_to_frag = frag_world_pos - light.position;
			float distance = length(light_to_frag);
			vec3 light_dir = normalize(light_to_frag);

			// angle between spotlight direction and light to fragment direction
			float theta = dot(light_dir, normalize(light.direction));

			// Convert angle cutoffs to cosine values for comparison
			float cutoff_cos = cos(light.cutoff);
			float outer_cutoff_cos = cos(light.outer_cutoff);
			float epsilon = cutoff_cos - outer_cutoff_cos;
			float intensity = clamp((theta - outer_cutoff_cos) / epsilon, 0.0, 1.0);

			float attenuation = get_attenuation(light, distance);
			result += calculate_phong_lighting(light, attenuation, light.position - frag_world_pos) * intensity;
		}
	}

	frag_color = vec4(result, 1.0);
}

@end

@program entity vs fs
