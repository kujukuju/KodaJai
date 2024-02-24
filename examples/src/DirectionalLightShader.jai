DirectionalLightShader :: struct {
    using #as shader: Shader;

    shader.vertex = DIRECTIONAL_LIGHT_VERTEX_SHADER;
    shader.fragment = DIRECTIONAL_LIGHT_FRAGMENT_SHADER;
}

#scope_module

DIRECTIONAL_LIGHT_VERTEX_SHADER :: #string ___glsl
#version 400 core

layout (location = 0) in vec2 aPos;

uniform mat4 view;

uniform mat4 uShadowView;

out vec2 vCoord;
out vec3 vCamera;
out vec3 vShadowDir;

void main() {
    vCoord = aPos * vec2(0.5, 0.5) + 0.5;
    vCamera = vec3(inverse(view) * vec4(0.0, 0.0, 0.0, 1.0));
    // don't think I need to normalize
    vShadowDir = normalize(vec3(inverse(uShadowView) * vec4(0.0, 0.0, -1.0, 0.0)));

    gl_Position = vec4(aPos, 0.0, 1.0);
}
___glsl

DIRECTIONAL_LIGHT_FRAGMENT_SHADER :: #string ___glsl
#version 400 core

layout (location = 0) out vec4 FragColor;

uniform sampler2D uPosition;
uniform sampler2D uDiffuse;
uniform sampler2D uNormal;
uniform sampler2D uSSAO;
uniform sampler2DShadow uShadow;
uniform sampler2DShadow uCascShadow;

uniform vec2 uScreenSize;

uniform vec3 uLightDirection;
uniform float uLightConstant;
uniform float uLightLinear;
uniform float uLightExp;

uniform mat4 uShadowView;
uniform mat4 uShadowProjection;
uniform mat4 uCascShadowView;
uniform mat4 uCascShadowProjection;

uniform float uSpecularPower;
uniform float uDiffuseIntensity;
uniform float uAmbientIntensity;

in vec2 vCoord;
in vec3 vCamera;
in vec3 vShadowDir;

vec4 calcLightInternal(vec3 baseColor, float ambientIntensity, float diffuseIntensity, vec3 direction, vec3 position, vec3 normal) {
    vec4 ambientColor = vec4(baseColor * ambientIntensity, 1.0);
    float diffuseFactor = dot(normal, -direction) * 0.7 + 0.3;

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

    return calcLightInternal(baseColor, uAmbientIntensity, uDiffuseIntensity, uLightDirection, position, normal);
}

float calcCascShadowFactor(vec3 position, vec3 normal) {
    vec4 shadowViewSpace = uCascShadowView * vec4(position, 1.0);
    vec4 shadowSpace = uCascShadowProjection * shadowViewSpace;

    vec3 shadowCoord = shadowSpace.xyz / shadowSpace.w;
    shadowCoord = shadowCoord * 0.5 + 0.5;

    if (shadowCoord.x < 0 || shadowCoord.y < 0 || shadowCoord.z < 0 || shadowCoord.x > 1 || shadowCoord.y > 1 || shadowCoord.z > 1) {
        return 1.0;
    }

    vec2 shadowSize = textureSize(uCascShadow, 0);
    float biasScale = shadowSize.x / 2.0 + shadowSize.y / 2.0;
    biasScale = 4096.0 / biasScale;

    const float minBias = 0.0004;
    const float maxBias = 0.02;
    const float PI = 3.141592653589793;

    float biasStrength = 1.0 - abs(dot(vShadowDir, normal));
    biasStrength = 1.0 / cos(biasStrength * PI * 1.0 / 3.0) - 1.0;
    biasStrength = pow(biasStrength, 2.0);

    float bias = (maxBias - minBias) * biasStrength + minBias;
    bias *= biasScale;

    return texture(uCascShadow, vec3(shadowCoord.xy, shadowCoord.z - bias));
}

float calcShadowFactor(vec3 position, vec3 normal) {
    vec4 shadowViewSpace = uShadowView * vec4(position, 1.0);
    vec4 shadowSpace = uShadowProjection * shadowViewSpace;

    vec3 shadowCoord = shadowSpace.xyz / shadowSpace.w;
    shadowCoord = shadowCoord * 0.5 + 0.5;

    if (shadowCoord.x < 0 || shadowCoord.y < 0 || shadowCoord.z < 0 || shadowCoord.x > 1 || shadowCoord.y > 1 || shadowCoord.z > 1) {
        return calcCascShadowFactor(position, normal);
        // return 1.0;
    }

    vec2 shadowSize = textureSize(uShadow, 0);
    float biasScale = shadowSize.x / 2.0 + shadowSize.y / 2.0;
    biasScale = 4096.0 / biasScale;

    const float minBias = 0.0004;
    const float maxBias = 0.02;
    const float PI = 3.141592653589793;

    float biasStrength = 1.0 - abs(dot(vShadowDir, normal));
    biasStrength = 1.0 / cos(biasStrength * PI * 1.0 / 3.0) - 1.0;
    biasStrength = pow(biasStrength, 2.0);

    float bias = (maxBias - minBias) * biasStrength + minBias;
    bias *= biasScale;

    return texture(uShadow, vec3(shadowCoord.xy, shadowCoord.z - bias));
}

void main() {
    vec2 coord = vCoord;

	vec3 position = texture(uPosition, coord).xyz;
	vec3 diffuse = texture(uDiffuse, coord).xyz;
	vec3 normal = texture(uNormal, coord).xyz;

    float ssao = texture(uSSAO, coord).r;

    float shadowFactor = calcShadowFactor(position, normal) * 0.5 + 0.5;

    FragColor = vec4(diffuse, 1.0) * calculateLight(position, normal) * 1.5 * ssao * shadowFactor;
}
___glsl