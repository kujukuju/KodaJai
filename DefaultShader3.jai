DefaultShader3 :: struct {
    using #as shader: Shader;

    shader.vertex = DEFAULT_VERTEX_SHADER3;
    shader.fragment = DEFAULT_FRAGMENT_SHADER3;
}

#scope_module

DEFAULT_VERTEX_SHADER3 :: #string DONE
#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aNorm;
layout (location = 2) in vec2 aTex;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

out vec3 vPos;
out vec3 vNorm;
out vec2 vTex;

void main() {
    vPos = vec3(model * vec4(aPos, 1.0));
    vNorm = aNorm;
    vTex = aTex;

    gl_Position = projection * view * model * vec4(aPos, 1.0);
}
DONE

DEFAULT_FRAGMENT_SHADER3 :: #string DONE
#version 330 core
out vec4 FragColor;
  
uniform sampler2D uTexture0;

in vec3 vPos;
in vec3 vNorm;
in vec2 vTex;

void main() {
    vec3 lightPos = vec3(5.0, 10.0, -10.0);
    vec3 lightColor = vec3(1.0, 1.0, 1.0);
    vec3 ambient = vec3(0.2, 0.2, 0.2);
    vec3 objectColor = texture(uTexture0, vTex).rgb * vec3(1.0, 1.0, 1.0);

    vec3 norm = normalize(vNorm);
    vec3 lightDir = normalize(lightPos - vPos);
    float diff = max(dot(norm, lightDir), 0.0);
    vec3 diffuse = diff * lightColor;
    vec3 result = (ambient + diffuse) * objectColor;

    FragColor = vec4(result, 1.0);
}
DONE