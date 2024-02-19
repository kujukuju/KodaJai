ColorShader :: struct {
    using #as shader: Shader;

    shader.vertex = COLOR_VERTEX_SHADER;
    shader.fragment = COLOR_FRAGMENT_SHADER;
}

#scope_module

COLOR_VERTEX_SHADER :: #string ___glsl
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

COLOR_FRAGMENT_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) out vec3 PositionOut;
layout (location = 1) out vec3 DiffuseOut;     
layout (location = 2) out vec3 NormalOut;     
layout (location = 3) out vec3 TexcoordOut;  
  
uniform sampler2D uTexture0;

uniform vec3 uLightDirection;

in vec3 vPos;
in vec3 vNorm;
in vec2 vTex;
in vec3 vCamera;

// float curve(float value);

void main() {
    // const vec3 planePoint = vec3(-1.33305, 54.63813, 62.292831);
    // const vec3 planeNormal = vec3(-0.193911, -0.63666, -0.746366);

    vec2 sample = vTex;

    vec3 diffuse = texture(uTexture0, sample).rgb;
    // if (diffuse.a < 0.5) {
    //     discard;
    // }

    // float brightness = 1.0;

    vec3 normal = normalize(vNorm);
    if (!gl_FrontFacing) {
        normal = -normal;
    }

    // const vec3 worldLightColor = vec3(245.0 / 255.0, 242.0 / 255.0, 213.0 / 255.0) * 1.5;
    // const vec3 ambientColor = 0.2 * worldLightColor;

    // vec3 lightDir = normalize(uLightDirection);
    // float strength = curve(dot(normal, -lightDir) * 0.8 + 0.2);
    // vec3 result = (ambientColor + strength) * diffuse.rgb * (brightness * 0.5 + 0.5);

    // const vec3 c = vec3(217.0, 250.0, 255.0) / 255.0;
    // result = smoothstep(-180.0, -10.0, vPos.y) * (result - c) + c;

    const vec3 c = vec3(217.0, 250.0, 255.0) / 255.0;
    diffuse = smoothstep(-180.0, -10.0, vPos.y) * (diffuse - c) + c;

    PositionOut = vPos;
    DiffuseOut = diffuse;
    NormalOut = normal;
    TexcoordOut = vec3(vTex, 0.0);

    // FragColor = vec4(result, 1.0);
}
___glsl;