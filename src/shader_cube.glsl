@header package main;
@header import sg "../sokol/gfx";

@ctype mat4 Mat4

@vs vs

in vec3 aPos;
in vec3 aNormal;

out vec3 normal;
out vec3 fragWorldPos;

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
}

@end

@fs fs

in vec3 normal;
in vec3 fragWorldPos;

out vec4 fragColor;

layout (binding=1) uniform CubeFSParams {
	vec3 cubeColor;
	vec3 lightColor;
	vec3 lightPos;
	vec3 viewPos;
};

void main () {

	// ambient
	float ambientStrength = 0.1;
	vec3 ambient = ambientStrength * lightColor;

	// diffuse
	vec3 norm = normalize(normal);
	vec3 lightDir = normalize(lightPos - fragWorldPos);
	float diff = max(dot(norm, lightDir), 0.0);
	vec3 diffuse = diff * lightColor;

	// specular
	float specularIntensity = 0.5;
	vec3 viewDir = normalize(viewPos - fragWorldPos);
	vec3 reflectDir = reflect(-lightDir, norm);
	float spec = pow(max(dot(viewDir, reflectDir), 0.0), 256);
	vec3 specular = specularIntensity * spec * lightColor;

	vec3 result = (ambient + diffuse + specular) * cubeColor;

	fragColor = vec4(result, 1.0);
}

@end

@program cube vs fs
