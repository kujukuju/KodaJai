VolumetricCloudShader :: struct {
    using #as shader: Shader;

    shader.vertex = VOLUMETRIC_CLOUD_VERTEX_SHADER3;
    shader.fragment = VOLUMETRIC_CLOUD_FRAGMENT_SHADER3;
}

#scope_module

VOLUMETRIC_CLOUD_VERTEX_SHADER3 :: #string DONE
#version 330 core
layout (location = 0) in vec3 aPos;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

out vec3 vCamera;
out vec3 vPos;
out vec3 vCoord;

void main() {
    vCamera = (inverse(model) * inverse(view) * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    vPos = aPos;
    vCoord = aPos / 2.0 + 0.5;

    gl_Position = projection * view * model * vec4(aPos, 1.0);
}
DONE

VOLUMETRIC_CLOUD_FRAGMENT_SHADER3 :: #string DONE
#version 330 core
out vec4 FragColor;

uniform mat4 view;

uniform vec3 uNoiseDimensions;
uniform sampler3D uNoiseTexture;

in vec3 vCamera;
in vec3 vPos;
in vec3 vCoord;

float sphereGradient(vec3 coord) {
    coord = (coord - 0.5) * 2.0;
    float radius = min(length(coord), 1.0);
    float alpha = 1.0 - max(radius - 0.9, 0.0) / 0.1;
    return alpha;
}

void main() {
    vec3 dir = normalize(vPos - vCamera);

    vec3 current = vCoord;
    float density = 0.0;

    float distance = 0.0;

    bool exit = false;
    exit = exit || current.x <= 0 && dir.x < 0;
    exit = exit || current.y <= 0 && dir.y < 0;
    exit = exit || current.z <= 0 && dir.z < 0;
    exit = exit || current.x >= 1 && dir.x > 0;
    exit = exit || current.y >= 1 && dir.y > 0;
    exit = exit || current.z >= 1 && dir.z > 0;
    while (!exit) {
        density += texture(uNoiseTexture, current).r * 0.01;

        current += dir / 100.0;

        exit = exit || current.x <= 0 && dir.x < 0;
        exit = exit || current.y <= 0 && dir.y < 0;
        exit = exit || current.z <= 0 && dir.z < 0;
        exit = exit || current.x >= 1 && dir.x > 0;
        exit = exit || current.y >= 1 && dir.y > 0;
        exit = exit || current.z >= 1 && dir.z > 0;
    }

    FragColor = vec4(1.0, 1.0, 1.0, density);
}
DONE