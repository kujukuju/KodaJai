
skinned_animation_no_normal_shader3 := #run create_shader(SKINNED_ANIMATION_NO_NORMAL_VERTEX_SHADER3, SKINNED_ANIMATION_NO_NORMAL_FRAGMENT_SHADER3);

#scope_module

SKINNED_ANIMATION_NO_NORMAL_VERTEX_SHADER3 :: #string DONE
#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aTex;
layout (location = 2) in vec4 aJointIndices;
layout (location = 3) in vec4 aJointWeights;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

uniform mat4 uJoints[100];

out vec3 vPos;
out vec2 vTex;

void main() {
    mat4 skinMat =
        aJointWeights.x * uJoints[int(aJointIndices.x)] +
        aJointWeights.y * uJoints[int(aJointIndices.y)] +
        aJointWeights.z * uJoints[int(aJointIndices.z)] +
        aJointWeights.w * uJoints[int(aJointIndices.w)];

    vPos = vec3(model * skinMat * vec4(aPos, 1.0));
    vTex = aTex;

    gl_Position = projection * view * model * skinMat * vec4(aPos, 1.0);
}
DONE

SKINNED_ANIMATION_NO_NORMAL_FRAGMENT_SHADER3 :: #string DONE
#version 330 core
out vec4 FragColor;
  
uniform sampler2D uTexture0;

in vec3 vPos;
in vec2 vTex;

void main() {
    // vec3 lightPos = vec3(5.0, 10.0, -10.0);
    vec3 lightColor = vec3(1.0, 1.0, 1.0);
    vec3 ambient = vec3(0.2, 0.2, 0.2);
    vec4 objectColor = texture(uTexture0, vTex);
    if (objectColor.a < 0.5) {
        discard;
    }

    // vec3 lightDir = normalize(lightPos - vPos);
    vec3 lightDir = normalize(vec3(0.5, 1.0, -1.0));
    vec3 diffuse =  lightColor;
    vec4 result = vec4(ambient + diffuse, 1.0) * objectColor;

    FragColor = vec4(result.rgb, 1.0);
}
DONE