DefaultShaderColors3 :: struct {
    using #as shader: Shader;

    shader.vertex = DEFAULT_VERTEX_SHADER_COLORS3;
    shader.fragment = DEFAULT_FRAGMENT_SHADER_COLORS3;
}

#scope_module

DEFAULT_VERTEX_SHADER_COLORS3 :: #string DONE
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
out vec4 vColor;

void main() {
    vPos = vec3(model * vec4(aPos, 1.0));
    vNorm = aNorm;
    vColor = aColor;

    gl_Position = projection * view * model * vec4(aPos, 1.0);
}
DONE

DEFAULT_FRAGMENT_SHADER_COLORS3 :: #string DONE
#version 330 core
out vec4 FragColor;

in vec3 vPos;
in vec3 vNorm;
in vec4 vColor;

void main() {
    vec3 lightPos = vec3(5.0, 10.0, -10.0);
    vec3 lightColor = vec3(1.0, 1.0, 1.0);
    vec3 ambient = vec3(0.2, 0.2, 0.2);
    vec3 objectColor = vColor.rgb;

    vec3 norm = normalize(vNorm);
    vec3 lightDir = normalize(lightPos - vPos);
    float diff = max(dot(norm, lightDir), 0.0);
    vec3 diffuse = diff * lightColor;
    vec3 result = (ambient + diffuse) * objectColor;

    FragColor = vec4(result, 1.0);
}
DONE