SpriteShader3 :: struct {
    using #as shader: Shader;

    shader.name = "SpriteShader3";
    shader.vertex = SPRITE3_VERTEX_SHADER;
    shader.fragment = SPRITE3_FRAGMENT_SHADER;
}

sprite_shader3: SpriteShader3;

#scope_module

SPRITE3_VERTEX_SHADER :: #string ___glsl
#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aTexCoord;

out vec2 vTexCoord;

uniform mat4 modelViewProjection;
uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

uniform vec4 uFrame;

// vec3 rotate(vec3 v, vec4 quat) {
//     float t = cross(quat.xyz, v) * 2.0;
//     return v + t * quat.w + cross(quat.xyz, t);
// }

void main() {
    // gl_Position = modelViewProjection * vec4(aPos, 1.0);
    
    vTexCoord = aTexCoord * uFrame.zw + uFrame.xy;

    vec3 modelPosition = vec3(model * vec4(0.0, 0.0, 0.0, 1.0));
    // vec3 modelPosition = vec3(model[0][3], model[1][3], model[2][3]);
    vec3 appliedPos = vec3(model * vec4(aPos, 0.0));

    gl_Position = projection * (view * vec4(modelPosition, 1.0) + vec4(appliedPos, 0.0));
    // gl_Position = projection * view * model * vec4(aPos, 1.0);
}
___glsl

SPRITE3_FRAGMENT_SHADER :: #string ___glsl
#version 330 core

out vec4 FragColor;
  
in vec2 vTexCoord;

uniform sampler2D uTexture;
uniform vec4 uTint;

void main() {
    FragColor = texture(uTexture, vTexCoord) * uTint;
}
___glsl
