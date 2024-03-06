RoundedRectShader :: struct {
    using #as shader: Shader;

    shader.name = "RoundedRectShader";
    shader.vertex = ROUNDED_RECT_VERTEX_SHADER;
    shader.fragment = ROUNDED_RECT_FRAGMENT_SHADER;
}

rounded_rect_shader: RoundedRectShader;

#scope_module

ROUNDED_RECT_VERTEX_SHADER :: #string ___glsl
#version 330 core
layout (location = 0) in vec2 aPos;
layout (location = 1) in vec2 aTexCoord;

out vec2 vTexCoord;

uniform mat4 projection;
uniform mat4 view;
uniform mat4 model;

uniform vec4 uFrame;

void main() {
    gl_Position = projection * view * model * vec4(aPos, 0.0, 1.0);
    
    vTexCoord = aTexCoord * uFrame.zw + uFrame.xy;
}
___glsl

ROUNDED_RECT_FRAGMENT_SHADER :: #string ___glsl
#version 330 core
out vec4 FragColor;
  
in vec2 vTexCoord;

uniform sampler2D uTexture;
uniform vec4 uTint;
uniform vec2 uDimensions;
uniform float uRadius;

float calculateAlpha(vec2 coord, vec2 corner, vec2 offset) {
    vec2 delta = coord - corner;
    float alpha = step(uRadius, length(delta));

    vec2 innerCorner = corner + offset;
    vec2 innerDelta = coord - innerCorner;
    float innerAlpha = smoothstep(uRadius + 0.5, uRadius - 0.5, length(innerDelta));
    alpha = max(alpha, innerAlpha);

    return alpha;
}

void main() {
    vec2 dimCoord = vTexCoord * uDimensions;

    float topLeftAlpha = calculateAlpha(dimCoord, vec2(0.0, 0.0), vec2(uRadius, uRadius));
    float bottomLeftAlpha = calculateAlpha(dimCoord, vec2(0.0, uDimensions.y), vec2(uRadius, -uRadius));
    float bottomRightAlpha = calculateAlpha(dimCoord, vec2(uDimensions.x, uDimensions.y), vec2(-uRadius, -uRadius));
    float topRightAlpha = calculateAlpha(dimCoord, vec2(uDimensions.x, 0.0), vec2(-uRadius, uRadius));

    float alpha = topLeftAlpha * bottomLeftAlpha * bottomRightAlpha * topRightAlpha;

    FragColor = vec4(uTint.rgb, uTint.a * alpha) * uTint;
}
___glsl