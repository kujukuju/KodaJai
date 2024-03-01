
FontParticleShader :: struct {
    using #as shader: Shader;

    shader.vertex = FONT_PARTICLE_VERTEX_SHADER;
    shader.fragment = FONT_PARTICLE_FRAGMENT_SHADER;
}

font_particle_shader: FontParticleShader;

#scope_module

FONT_PARTICLE_VERTEX_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aParticlePosition;
layout (location = 2) in vec2 aParticleSize;
layout (location = 3) in vec2 aParticleTexSize;
layout (location = 4) in float aParticleIndex;

out vec2 vTexCoord;
flat out float vIndex;
flat out vec2 vTexSize;

uniform mat4 projection;

void main() {
    vTexCoord = aPos.xy * aParticleTexSize;
    vIndex = aParticleIndex;

    vec2 pos = aParticlePosition + aPos.xy * aParticleSize;

    gl_Position = projection * vec4(pos, 0.0, 1.0);
}
___glsl

FONT_PARTICLE_FRAGMENT_SHADER :: #string ___glsl
#version 330 core

out vec4 FragColor;

in vec2 vTexCoord;
flat in float vIndex;
flat in vec2 vTexSize;

uniform sampler2DArray uTexture;
uniform vec4 uTint;
uniform float uPadding;
uniform float uScale;

void main() {
    float sdf = texture(uTexture, vec3(vTexCoord, vIndex)).r;
    // sdf = sdf - 128.0 / 255.0;
    // it seems to change 16 / 255 per pixel

    float edge = 128.0 / 255.0;
    float edgeWidth = 12.0 / 255.0 / uScale;
    float edgeMin = max(edge - edgeWidth - uPadding / 16.0, 0.0);
    float edgeMax = min(edge + edgeWidth - uPadding / 16.0, 1.0);

    float alpha = smoothstep(edgeMin, edgeMax, sdf);

    FragColor = vec4(1.0, 1.0, 1.0, alpha) * uTint;
}
___glsl
