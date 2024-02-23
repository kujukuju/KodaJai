DirectionalLightShader :: struct {
    using #as shader: Shader;

    shader.vertex = DIRECTIONAL_LIGHT_VERTEX_SHADER;
    shader.fragment = DIRECTIONAL_LIGHT_FRAGMENT_SHADER;
}

#scope_module

DIRECTIONAL_LIGHT_VERTEX_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) in vec2 aPos;

uniform mat4 view;

out vec2 vCoord;
out vec3 vCamera;

void main() {
    vCoord = aPos * vec2(0.5, 0.5) + 0.5;
    vCamera = vec3(inverse(view) * vec4(0.0, 0.0, 0.0, 1.0));

    gl_Position = vec4(aPos, 0.0, 1.0);
}
___glsl

DIRECTIONAL_LIGHT_FRAGMENT_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) out vec4 FragColor;

uniform sampler2D uPosition;
uniform sampler2D uDiffuse;
uniform sampler2D uNormal;
uniform sampler2D uSSAO;
uniform sampler2DShadow uShadow;
// uniform sampler2D uShadow;

uniform vec2 uScreenSize;

// uniform vec3 uLightPosition;
// uniform float uLightRadius;
uniform vec3 uLightDirection;
uniform float uLightConstant;
uniform float uLightLinear;
uniform float uLightExp;

uniform mat4 uShadowView;
uniform mat4 uShadowProjection;

uniform float uSpecularPower;
uniform float uDiffuseIntensity;
uniform float uAmbientIntensity;

in vec2 vCoord;
in vec3 vCamera;

vec4 calcLightInternal(vec3 baseColor, float ambientIntensity, float diffuseIntensity, vec3 direction, vec3 position, vec3 normal) {
    vec4 ambientColor = vec4(baseColor * ambientIntensity, 1.0);
    float diffuseFactor = dot(normal, -direction);

    vec4 diffuseColor = vec4(0, 0, 0, 0);
    vec4 specularColor = vec4(0, 0, 0, 0);

    if (diffuseFactor > 0.0) {
        diffuseColor = vec4(baseColor * diffuseIntensity * diffuseFactor, 1.0);

        vec3 vertexToEye = normalize(vCamera - position);
        vec3 lightReflect = normalize(reflect(direction, normal));
        float specularFactor = dot(vertexToEye, lightReflect);        
        if (specularFactor > 0.0) {
            specularFactor = pow(specularFactor, uSpecularPower);
            const float matSpecularIntensity = 0.0;
            specularColor = vec4(baseColor * matSpecularIntensity * specularFactor, 1.0);
        }
    }

    return ambientColor + diffuseColor + specularColor;
}

vec4 calculateLight(vec3 position, vec3 normal) {
    const vec3 baseColor = vec3(245.0 / 255.0, 242.0 / 255.0, 213.0 / 255.0);
    // const float ambientIntensity = 0.0;
    // const float diffuseIntensity = 0.2;

    return calcLightInternal(baseColor, uAmbientIntensity, uDiffuseIntensity, uLightDirection, position, normal);
}

float calcShadowFactor(vec3 position) {
    vec4 shadowSpace = uShadowProjection * uShadowView * vec4(position, 1.0);

    vec3 shadowCoord = shadowSpace.xyz / shadowSpace.w;
    shadowCoord = shadowCoord * 0.5 + 0.5;

    if (shadowCoord.x < 0.0 || shadowCoord.y < 0.0 || shadowCoord.x > 1.0 || shadowCoord.y > 1.0) {
        return 1.0;
    }

    const float bias = 0.001;
    return texture(uShadow, vec3(shadowCoord.xy, shadowCoord.z - bias));
    
    // float shadowDepth = texture(uShadow, shadowCoord.xy).r;

    // if (shadowCoord.z > shadowDepth + bias) {
    //     return 0.2;
    // }

    // return 1.0;
}

void main() {
    vec2 coord = vCoord;

	vec3 position = texture(uPosition, coord).xyz;
	vec3 diffuse = texture(uDiffuse, coord).xyz;
	vec3 normal = texture(uNormal, coord).xyz;
	normal = normalize(normal);

    float ssao = texture(uSSAO, coord).r;

    float shadowFactor = calcShadowFactor(position);

    FragColor = vec4(diffuse, 1.0) * calculateLight(position, normal) * 1.5 * ssao * shadowFactor;
}
___glsl