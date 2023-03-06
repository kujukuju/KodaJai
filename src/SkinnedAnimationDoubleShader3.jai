SkinnedAnimationDoubleShader3 :: struct {
    using #as shader: Shader;

    shader.vertex = SKINNED_ANIMATION_DOUBLE_VERTEX_SHADER3;
    shader.fragment = SKINNED_ANIMATION_DOUBLE_FRAGMENT_SHADER3;
}

#scope_module

SKINNED_ANIMATION_DOUBLE_VERTEX_SHADER3 :: #string DONE
#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aNorm;
layout (location = 2) in vec2 aTex;
layout (location = 3) in vec4 aJointIndices1;
layout (location = 4) in vec4 aJointIndices2;
layout (location = 5) in vec4 aJointWeights1;
layout (location = 6) in vec4 aJointWeights2;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

uniform mat4 uJoints[100];

out vec3 vPos;
out vec3 vNorm;
out vec2 vTex;

void main() {
    vPos = vec3(model * vec4(aPos, 1.0));
    vNorm = vec3(model * vec4(aNorm, 0.0));
    vTex = aTex;
    
    mat4 skinMat =
        aJointWeights1.x * uJoints[int(aJointIndices1.x)] +
        aJointWeights1.y * uJoints[int(aJointIndices1.y)] +
        aJointWeights1.z * uJoints[int(aJointIndices1.z)] +
        aJointWeights1.w * uJoints[int(aJointIndices1.w)] +
        aJointWeights2.x * uJoints[int(aJointIndices2.x)] +
        aJointWeights2.y * uJoints[int(aJointIndices2.y)] +
        aJointWeights2.z * uJoints[int(aJointIndices2.z)] +
        aJointWeights2.w * uJoints[int(aJointIndices2.w)];

    gl_Position = projection * view * skinMat * vec4(aPos, 1.0);
}
DONE

SKINNED_ANIMATION_DOUBLE_FRAGMENT_SHADER3 :: #string DONE
#version 330 core
out vec4 FragColor;
  
uniform sampler2D uTexture0;

in vec3 vPos;
in vec3 vNorm;
in vec2 vTex;

void main() {
    // vec3 lightPos = vec3(5.0, 10.0, -10.0);
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

    FragColor = vec4(result.rgb, 1.0);
}
DONE