
FontParticleShader :: struct {
    using #as shader: Shader;

    shader.name = "FontParticleShader";
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
layout (location = 5) in vec3 aParticleTransform1;
layout (location = 6) in vec3 aParticleTransform2;
layout (location = 7) in vec3 aParticleTransform3;

out vec3 vTexCoord;
flat out float vIndex;
flat out vec2 vTexSize;

uniform mat4 projection;
uniform mat4 view;

void main() {
    mat3 transform = mat3(aParticleTransform1, aParticleTransform2, aParticleTransform3);
    vTexCoord = vec3(aPos.xy, 1);
    vIndex = aParticleIndex;
    vTexSize = aParticleTexSize;

    vec3 pos = transform * vec3(aParticlePosition + aPos.xy * aParticleSize, 1.0);
    pos.xy /= pos.z;
    vTexCoord.z = pos.z;
    vTexCoord.xy /= vTexCoord.z;

    gl_Position = projection * view * vec4(pos.xy, 0.0, 1.0);
}
___glsl

FONT_PARTICLE_FRAGMENT_SHADER :: #string ___glsl
#version 330 core

out vec4 FragColor;

in vec3 vTexCoord;
flat in float vIndex;
flat in vec2 vTexSize;

uniform sampler2DArray uTexture;
uniform vec4 uTint;
uniform float uPadding;
uniform float uScale;
uniform float uBlur;

void main() {
    vec2 coord = vTexCoord.xy * vTexCoord.z;
    coord *= vTexSize;

    // TODO implement smdb w/e sdf
    float sdf;
    if (uScale < 1.5) {
        sdf = texture(uTexture, vec3(coord, vIndex)).r;
    } else {
        vec2 pixelSize = 1.0 / vec2(textureSize(uTexture, 0).xy) * uScale;
        sdf = texture(uTexture, vec3(coord, vIndex)).r / 5.0 +
            texture(uTexture, vec3(coord + vec2(-0.25, -0.25) * pixelSize, vIndex)).r / 5.0 +
            texture(uTexture, vec3(coord + vec2(0.25, -0.25) * pixelSize, vIndex)).r / 5.0 + 
            texture(uTexture, vec3(coord + vec2(-0.25, 0.25) * pixelSize, vIndex)).r / 5.0 + 
            texture(uTexture, vec3(coord + vec2(0.25, 0.25) * pixelSize, vIndex)).r / 5.0;
    }
    
    // sdf = sdf - 128.0 / 255.0;
    // it seems to change 16 / 255 per pixel

    float edge = 128.0 / 255.0;
    float edgeWidth = 12.0 / 255.0 / uScale;
    float edgeMin = clamp(edge - edgeWidth * 1.0 - uPadding / 16.0 - uBlur / 8.0, 0.0, 1.0 - edgeWidth);
    float edgeMax = clamp(edge + edgeWidth * 1.0 - uPadding / 16.0 + uBlur / 8.0, edgeWidth, 1.0);

    float alpha = smoothstep(edgeMin, edgeMax, sdf);

    FragColor = vec4(1.0, 1.0, 1.0, alpha) * uTint;
}
___glsl
