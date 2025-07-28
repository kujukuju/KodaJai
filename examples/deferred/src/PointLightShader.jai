
point_light_shader := #run create_shader(POINT_LIGHT_VERTEX_SHADER, POINT_LIGHT_FRAGMENT_SHADER);

#scope_module

POINT_LIGHT_VERTEX_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) in vec3 aPos;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

out vec3 vCamera;
out vec3 vLightPosition;
out float vLightRadius;

void main() {
    vCamera = vec3(inverse(view) * vec4(0.0, 0.0, 0.0, 1.0));
    vLightPosition = vec3(model * vec4(0.0, 0.0, 0.0, 1.0));
    vLightRadius =  length(vec3(model * vec4(1.0, 0.0, 0.0, 0.0))); // length(vec3(model[0][0], model[1][0], model[2][0]));

    gl_Position = projection * view * model * vec4(aPos, 1.0);
}
___glsl

POINT_LIGHT_FRAGMENT_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) out vec4 FragColor;

uniform sampler2D uPosition;
uniform sampler2D uDiffuse;
uniform sampler2D uNormal;

uniform vec2 uScreenSize;

// uniform vec3 uLightPosition;
// uniform float uLightRadius;
uniform float uLightConstant;
uniform float uLightLinear;
uniform float uLightExp;

uniform float uSpecularPower;
uniform float uDiffuseIntensity;
uniform float uAmbientIntensity;

in vec3 vCamera;
in vec3 vLightPosition;
in vec3 vLightRadius;

vec4 calcLightInternal(vec3 baseColor, float ambientIntensity, float diffuseIntensity, vec3 direction, vec3 position, vec3 normal) {
    vec4 ambientColor = vec4(baseColor * ambientIntensity, 1.0);
    float diffuseFactor = dot(normal, -direction);

    vec4 diffuseColor = vec4(0, 0, 0, 0);
    vec4 specularColor = vec4(0, 0, 0, 0);

    if (diffuseFactor > 0.0) {
        diffuseColor = vec4(baseColor * diffuseIntensity * diffuseFactor, 1.0);

        // vec3 vertexToEye = normalize(vCamera - position);
        // vec3 lightReflect = normalize(reflect(direction, normal));
        // float specularFactor = dot(vertexToEye, lightReflect);
        // if (specularFactor > 0.0) {
        //     specularFactor = pow(specularFactor, uSpecularPower);
        //     const float matSpecularIntensity = 0.0;
        //     specularColor = vec4(baseColor * matSpecularIntensity * specularFactor, 1.0);
        // }
    }

    return ambientColor + diffuseColor + specularColor;
}

vec4 calculateLight(vec3 position, vec3 normal) {
    vec3 direction = position - vLightPosition;
    float distance = length(direction);
    direction = normalize(direction);

    const vec3 baseColor = vec3(245.0 / 255.0, 242.0 / 255.0, 213.0 / 255.0);

    vec4 color = calcLightInternal(baseColor, uAmbientIntensity, uDiffuseIntensity, direction, position, normal);

    float attenuationFactor = uLightConstant + uLightLinear * distance + uLightExp * distance * distance;
    attenuationFactor = max(1.0, attenuationFactor);

    return color / attenuationFactor;
}

void main() {
    vec2 coord = gl_FragCoord.xy / uScreenSize;

	vec3 position = texture(uPosition, coord).xyz;
	vec3 diffuse = texture(uDiffuse, coord).xyz;
	vec3 rawNormal = texture(uNormal, coord);
	vec3 normal = normalize(rawNormal.xyz * 2.0 - 1.0);

    FragColor = vec4(diffuse, 1.0) * calculateLight(position, normal);
    // FragColor = vec4(1.0);
}
___glsl