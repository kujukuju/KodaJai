
gaussian_directional_blur_shader := #run create_shader(GAUSSIAN_DIRECTIONAL_BLUR_VERTEX_SHADER, GAUSSIAN_DIRECTIONAL_BLUR_FRAGMENT_SHADER);

#scope_module

GAUSSIAN_DIRECTIONAL_BLUR_VERTEX_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) in vec2 aPos;

out vec2 vCoord;

void main() {
    vCoord = aPos * vec2(0.5, 0.5) + 0.5;

    gl_Position = vec4(aPos, 0.0, 1.0);
}
___glsl

GAUSSIAN_DIRECTIONAL_BLUR_FRAGMENT_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) out vec4 FragColor;

// use this to generate new values
// https://lisyarus.github.io/blog/graphics/2023/02/24/blur-coefficients-generator.html
const int SAMPLE_COUNT = 8;

const float OFFSETS[8] = float[8](
    -6.168999895680605,
    -4.2493201357512165,
    -2.351564403533789,
    -0.46943377969837197,
    1.4091998770852123,
    3.2979348079914823,
    5.206290077682596,
    7
);

const float WEIGHTS[8] = float[8](
    0.0028918856621288915,
    0.03708585635306172,
    0.18660117722359726,
    0.3721448146065306,
    0.29569619257017404,
    0.09344193718198306,
    0.011649408027304327,
    0.00048872837522002
);

uniform sampler2D uTexture;

// should probably be either vec2(radius, 0) or vec2(0, radius)
uniform vec2 uDirection;
uniform float uStrength = 1.0;
uniform float uSaturation = 1.0;
uniform float uAlpha = 1.0;

in vec2 vCoord;

vec4 blur(sampler2D sample, vec2 uv, vec2 direction) {
    vec4 result = vec4(0.0);
    vec2 size = textureSize(sample, 0);
    for (int i = 0; i < SAMPLE_COUNT; i++) {
        vec2 offset = direction * OFFSETS[i] / size * uStrength;
        float weight = WEIGHTS[i];
        result += texture(sample, uv + offset) * weight;
    }
    return result;
}

void main() {
    vec4 color = blur(uTexture, vCoord, uDirection);

    float gray = color.r / 3.0 + color.g / 3.0 + color.b / 3.0;
    color.r = color.r * uSaturation + gray * (1.0 - uSaturation);
    color.g = color.g * uSaturation + gray * (1.0 - uSaturation);
    color.b = color.b * uSaturation + gray * (1.0 - uSaturation);

    FragColor = vec4(color.rgb, color.a * uAlpha);
}
___glsl