DefaultShader3 :: struct {
    using #as shader: Shader;

    shader.name = "DefaultShader3";
    shader.vertex = DEFAULT_VERTEX_SHADER3;
    shader.fragment = DEFAULT_FRAGMENT_SHADER3;
}

default_shader3: DefaultShader3;

#scope_module

DEFAULT_VERTEX_SHADER3 :: #string ___glsl
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
    vNorm = vec3(model * vec4(aNorm, 0.0));
    vTex = aTex;

    gl_Position = projection * view * model * vec4(aPos, 1.0);
}
___glsl

DEFAULT_FRAGMENT_SHADER3 :: #string ___glsl
#version 330 core
out vec4 FragColor;
  
uniform sampler2D uTexture0;

uniform vec4 uTint = vec4(1.0, 1.0, 1.0, 1.0);

in vec3 vPos;
in vec3 vNorm;
in vec2 vTex;

void main() {
    vec3 lightColor = vec3(1.0, 1.0, 1.0);
    vec3 ambient = vec3(0.2, 0.2, 0.2);
    vec4 objectColor = texture(uTexture0, vTex);
    if (objectColor.a < 0.5) {
        discard;
    }

    vec3 norm = normalize(vNorm);
    // vec3 lightDir = normalize(lightPos - vPos);
    vec3 lightDir = normalize(vec3(0.5, 1.0, -1.0));
    float diff = max(dot(norm, lightDir), 0.0);
    vec3 diffuse = diff * lightColor;
    vec4 result = vec4(ambient + diffuse, 1.0) * objectColor;

    FragColor = vec4(result.rgb, 1.0) * uTint;

    // FragColor = vec4(1.0);
}
___glsl
