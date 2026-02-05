@header package shaders

@block LightUniform
layout (binding=2) uniform FS_Light {
	vec3 position;
	vec3 ambient;
	vec3 diffuse;
	vec3 specular;
} light;
@end
