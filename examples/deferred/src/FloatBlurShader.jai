
FloatBlurShader :: struct {
    using #as shader: Shader;

    shader.name = "FloatBlurShader";
    shader.vertex = FLOAT_BLUR_VERTEX_SHADER;
    shader.fragment = FLOAT_BLUR_FRAGMENT_SHADER;
}

float_blur_shader: FloatBlurShader;

#scope_module

FLOAT_BLUR_VERTEX_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) in vec2 aPos;

out vec2 vCoord;

void main() {
    vCoord = aPos * vec2(0.5, 0.5) + 0.5;

    gl_Position = vec4(aPos, 0.0, 1.0);
}
___glsl

FLOAT_BLUR_FRAGMENT_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) out float FragColor;

uniform sampler2D uBlur;

in vec2 vCoord;

void main() {
    vec2 pixelSize = 1.0 / textureSize(uBlur, 0);

    float sum = 0.0;
    for (int y = -2; y <= 2; y++) {
        for (int x = -2; x <= 2; x++) {
            vec2 offset = vec2(float(x), float(y)) * pixelSize * 0.5;

            sum += texture(uBlur, vCoord + offset).r;
        }
    }
    sum /= 25.0;

    FragColor = sum;
}
___glsl;