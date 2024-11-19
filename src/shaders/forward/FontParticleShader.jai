
font_particle_shader := #run create_shader(FONT_PARTICLE_VERTEX_SHADER, FONT_PARTICLE_FRAGMENT_SHADER);

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
layout (location = 8) in vec4 aParticleTint;
layout (location = 9) in float aParticlePadding;
layout (location = 10) in float aParticleScale;
layout (location = 11) in float aParticleBlur;
layout (location = 12) in float aParticleRotation;
layout (location = 13) in vec3 aParticleWorldPosition;

out vec3 vTexCoord;
flat out float vIndex;
flat out vec2 vTexSize;
flat out vec4 vTint;
flat out float vPadding;
flat out float vScale;
flat out float vBlur;

uniform mat4 projection;
uniform mat4 view;

vec2 rotate(vec2 p, float r) {
    float cos_r = cos(r);
    float sin_r = sin(r);
    return vec2(p.x * cos_r - p.y * sin_r, p.x * sin_r + p.y * cos_r);
}

void main() {
    mat3 transform = mat3(
        aParticleTransform1.x, aParticleTransform2.x, aParticleTransform3.x,
        aParticleTransform1.y, aParticleTransform2.y, aParticleTransform3.y,
        aParticleTransform1.z, aParticleTransform2.z, aParticleTransform3.z);
    vTexCoord = vec3(aPos.xy, 1);
    vIndex = aParticleIndex;
    vTexSize = aParticleTexSize;
    vTint = aParticleTint;
    vPadding = aParticlePadding;
    vScale = aParticleScale;
    vBlur = aParticleBlur;

    vec2 localCenter = aParticleSize / 2.0;
    vec2 localPos = rotate(aPos.xy * aParticleSize - localCenter, aParticleRotation) + localCenter;

    vec3 pos = transform * vec3(aParticlePosition + localPos, 1.0);

    if (dot(aParticleWorldPosition, aParticleWorldPosition) > 0.0) {
        // when in 3d space we will keep it always camera facing for now
        vTexCoord.y = 1.0 - vTexCoord.y;

        gl_Position = projection * (view * vec4(aParticleWorldPosition, 1.0) + vec4(pos.xy, 0.0, 0.0));
    } else {
        // when in 2d space we will appropriately transform the font by the view matrix
        pos.xy /= pos.z;
        vTexCoord.z = pos.z;
        vTexCoord.xy /= vTexCoord.z;

        gl_Position = projection * view * vec4(pos.xy, 0.0, 1.0);
    }
}
___glsl

FONT_PARTICLE_FRAGMENT_SHADER :: #string ___glsl
#version 330 core

out vec4 FragColor;

in vec3 vTexCoord;
flat in float vIndex;
flat in vec2 vTexSize;
flat in vec4 vTint;
flat in float vPadding;
flat in float vScale;
flat in float vBlur;

uniform sampler2DArray uTexture;

void main() {
    vec2 coord = vTexCoord.xy * vTexCoord.z;
    coord *= vTexSize;

    float fScale = 4.0 / (length(fwidth(vTexCoord.xy)) * length(vec2(textureSize(uTexture, 0).xy)));

    // TODO implement smdb w/e sdf
    float sdf;
    if (fScale < 1.5) {
        sdf = texture(uTexture, vec3(coord, vIndex)).r;
    } else {
        vec2 pixelSize = 1.0 / vec2(textureSize(uTexture, 0).xy) * vScale;
        sdf = texture(uTexture, vec3(coord, vIndex)).r / 5.0 +
            texture(uTexture, vec3(coord + vec2(-0.25, -0.25) * pixelSize, vIndex)).r / 5.0 +
            texture(uTexture, vec3(coord + vec2(0.25, -0.25) * pixelSize, vIndex)).r / 5.0 + 
            texture(uTexture, vec3(coord + vec2(-0.25, 0.25) * pixelSize, vIndex)).r / 5.0 + 
            texture(uTexture, vec3(coord + vec2(0.25, 0.25) * pixelSize, vIndex)).r / 5.0;
    }
    
    // sdf = sdf - 128.0 / 255.0;
    // it seems to change 16 / 255 per pixel

    float edge = 128.0 / 255.0;
    float edgeWidth = 12.0 / 255.0 / fScale;
    float edgeMin = clamp(edge - edgeWidth * 1.0 - vPadding / 16.0 - vBlur / 8.0, 0.0, 1.0 - edgeWidth);
    float edgeMax = clamp(edge + edgeWidth * 1.0 - vPadding / 16.0 + vBlur / 8.0, edgeWidth, 1.0);

    float alpha = smoothstep(edgeMin, edgeMax, sdf);

    FragColor = vec4(1.0, 1.0, 1.0, alpha) * vTint;
}
___glsl
