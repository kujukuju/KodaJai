
GeometryShader :: struct {
    using #as shader: Shader;

    shader.name = "GeometryShader";
    shader.vertex = GEOMETRY_VERTEX_SHADER;
    shader.fragment = GEOMETRY_FRAGMENT_SHADER;
}

geometry_shader: GeometryShader;

#scope_module

GEOMETRY_VERTEX_SHADER :: #string ___glsl
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
out vec3 vCamera;

void main() {
    vPos = vec3(model * vec4(aPos, 1.0));
    vNorm = vec3(model * vec4(aNorm, 0.0));
    vTex = aTex;
    vCamera = vec3(inverse(view) * vec4(0.0, 0.0, 0.0, 1.0));

    gl_Position = projection * view * model * vec4(aPos, 1.0);
}
___glsl

GEOMETRY_FRAGMENT_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) out vec4 PositionOut;
layout (location = 1) out vec4 NormalOut;
layout (location = 2) out vec4 DiffuseOut;
  
uniform sampler2D uTexture0;

uniform vec3 uLightDirection;

in vec3 vPos;
in vec3 vNorm;
in vec2 vTex;
in vec3 vCamera;

void main() {
    vec2 sample = vTex;

    vec3 diffuse = texture(uTexture0, sample).rgb;

    vec3 normal = normalize(vNorm);
    if (!gl_FrontFacing) {
        normal = -normal;
    }

    const vec3 c = vec3(217.0, 250.0, 255.0) / 255.0;
    diffuse = smoothstep(-180.0, -10.0, vPos.y) * (diffuse - c) + c;

    PositionOut = vec4(vPos, 0.0);
    NormalOut = vec4(normal, 0.0);
    DiffuseOut = vec4(diffuse, 0.0);
}
___glsl;