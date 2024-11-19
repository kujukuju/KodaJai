
blur_shader := #run create_shader(BLUR_VERTEX_SHADER, BLUR_FRAGMENT_SHADER);

#scope_module

BLUR_VERTEX_SHADER :: #string DONE
#version 330 core
layout (location = 0) in vec2 aPos;
layout (location = 1) in vec2 aTexCoord;

out vec2 vTexCoord;

uniform mat4 projection;
uniform mat4 view;
uniform mat4 model;

uniform vec2 uDim;
uniform vec2 uScreenDim;
uniform vec4 uFrame;

void main() {
    gl_Position = projection * view * model * vec4(aPos, 0.0, 1.0);
    
    vTexCoord = aTexCoord * uFrame.zw + uFrame.xy;
}
DONE

BLUR_FRAGMENT_SHADER :: #string DONE
#version 330 core
out vec4 FragColor;
  
in vec2 vTexCoord;

uniform sampler2D uTexture;
uniform vec4 uTint;
uniform float uBlur;

vec4 blur9(sampler2D texture, vec2 uv, vec2 resolution, vec2 direction) {
  vec4 color = vec4(0.0);
  vec2 off1 = vec2(1.3846153846) * direction;
  vec2 off2 = vec2(3.2307692308) * direction;
  color += texture2D(image, uv) * 0.2270270270;
  color += texture2D(image, uv + (off1 / resolution)) * 0.3162162162;
  color += texture2D(image, uv - (off1 / resolution)) * 0.3162162162;
  color += texture2D(image, uv + (off2 / resolution)) * 0.0702702703;
  color += texture2D(image, uv - (off2 / resolution)) * 0.0702702703;
  return color;
}

void main() {
    vec2 pixelSize = uBlur / vec2(textureSize(uTexture, 0).xy);
    vec4 color =
        texture(uTexture, vTexCoord + vec2(-1, -1) * pixelSize) / 9.0 +
        texture(uTexture, vTexCoord + vec2(-1, 0) * pixelSize) / 9.0 +
        texture(uTexture, vTexCoord + vec2(-1, 1) * pixelSize) / 9.0 +
        texture(uTexture, vTexCoord + vec2(0, -1) * pixelSize) / 9.0 +
        texture(uTexture, vTexCoord + vec2(0, 0) * pixelSize) / 9.0 +
        texture(uTexture, vTexCoord + vec2(0, 1) * pixelSize) / 9.0 +
        texture(uTexture, vTexCoord + vec2(1, -1) * pixelSize) / 9.0 +
        texture(uTexture, vTexCoord + vec2(1, 0) * pixelSize) / 9.0 +
        texture(uTexture, vTexCoord + vec2(1, 1) * pixelSize) / 9.0;
    FragColor = color * uTint;
}
DONE