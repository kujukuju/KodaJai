
EdgeShader :: struct {
    using #as shader: Shader;

    shader.name = "EdgeShader";
    shader.vertex = EDGE_VERTEX_SHADER;
    shader.fragment = EDGE_FRAGMENT_SHADER;
}

edge_shader: EdgeShader;

#scope_module

EDGE_VERTEX_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) in vec2 aPos;

uniform mat4 view;
uniform mat4 projection;

out vec2 vCoord;
flat out vec3 vCamera;
flat out mat4 vInverseView;
flat out mat4 vInverseProjection;

void main() {
    vCoord = aPos * vec2(0.5, 0.5) + 0.5;
    vCamera = vec3(inverse(view) * vec4(0.0, 0.0, 0.0, 1.0));
    vInverseView = inverse(view);
    vInverseProjection = inverse(projection);

    gl_Position = vec4(aPos, 0.0, 1.0);
}
___glsl

EDGE_FRAGMENT_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) out vec4 FragColor;

const float minDepth = 0.0;
const float maxDepth = 10.0;
const float minSeparation = 0.1;
const float maxSeparation = 1.0;
const float minDistance = 0.05;
const float maxDistance = 0.5;
const vec2[8] offsets = vec2[8](vec2(-1, -1), vec2(0, -1), vec2(1, -1), vec2(1, 0), vec2(-1, 0), vec2(-1, 1), vec2(0, 1), vec2(1, 1));
const vec3 colorModifier = vec3(20.0 / 255.0, 2.0 / 255.0, 4.0 / 255.0);

uniform sampler2D uColor;
uniform sampler2D uDepth;

in vec2 vCoord;
flat in vec3 vCamera;
flat in mat4 vInverseView;
flat in mat4 vInverseProjection;

void main() {
    vec3 color = texture(uColor, vCoord).rgb;
    // TODO view
    vec3 position = reconstructWorldPosition(vCoord, texture(uDepth, vCoord).r, vInverseView, vInverseProjection);

    vec2 depthSize = textureSize(uDepth, 0);

    vec3 fragDepthDelta = position - vCamera;

    float depthSquared = dot(fragDepthDelta, fragDepthDelta);
    float depth = sqrt(depthSquared);

    float separation = smoothstep(minDepth, maxDepth, depth);
    separation = (minSeparation - maxSeparation) * separation + maxSeparation;

    float maxDepthDifference = 0.0;
    for (int i = 0; i < 8; i++) {
        vec2 offset = offsets[i];
        float offsetLength = length(offset);

        vec2 sampleCoord = vCoord + offset * separation / depthSize;

        // TODO view
        vec3 samplePosition = reconstructWorldPosition(sampleCoord, texture(uDepth, sampleCoord).r, vInverseView, vInverseProjection);

        vec3 depthDelta = samplePosition - position;
        float depthDistanceSquared = dot(depthDelta, depthDelta);

        maxDepthDifference = max(maxDepthDifference, depthDistanceSquared);
    }

    vec3 lineColor = color * colorModifier;

    float scaledMinDistance = sqrt(depth * 0.1) * minDistance;
    float scaledMaxDistance = sqrt(depth * 0.1) * maxDistance;

    float diff = smoothstep(scaledMinDistance, scaledMaxDistance, sqrt(maxDepthDifference));
    diff = step(0.0001, diff) * (diff * 0.5 + 0.5);

    vec3 finalColor = color * (1.0 - diff) + lineColor * diff;

    FragColor = vec4(finalColor, 1.0);
    // FragColor = vec4(color, 1.0);
}
___glsl