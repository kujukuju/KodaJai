CubemapShader :: struct {
    using #as shader: Shader;

    shader.name = "CubemapShader";
    shader.vertex = CUBEMAP_VERTEX_SHADER;
    shader.fragment = CUBEMAP_FRAGMENT_SHADER;
}

#scope_module

CUBEMAP_VERTEX_SHADER :: #string DONE
#version 330 core
layout (location = 0) in vec3 aPos;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

out vec3 vPos;
out vec3 vCamera;

void main() {
    vPos = vec3(model * vec4(aPos, 1.0));
    vCamera = vec3(inverse(view) * vec4(0.0, 0.0, 0.0, 1.0));

    gl_Position = projection * view * model * vec4(aPos, 1.0);
}
DONE

CUBEMAP_FRAGMENT_SHADER :: #string DONE
#version 330 core
out vec4 FragColor;
  
uniform samplerCube uTexture0;

in vec3 vPos;
in vec3 vCamera;

void main() {
    vec3 direction = normalize(vPos - vCamera);
    vec3 color = texture(uTexture0, direction).rgb;
    
    FragColor = vec4(color, 1.0);
}
DONE