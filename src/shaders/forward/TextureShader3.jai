
texture_shader3 := #run create_shader(TEXTURE_VERTEX_SHADER3, TEXTURE_FRAGMENT_SHADER3);

#scope_module

TEXTURE_VERTEX_SHADER3 :: #string DONE
#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aTex;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

out vec2 vTex;

void main() {
    vTex = aTex;

    gl_Position = projection * view * model * vec4(aPos, 1.0);
}
DONE

TEXTURE_FRAGMENT_SHADER3 :: #string DONE
#version 330 core
out vec4 FragColor;
  
uniform sampler2D uTexture0;

in vec2 vTex;

void main() {
    // vec4 objectColor = texture(uTexture0, vTex);
    // if (objectColor.a < 0.5) {
    //     discard;
    // }

    FragColor = texture(uTexture0, vTex);
}
DONE