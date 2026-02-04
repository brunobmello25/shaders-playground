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

layout (binding=0) uniform CubeVSParams {
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

layout (binding=1) uniform CubeFSParams {
	vec3 viewPos;
};

layout (binding=2) uniform CubeFSMaterial {
	vec3 specular;
	float shininess;
} material;

layout (binding=3) uniform CubeFSLight {
	vec3 position;

	vec3 ambient;
	vec3 diffuse;
	vec3 specular;
} light;

layout (binding=4) uniform texture2D cubeDiffuseTexture;
layout (binding=5) uniform sampler cubeDiffuseSampler;

void main () {

	// ambient
	vec3 ambient = light.ambient;

	// diffuse
	vec3 norm = normalize(normal);
	vec3 lightDir = normalize(light.position - fragWorldPos);
	float diff = max(dot(norm, lightDir), 0.0);
	vec3 diffuse = light.diffuse * diff * vec3(texture(sampler2D(cubeDiffuseTexture, cubeDiffuseSampler), uv));

	// specular
	vec3 viewDir = normalize(viewPos - fragWorldPos);
	vec3 reflectDir = reflect(-lightDir, norm);
	float spec = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);
	vec3 specular = light.specular * (spec * material.specular);

	vec3 result = ambient + diffuse + specular;

	fragColor = vec4(result, 1.0);
}

@end

@program cube vs fs
