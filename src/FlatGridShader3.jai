FlatGridShader3 :: struct {
    using #as shader: Shader;

    shader.vertex = FLAT_GRID_VERTEX_SHADER3;
    shader.fragment = FLAT_GRID_FRAGMENT_SHADER3;
}

#scope_module

FLAT_GRID_VERTEX_SHADER3 :: #string DONE
#version 330 core
layout (location = 0) in vec3 aPos;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

out vec3 vPos;
out vec3 vWorldPos;

void main() {
    vPos = aPos;
    vWorldPos = vec3(model * vec4(aPos, 1.0));

    gl_Position = projection * view * model * vec4(aPos, 1.0);
}
DONE

FLAT_GRID_FRAGMENT_SHADER3 :: #string DONE
#version 330 core
out vec4 FragColor;

uniform mat4 view;

uniform vec4 uTint;
uniform float uRadius;
uniform vec3 uFadeCenter;

in vec3 vPos;
in vec3 vWorldPos;

void main() {
    vec3 cameraPos = vec3(inverse(view) * vec4(0.0, 0.0, 0.0, 1.0));
    vec3 fragDir = normalize(vWorldPos - cameraPos);
    float fragDist = length(vWorldPos - cameraPos);
    float fragDistMul = smoothstep(0.0, 5.0, fragDist);
    float incline = sqrt(abs(dot(vec3(0, 1, 0), fragDir))) * fragDistMul + 1.0 - fragDistMul;

    float sub = 1.0;
    float alpha = 1.0;
    if (uRadius > 0.0) {
        sub = clamp((uRadius - length(vWorldPos - uFadeCenter)) / 10.0, 0.0, 1.0);
        sub = pow(sub, 0.25);
        alpha = clamp((uRadius - length(vWorldPos - uFadeCenter)) / uRadius, 0.0, 1.0);
        alpha = sqrt(alpha) * 0.75 + 0.25;
    }
    FragColor = vec4(uTint.rgb, pow(uTint.a * alpha * sub * incline, 2.0));
}
DONE