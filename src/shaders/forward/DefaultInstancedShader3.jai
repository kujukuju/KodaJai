
default_instanced_shader3 := #run create_shader(DEFAULT_INSTANCED_VERTEX_SHADER3, DEFAULT_INSTANCED_FRAGMENT_SHADER3);

#scope_module

DEFAULT_INSTANCED_VERTEX_SHADER3 :: #string ___glsl
#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aNorm;
layout (location = 2) in vec2 aTex;
layout (location = 3) in vec4 aModel1;
layout (location = 4) in vec4 aModel2;
layout (location = 5) in vec4 aModel3;
layout (location = 6) in vec4 aModel4;

uniform mat4 view;
uniform mat4 projection;

out vec3 vPos;
out vec3 vNorm;
out vec2 vTex;

void main() {
    mat4 model = mat4(
        aModel1.x, aModel2.x, aModel3.x, aModel4.x,
        aModel1.y, aModel2.y, aModel3.y, aModel4.y,
        aModel1.z, aModel2.z, aModel3.z, aModel4.z,
        aModel1.w, aModel2.w, aModel3.w, aModel4.w);

    vPos = vec3(model * vec4(aPos, 1.0));
    vNorm = vec3(model * vec4(aNorm, 0.0));
    vTex = aTex;

    gl_Position = projection * view * model * vec4(aPos, 1.0);
}
___glsl

DEFAULT_INSTANCED_FRAGMENT_SHADER3 :: #string ___glsl
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
