
FontParticleShader :: struct {
    using #as shader: Shader;

    shader.vertex = FONT_PARTICLE_VERTEX_SHADER;
    shader.fragment = FONT_PARTICLE_FRAGMENT_SHADER;
}

font_particle_shader: FontParticleShader;

#scope_module

FONT_PARTICLE_VERTEX_SHADER :: #string ___glsl
#version 330 core
layout (location = 0) in vec2 aPos;
layout (location = 1) in vec2 aTex;
layout (location = 2) in vec2 aParticlePosition;
layout (location = 3) in vec2 aParticleSize;
layout (location = 4) in vec2 aParticleTexSize;
layout (location = 5) in float aParticleIndex;

out vec2 vTexCoord;

uniform mat4 projection;

void main() {
    vec2 pos = 

    gl_Position = projection * vec4(aPos, 0.0, 1.0);
    vTexCoord = aTexCoord;
}
___glsl

FONT_PARTICLE_FRAGMENT_SHADER :: #string ___glsl
#version 330 core
out vec4 FragColor;
  
in vec2 vTexCoord;

uniform sampler2D uTexture;
uniform vec4 uTint;

void main() {
    FragColor = vec4(1.0, 1.0, 1.0, texture(uTexture, vTexCoord).r) * uTint;
}
___glsl
