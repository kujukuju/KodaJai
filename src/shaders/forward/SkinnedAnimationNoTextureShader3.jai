SkinnedAnimationNoTextureShader3 :: struct {
    using #as shader: Shader;

    shader.name = "SkinnedAnimationNoTextureShader3";
    shader.vertex = SKINNED_ANIMATION_NO_TEXTURE_VERTEX_SHADER3;
    shader.fragment = SKINNED_ANIMATION_NO_TEXTURE_FRAGMENT_SHADER3;
}

#scope_module

SKINNED_ANIMATION_NO_TEXTURE_VERTEX_SHADER3 :: #string DONE
#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aNorm;
layout (location = 2) in vec4 aJointIndices;
layout (location = 3) in vec4 aJointWeights;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

uniform mat4 uJoints[100];

out vec3 vPos;
out vec3 vNorm;

void main() {
    mat4 skinMat =
        aJointWeights.x * uJoints[int(aJointIndices.x)] +
        aJointWeights.y * uJoints[int(aJointIndices.y)] +
        aJointWeights.z * uJoints[int(aJointIndices.z)] +
        aJointWeights.w * uJoints[int(aJointIndices.w)];

    vPos = vec3(model * skinMat * vec4(aPos, 1.0));
    vNorm = vec3(model * skinMat * vec4(aNorm, 0.0));

    gl_Position = projection * view * model * skinMat * vec4(aPos, 1.0);
}
DONE

SKINNED_ANIMATION_NO_TEXTURE_FRAGMENT_SHADER3 :: #string DONE
#version 330 core
out vec4 FragColor;

in vec3 vPos;
in vec3 vNorm;

void main() {
    // vec3 lightPos = vec3(5.0, 10.0, -10.0);
    vec3 lightColor = vec3(1.0, 1.0, 1.0);
    vec3 ambient = vec3(0.2, 0.2, 0.2);
    vec4 objectColor = vec4(1.0, 1.0, 1.0, 1.0);
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