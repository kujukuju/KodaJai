DefaultColorShader3 :: struct {
    using #as shader: Shader;

    shader.name = "DefaultColorShader3";
    shader.vertex = DEFAULT_COLOR_VERTEX_SHADER3;
    shader.fragment = DEFAULT_COLOR_FRAGMENT_SHADER3;
}

default_color_shader3: DefaultColorShader3;

#scope_module

DEFAULT_COLOR_VERTEX_SHADER3 :: #string DONE
#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aNorm;
layout (location = 2) in vec2 aTex;
layout (location = 3) in vec4 aColor;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

out vec3 vPos;
out vec3 vNorm;
out vec2 vTex;
out vec4 vColor;

void main() {
    vPos = vec3(model * vec4(aPos, 1.0));
    vNorm = aNorm;
    vTex = aTex;
    vColor = aColor;

    gl_Position = projection * view * model * vec4(aPos, 1.0);
}
DONE

DEFAULT_COLOR_FRAGMENT_SHADER3 :: #string DONE
#version 330 core
out vec4 FragColor;
  
uniform sampler2D uTexture0;

in vec3 vPos;
in vec3 vNorm;
in vec2 vTex;
in vec4 vColor;

void main() {
    // vec3 lightPos = vec3(-44.0, -102.0, -180.0);
    vec3 lightColor = vec3(1.0, 1.0, 1.0);
    vec3 ambient = vec3(0.2, 0.2, 0.2);
    vec3 objectColor = texture(uTexture0, vTex).rgb * vec3(1.0, 1.0, 1.0);

    vec3 norm = normalize(vNorm);
    // vec3 lightDir = normalize(vPos - lightPos);
    vec3 lightDir = normalize(vec3(6.0, 19.5, 50.0));
    float lightDirDot = dot(norm, lightDir) * 0.5 + 0.5;
    float diff = lightDirDot * lightDirDot;
    vec3 diffuse = diff * lightColor;
    vec3 result = (ambient + diffuse) * objectColor * (vColor.rgb * 0.5 + 0.5);

    FragColor = vec4(result, 1.0);
}
DONE