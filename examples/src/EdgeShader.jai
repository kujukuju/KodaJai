
EdgeShader :: struct {
    using #as shader: Shader;

    shader.vertex = EDGE_VERTEX_SHADER;
    shader.fragment = EDGE_FRAGMENT_SHADER;
}

#scope_module

EDGE_VERTEX_SHADER :: #string ___glsl
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

EDGE_FRAGMENT_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) out vec4 FragColor;

const float minSeparation = 0.2;
const float maxSeparation = 1.0;
const float minDistance = 0.1;
const float maxDistance = 0.5;
const int size = 1;
const vec3 colorModifier = vec3(0.224, 0.063, 0.099);

uniform sampler2D uColor;
uniform sampler2D uPosition;
uniform sampler2D uDepth;

in vec2 vCoord;
in vec3 vCamera;

void main() {
    vec3 color = texture(uColor, vCoord).rgb;
    vec3 position = texture(uPosition, vCoord).rgb;

    vec2 positionSize = textureSize(uPosition, 0);

    float depth = distance(vCamera, position);
    float separation = mix(maxSeparation, minSeparation, depth / 100.0);

    float mx = 0.0;
    for (int y = -size; y <= size; y++) {
        for (int x = -size; x <= size; x++) {
            vec2 sampleCoord = vCoord + vec2(float(x), float(y)) * separation / positionSize;

            vec3 samplePosition = texture(uPosition, sampleCoord).rgb;

            mx = max(mx, distance(position, samplePosition));
        }
    }

    vec3 lineColor = color * colorModifier;

    float diff = smoothstep(minDistance, maxDistance, mx);

    vec3 finalColor = color * (1.0 - diff) + lineColor * diff;

    FragColor = vec4(finalColor, 1.0);
}
___glsl