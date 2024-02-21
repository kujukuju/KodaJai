
// fast adaptive anti aliasing
FAAAShader :: struct {
    using #as shader: Shader;

    shader.vertex = FAAA_VERTEX_SHADER;
    shader.fragment = FAAA_FRAGMENT_SHADER;
}

#scope_module

FAAA_VERTEX_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) in vec2 aPos;

uniform mat4 view;

// pos -> vNdc

out vec2 vCoord;
out vec3 vCamera;
out vec3 vCameraForward;
out vec2 vNdc;

void main() {
    vCoord = aPos * vec2(0.5, 0.5) + 0.5;
    vCamera = vec3(inverse(view) * vec4(0.0, 0.0, 0.0, 1.0));
    vCameraForward = vec3(inverse(view) * vec4(0.0, 0.0, -1.0, 0.0));
    vNdc = aPos; // TODO might need to flip y?

    gl_Position = vec4(aPos, 0.0, 1.0);
}
___glsl

FAAA_FRAGMENT_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) out vec4 FragColor;

const float edgeThreshold = (10.0 - FXAA_EDGE_THRESHOLD) * 0.0625;

uniform mat4 view;
uniform mat4 projection;

uniform sampler2D uColor;
uniform sampler2D uPosition;
uniform sampler2D uNormal;
uniform sampler2D uDepth;

in vec2 vCoord;
in vec3 vCamera;
in vec3 vCameraForward;
in vec2 vNdc;

void main() {
    vec2 bufferSize = textureSize(uColor, 0);

    vec2 pixelSize = 1.0 / bufferSize;

    FragColor = texture(uColor, vCoord).rgba;
}
___glsl