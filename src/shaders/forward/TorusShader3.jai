
torus_shader3 := #run create_shader(TORUS_VERTEX_SHADER3, TORUS_FRAGMENT_SHADER3);

#scope_module

TORUS_VERTEX_SHADER3 :: #string ___glsl
#version 330 core
layout (location = 0) in vec3 aPos;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;
uniform float uMajorRadius;
uniform float uMinorRadius;

void main() {
    vec3 majorDir = normalize(vec3(aPos.x, 0.0, aPos.z));
    vec3 majorCenter = majorDir * 2.0;
    vec3 minorDir = normalize(aPos - majorCenter);

    vec3 newPos = majorDir * uMajorRadius + minorDir * uMinorRadius;

    gl_Position = projection * view * model * vec4(newPos, 1.0);
}
___glsl

TORUS_FRAGMENT_SHADER3 :: #string ___glsl
#version 330 core
out vec4 FragColor;

uniform vec4 uTint;

void main() {
    FragColor = uTint;
}
___glsl