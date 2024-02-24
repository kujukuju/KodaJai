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
    vShadowDir = normalize(vec3(inverse(view) * vec4(0.0, 0.0, -1.0, 0.0)));

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
uniform sampler2D uShadow;
// uniform sampler2DShadow uShadow;

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
in vec3 vShadowDir;

vec4 calcLightInternal(vec3 baseColor, float ambientIntensity, float diffuseIntensity, vec3 direction, vec3 position, vec3 normal) {
    vec4 ambientColor = vec4(baseColor * ambientIntensity, 1.0);
    float diffuseFactor = dot(normal, -direction) * 0.7 + 0.3;

    vec4 diffuseColor = vec4(0, 0, 0, 0);
    vec4 specularColor = vec4(0, 0, 0, 0);

    if (diffuseFactor > 0.0) {
        diffuseColor = vec4(baseColor * diffuseIntensity * diffuseFactor, 1.0);

        vec3 vertexToEye = normalize(vCamera - position);

        // float rimLightIntensity = dot(vertexToEye, normal);
        // rimLightIntensity = 1.0 - rimLightIntensity;
        // rimLightIntensity = max(0.0, rimLightIntensity);
        // rimLightIntensity = pow(rimLightIntensity, 2.0);
        // rimLightIntensity = smoothstep(0.3, 0.4, rimLightIntensity);
        // diffuseColor.rgb += rimLightIntensity * baseColor;

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

float calcShadowFactor(vec3 position, vec3 normal) {
    vec4 shadowViewSpace = uShadowView * vec4(position, 1.0);
    vec4 shadowSpace = uShadowProjection * shadowViewSpace;

    vec3 shadowCoord = shadowSpace.xyz / shadowSpace.w;
    shadowCoord = shadowCoord * 0.5 + 0.5;

    if (shadowCoord.x < 0.0 || shadowCoord.y < 0.0 || shadowCoord.x > 1.0 || shadowCoord.y > 1.0) {
        return 1.0;
    }

    const float minBias = 0.0002;
    const float maxBias = 0.01;
    const float halfPI = 1.5707963267948966;

    float biasStrength = 1.0 - abs(dot(vShadowDir, normal));
    biasStrength = 1.0 / cos(biasStrength * halfPI * 1.0 / 3.0) - 1.0;
    // biasStrength = pow(biasStrength, 2.0);

    float bias = (maxBias - minBias) * biasStrength + minBias;

    // return texture(uShadow, vec3(shadowCoord.xy, shadowCoord.z - bias));

    float shadowDepth = texture(uShadow, shadowCoord.xy).r;

    return smoothstep(shadowCoord.z - bias * 2.0, shadowCoord.z - bias, shadowDepth);
    // if (shadowDepth < shadowCoord.z - bias) {
    //     return 0.2;
    // }

    // return 1.0;
}

float gaussian(float x, float range) {
    return exp(-x / range);
}

// can't really use textureGather because the shadow map doesn't correspond 1:1 with the actual scene fragmetns
float calcShadowFactorExpand(vec3 position, vec3 normal) {
    vec2 shadowMapSize = textureSize(uShadow, 0);
    vec2 positionSize = textureSize(uPosition, 0);

    vec4 shadowViewSpace = uShadowView * vec4(position, 1.0);
    vec4 shadowSpace = uShadowProjection * shadowViewSpace;

    vec3 shadowCoord = shadowSpace.xyz / shadowSpace.w;
    shadowCoord = shadowCoord * 0.5 + 0.5;

    if (shadowCoord.x < 0.0 || shadowCoord.y < 0.0 || shadowCoord.x > 1.0 || shadowCoord.y > 1.0) {
        return 1.0;
    }

    const float minBias = 0.0004;
    const float maxBias = 0.01;
    const float halfPI = 1.5707963267948966;

    float biasStrength = 1.0 - abs(dot(vShadowDir, normal));
    biasStrength = 1.0 / cos(biasStrength * halfPI * 1.0 / 3.0) - 1.0;

    float bias = (maxBias - minBias) * biasStrength + minBias;

    float positionDepth = shadowCoord.z;
    // vec2 depthDelta = vec2(dFdx(positionDepth), -dFdy(positionDepth));

    vec3 positionDeltaX = dFdx(position);
    vec3 positionDeltaY = dFdy(position);
    float positionDeltaLength = sqrt(dot(positionDeltaX, positionDeltaX) + dot(positionDeltaY, positionDeltaY));

    float offsetScale = 4.0 / (positionDeltaLength * 100.0);
    
    // const float maxBlurDepth = 0.002;
    // const float minBlurDepth = 0.0002;
    // const float maxBlur = 2.0;
    // const float minBlur = 0.0;

    // float shadowDepth = texture(uShadow, shadowCoord.xy).r;
    // float depthDifference = shadowCoord.z - shadowDepth;
    // float blur = smoothstep(minBlurDepth, maxBlurDepth, depthDifference);
    // blur = blur * (maxBlur - minBlur) + minBlur;

    const float maxBlurDepth = 0.04;
    const float minBlurDepth = 0.0002;
    const float maxBlurGaussian = 8.0;
    const float minBlurGaussian = 0.1;

    // float shadowAverage = 0.0;
    // float maximumDepthDifference = 0.0;
    // float averageDepthDifference = 0.0;
    float totalDepthDifference = 0.0;
    float countDepthDifference = 0.0;
    float depthDifferences[25];
    int depthIndex = 0;
    for (int y = -2; y <= 2; y++) {
        for (int x = -2; x <= 2; x++) {
            vec2 offset = vec2(float(x), float(y)) / positionSize * offsetScale;
            vec3 depthPosition = texture(uPosition, vCoord + offset).xyz;
            vec4 depthSpace = uShadowProjection * uShadowView * vec4(depthPosition, 1.0);
            vec3 depthCoord = depthSpace.xyz / depthSpace.w;
            depthCoord = depthCoord * 0.5 + 0.5;

            float fragmentShadowDepth = texture(uShadow, depthCoord.xy).r;
            float depthDifference = depthCoord.z - bias - fragmentShadowDepth;

            // maximumDepthDifference = max(maximumDepthDifference, depthDifference);
            // averageDepthDifference += max(depthDifference, 0.0) / 25.0;
            if (depthDifference > 0.0) {
                totalDepthDifference += smoothstep(minBlurDepth, maxBlurDepth, depthDifference);
                // totalDepthDifference += clamp(depthDifference / maxBlurDepth, 0.0, 1.0);
            } else {
                totalDepthDifference += 1.0;
            }
            countDepthDifference += 1.0;

            depthDifferences[depthIndex] = depthDifference;
            depthIndex++;

            // shadowAverage += step(depthDifference, 0.0) / 25.0;
        }
    }

    countDepthDifference = max(countDepthDifference, 1.0);
    float averageDepthDifference = totalDepthDifference / countDepthDifference;

    // float blurGaussian = smoothstep(minBlurDepth, maxBlurDepth, maximumDepthDifference);
    // float blurGaussian = smoothstep(minBlurDepth, maxBlurDepth, averageDepthDifference);
    float blurGaussian = averageDepthDifference;
    // blurGaussian = (maxBlurGaussian - minBlurGaussian) * blurGaussian + minBlurGaussian;

    float shadowAverage = 0.0;
    float shadowWeight = 0.0;
    depthIndex = 0;
    for (int y = -2; y <= 2; y++) {
        float strengthY = gaussian(abs(float(y)), blurGaussian);

        for (int x = -2; x <= 2; x++) {
            float strengthX = gaussian(abs(float(x)), blurGaussian);
            float weight = strengthX * strengthY;

            float depthDifference = depthDifferences[depthIndex];
            depthIndex++;

            shadowAverage += step(depthDifference, 0.0) * weight;
            shadowWeight += weight;
        }
    }

    return blurGaussian;
    // return shadowAverage / shadowWeight;

    // float shadowSum = 0.0;
    // float shadowCount = 0.0;
    // for (int y = -1; y <= 1; y += 2) {
    //     for (int x = -1; x <= 1; x += 2) {
    //         vec2 offset = vec2(float(x), float(y)) * 0.5;
    //         // vec4 shadowDepths = textureGather(uShadow, shadowCoord.xy + offset / shadowMapSize);

    //         vec4 positionDepths = vec4(
    //             positionDepth + depthDelta.x * (offset.x - 0.5) + depthDelta.y * (offset.y - 0.5), // top left
    //             positionDepth + depthDelta.x * (offset.x + 0.5) + depthDelta.y * (offset.y - 0.5), // top right
    //             positionDepth + depthDelta.x * (offset.x - 0.5) + depthDelta.y * (offset.y + 0.5), // bottom left
    //             positionDepth + depthDelta.x * (offset.x + 0.5) + depthDelta.y * (offset.y + 0.5) // bottom right
    //         );

    //         shadowSum += smoothstep(positionDepths.x - bias * 2.0, positionDepths.x - bias, shadowDepths.x);
    //         shadowSum += smoothstep(positionDepths.y - bias * 2.0, positionDepths.y - bias, shadowDepths.y);
    //         shadowSum += smoothstep(positionDepths.z - bias * 2.0, positionDepths.z - bias, shadowDepths.z);
    //         shadowSum += smoothstep(positionDepths.w - bias * 2.0, positionDepths.w - bias, shadowDepths.w);
    //         shadowCount += 4.0;
    //     }
    // }

    // float shadowValue = shadowSum / shadowCount;
    // return shadowValue;
    
    // return texture(uShadow, vec3(shadowCoord.xy, positionDepth - bias));

    // float shadowDepth = texture(uShadow, shadowCoord.xy).r;

    // return smoothstep(positionDepth - bias * 2.0, positionDepth - bias, shadowDepth);
    // if (shadowDepth < positionDepth - bias) {
    //     return 0.2;
    // }

    // return 1.0;
}

void main() {
    vec2 coord = vCoord;

	vec3 position = texture(uPosition, coord).xyz;
	vec3 diffuse = texture(uDiffuse, coord).xyz;
	vec3 normal = texture(uNormal, coord).xyz;

    float ssao = texture(uSSAO, coord).r;

    float shadowFactor = calcShadowFactorExpand(position, normal);

    // vec3 positionDeltaX = dFdx(position);
    // vec3 positionDeltaY = dFdy(position);
    // float positionDeltaLength = sqrt(dot(positionDeltaX, positionDeltaX) + dot(positionDeltaY, positionDeltaY));

    // FragColor = vec4(vec3(shadowFactor), 1.0);
    // FragColor = vec4(vec3(ssao), 1.0);
    FragColor = vec4(diffuse, 1.0) * calculateLight(position, normal) * 1.5 * ssao;

    // FragColor = vec4(diffuse, 1.0) * calculateLight(position, normal) * 1.5 * ssao * shadowFactor;
}
___glsl