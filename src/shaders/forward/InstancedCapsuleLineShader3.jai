
instanced_capsule_line_shader3 := #run create_shader(INSTANCED_CAPSULE_LINE_VERTEX_SHADER3, INSTANCED_CAPSULE_LINE_FRAGMENT_SHADER3);

#scope_module

INSTANCED_CAPSULE_LINE_VERTEX_SHADER3 :: #string ___glsl
#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec4 aModel1;
layout (location = 2) in vec4 aModel2;
layout (location = 3) in vec4 aModel3;
layout (location = 4) in vec4 aModel4;
layout (location = 5) in float aHalflength;
layout (location = 6) in float aRadius;

uniform mat4 view;
uniform mat4 projection;

void main() {
    mat4 model = mat4(
        aModel1.x, aModel2.x, aModel3.x, aModel4.x,
        aModel1.y, aModel2.y, aModel3.y, aModel4.y,
        aModel1.z, aModel2.z, aModel3.z, aModel4.z,
        aModel1.w, aModel2.w, aModel3.w, aModel4.w);

    vec3 pos = (aPos - vec3(0.0, sign(aPos.y), 0.0)) * aRadius;
    pos = pos + vec3(0.0, sign(aPos.y), 0.0) * aHalflength;

    gl_Position = projection * view * model * vec4(pos, 1.0);
}
___glsl

INSTANCED_CAPSULE_LINE_FRAGMENT_SHADER3 :: #string ___glsl
#version 330 core
out vec4 FragColor;

uniform vec4 uTint;

void main() {
    FragColor = uTint;
}
___glsl