DefaultEllipseShader :: struct {
    using #as shader: Shader;

    shader.name = "DefaultEllipseShader";
    shader.vertex = DEFAULT_ELLIPSE_VERTEX_SHADER;
    shader.fragment = DEFAULT_ELLIPSE_FRAGMENT_SHADER;
}

default_ellipse_shader: DefaultEllipseShader;

#scope_module

DEFAULT_ELLIPSE_VERTEX_SHADER :: #string ___glsl
#version 330 core
layout (location = 0) in vec2 aPos;
layout (location = 1) in vec2 aTexCoord;

out vec2 vTexCoord;

uniform mat4 projection;
uniform mat4 view;
uniform mat4 model;

uniform vec2 uPos;
uniform vec2 uDim;
uniform vec2 uScreenDim;
uniform vec4 uFrame;

void main() {
    gl_Position = projection * view * model * vec4(aPos, 0.0, 1.0);
    
    vTexCoord = aTexCoord * uFrame.zw + uFrame.xy;
}
___glsl

DEFAULT_ELLIPSE_FRAGMENT_SHADER :: #string ___glsl
#version 330 core
out vec4 FragColor;
  
in vec2 vTexCoord;

uniform vec4 uTint;
uniform vec4 uBorderTint;

void main() {
    vec2 fromCenter = vTexCoord * 2.0 - 1.0;
    float distance = length(fromCenter);
    // can use that one function to get the pixel density and scale appropriately instead of hard edges

    const float edgeWidth = 2.0;

    float color = smoothstep(1.0, 1.0 - length(fwidth(vTexCoord)) * edgeWidth, distance);
    float border = smoothstep(1.0 - length(fwidth(vTexCoord)) * edgeWidth, 1.0 - length(fwidth(vTexCoord)) * edgeWidth * 2.0, distance);

    // TODO use whatever that pixel density function is

    vec4 averageColor = (uTint * uTint.a * color + uBorderTint * uBorderTint.a * border) / (uTint.a * color + uBorderTint.a * border);

    FragColor = averageColor * max(uTint.a * color, uBorderTint.a * border);
    // FragColor = vec4(1.0, 1.0, 1.0, 1.0);
}
___glsl