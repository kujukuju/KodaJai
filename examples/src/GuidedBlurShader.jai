GuidedBlurShader :: struct {
    using #as shader: Shader;

    shader.vertex = GUIDED_BLUR_VERTEX_SHADER;
    shader.fragment = GUIDED_BLUR_FRAGMENT_SHADER;
}

#scope_module

GUIDED_BLUR_VERTEX_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) in vec2 aPos;

uniform mat4 view;

out vec2 vCoord;
out vec3 vCamera;
out vec3 vCameraForward;

void main() {
    vCoord = aPos * vec2(0.5, 0.5) + 0.5;
    vCamera = vec3(inverse(view) * vec4(0.0, 0.0, 0.0, 1.0));
    vCameraForward = vec3(inverse(view) * vec4(0.0, 0.0, -1.0, 0.0));

    gl_Position = vec4(aPos, 0.0, 1.0);
}
___glsl

GUIDED_BLUR_FRAGMENT_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) out vec4 FragColor;

const float OFFSETS[4] = float[](-1.5, -0.5, 0.5, 1.5);

uniform mat4 view;
uniform mat4 projection;

uniform sampler2D uPosition;
uniform sampler2D uNormal;
uniform sampler2D uSsao;

in vec2 vCoord;
in vec3 vCamera;
in vec3 vCameraForward;

void main() {
    float blurred = 0.0;
    for (int i = 0 ; i < 4 ; i++) {
        for (int j = 0 ; j < 4 ; j++) {
            vec2 tc = vCoord;
            tc.x += OFFSETS[j] / textureSize(uSsao, 0).x;
            tc.y += OFFSETS[i] / textureSize(uSsao, 0).y;
            blurred += texture(uSsao, tc).r;
        }
    }
    
    blurred /= 4.0 * 4.0;
    FragColor = vec4(vec3(blurred), 1.0);
}
___glsl