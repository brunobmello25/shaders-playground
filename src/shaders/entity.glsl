@header package shaders;
@header import sg "../../sokol/gfx";

@ctype mat4 Mat4

@vs vs

in vec3 aPos;
in vec3 aNormal;
in vec2 aUv;

out vec3 normal;
out vec3 fragWorldPos;
out vec2 uv;

layout (binding=0) uniform Entity_VS_Params {
	mat4 model;
	mat4 view;
	mat4 projection;
	mat4 normalMatrix;
};

void main () {
	gl_Position = projection * view * model * vec4(aPos, 1.0);
	fragWorldPos = vec3(model * vec4(aPos, 1.0));
	normal = mat3(normalMatrix) * aNormal;
	uv = aUv;
}

@end

@fs fs

in vec3 normal;
in vec3 fragWorldPos;
in vec2 uv;

out vec4 fragColor;

layout (binding=1) uniform Entity_FS_Params {
	vec3 viewPos;
};

layout (binding=2) uniform Entity_FS_Material {
	float shininess;
} material;

layout (binding=3) uniform Entity_FS_Light {
	vec3 position;

	vec3 ambient;
	vec3 diffuse;
	vec3 specular;
} light;

layout (binding=4) uniform texture2D entity_diffuse_texture;
layout (binding=5) uniform sampler entity_diffuse_sampler;

layout (binding=6) uniform texture2D entity_specular_texture;
layout (binding=7) uniform sampler entity_specular_sampler;

void main () {

	// ambient
	vec3 ambient = light.ambient * vec3(texture(sampler2D(entity_diffuse_texture, entity_diffuse_sampler), uv));

	// diffuse
	vec3 norm = normalize(normal);
	vec3 lightDir = normalize(light.position - fragWorldPos);
	float diff = max(dot(norm, lightDir), 0.0);
	vec3 diffuse = light.diffuse * diff * vec3(texture(sampler2D(entity_diffuse_texture, entity_diffuse_sampler), uv));

	// specular
	vec3 viewDir = normalize(viewPos - fragWorldPos);
	vec3 reflectDir = reflect(-lightDir, norm);
	float spec = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);
	vec3 specular = light.specular * spec * vec3(texture(sampler2D(entity_specular_texture, entity_specular_sampler), uv));

	vec3 result = ambient + diffuse + specular;

	fragColor = vec4(result, 1.0);
}

@end

@program entity vs fs
