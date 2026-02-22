@header package shaders
@header import sg "../vendor/sokol/sokol/gfx";

@ctype mat4 Mat4

@vs vs

#define MAX_BONES_PER_MESH 100

in vec3 a_pos;
in vec3 a_normal;
in vec2 a_uv;
in vec4 bone_ids;
in vec4 bone_weights;

out vec3 normal;
out vec3 frag_world_pos;
out vec2 uv;

layout (binding=0) uniform Entity_VS_Params {
	mat4 model;
	mat4 view;
	mat4 projection;
	mat4 normal_matrix;
};

layout(binding=1) uniform Entity_VS_Bone_Transforms {
	mat4 bone_transforms[MAX_BONES_PER_MESH];
};

void main () {
	vec4 skinned_pos = vec4(0.0);
	vec4 skinned_normal = vec4(0.0);
	for (int i = 0; i < 4; i++) {
		int bone_id = int(bone_ids[i]);
		float weight = bone_weights[i];
		skinned_pos += weight * (bone_transforms[bone_id] * vec4(a_pos, 1.0));
		skinned_normal += weight * (bone_transforms[bone_id] * vec4(a_normal, 0.0));
	}

	gl_Position = projection * view * model * skinned_pos;
	frag_world_pos = vec3(model * skinned_pos);
	normal = mat3(normal_matrix) * vec3(skinned_normal);
	uv = a_uv;
}

@end

@fs fs

in vec3 normal;
in vec3 frag_world_pos;
in vec2 uv;

out vec4 frag_color;

layout (binding=2) uniform Entity_FS_Params {
	vec3 view_pos;
	float fog_start;
	float fog_end;
	vec3 fog_color;
	float shininess;
};

layout (binding=0) uniform texture2D entity_diffuse_texture;
layout (binding=1) uniform texture2D entity_specular_texture;

layout (binding=0) uniform sampler entity_diffuse_sampler;
layout (binding=1) uniform sampler entity_specular_sampler;

// FIXME: aparentemente temos um bug com uma luz presa na camera: mover a camera olhando pra baixo parece mover uma luz. talvez a luz direcional esteja bugada?
#define MAX_LIGHTS 8 
#define LIGHT_DIRECTIONAL 1
#define LIGHT_POINT 2
#define LIGHT_SPOT 3

layout (std140, binding=3) uniform FS_Lights {
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

vec3 calculate_directional_light(Light light) {
	return calculate_phong_lighting(light, 1.0, -light.direction);
}

vec3 calculate_point_light(Light light) {
	float dist = length(light.position - frag_world_pos);
	float attenuation = get_attenuation(light, dist);
	return calculate_phong_lighting(light, attenuation, light.position - frag_world_pos);
}

vec3 calculate_spot_light(Light light) {
	vec3 light_to_frag = frag_world_pos - light.position;
	float dist = length(light_to_frag);
	vec3 light_dir = normalize(light_to_frag);

	float theta = dot(light_dir, normalize(light.direction));
	float cutoff_cos = cos(light.cutoff);
	float outer_cutoff_cos = cos(light.outer_cutoff);
	float intensity = clamp((theta - outer_cutoff_cos) / (cutoff_cos - outer_cutoff_cos), 0.0, 1.0);

	float attenuation = get_attenuation(light, dist);
	return calculate_phong_lighting(light, attenuation, light.position - frag_world_pos) * intensity;
}

float calculate_linear_fog_factor() {
	float dist_from_center = length(frag_world_pos.xz);
	float fog_range = fog_end - fog_start;
	float fog_factor = (fog_end - dist_from_center) / fog_range;
	return clamp(fog_factor, 0.0, 1.0);
}

float calculate_fog_factor() {
	float fog_factor = calculate_linear_fog_factor();

	return fog_factor;
}

vec3 apply_fog(vec3 frag_color, vec3 fog_color) {
	if(fog_color == vec3(0)) {
		return frag_color;
	}

	float fog_factor = calculate_fog_factor();

	return mix(fog_color, frag_color, fog_factor);
}

void main() {
	vec3 result = vec3(0.0);
	for (int i = 0; i < fs_lights.light_count; i++) {
		Light light = get_light(i);
		if (light.kind == LIGHT_DIRECTIONAL) {
			result += calculate_directional_light(light);
		} else if (light.kind == LIGHT_POINT) {
			result += calculate_point_light(light);
		} else if (light.kind == LIGHT_SPOT) {
			result += calculate_spot_light(light);
		}
	}

	result = apply_fog(result, fog_color);

	frag_color = vec4(result, 1.0);
}

@end

@program entity vs fs
