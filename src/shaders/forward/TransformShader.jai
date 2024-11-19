
transform_shader := #run create_shader(TRANSFORM_VERTEX_SHADER, TRANSFORM_FRAGMENT_SHADER);

#scope_module

TRANSFORM_VERTEX_SHADER :: #string DONE
#version 330 core
layout (location = 0) in vec2 aPos;
layout (location = 1) in vec2 aTexCoord;

uniform mat4 projection;
uniform mat4 view;
uniform mat4 model;

uniform vec2 uDim;
uniform vec2 uScreenDim;
uniform vec4 uFrame;
uniform mat3 uTransform;

out vec3 vTexCoord;

void main() {
    vec2 worldPos = vec2(model * vec4(aPos, 0.0, 1.0));

    vTexCoord = vec3(aTexCoord * uFrame.zw + uFrame.xy, 1);

    vec3 pos = uTransform * vec3(worldPos, 1.0);
    pos.xy /= pos.z;
    vTexCoord.z = pos.z;
    vTexCoord.xy /= vTexCoord.z;

    gl_Position = projection * view * vec4(pos.xy, 0.0, 1.0);
}
DONE

TRANSFORM_FRAGMENT_SHADER :: #string DONE
#version 330 core
out vec4 FragColor;

uniform sampler2D uTexture;
uniform vec4 uTint;
  
in vec3 vTexCoord;

void main() {
    vec2 coord = vTexCoord.xy * vTexCoord.z;
    FragColor = texture(uTexture, coord) * uTint;
}
DONE