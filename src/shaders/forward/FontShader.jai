FontShader :: struct {
    using #as shader: Shader;

    shader.name = "FontShader";
    shader.vertex = FONT_VERTEX_SHADER;
    shader.fragment = FONT_FRAGMENT_SHADER;
}

font_shader: FontShader;

#scope_module

FONT_VERTEX_SHADER :: #string DONE
#version 330 core
layout (location = 0) in vec2 aPos;
layout (location = 1) in vec2 aTexCoord;

out vec2 vTexCoord;

uniform mat4 projection;

void main() {
    gl_Position = projection * vec4(aPos, 0.0, 1.0);
    vTexCoord = aTexCoord;
}
DONE

FONT_FRAGMENT_SHADER :: #string DONE
#version 330 core
out vec4 FragColor;
  
in vec2 vTexCoord;

uniform sampler2D uTexture;
uniform vec4 uTint;

void main() {
    FragColor = vec4(1.0, 1.0, 1.0, texture(uTexture, vTexCoord).r) * uTint;
}
DONE