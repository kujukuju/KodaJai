DefaultEllipseShader :: struct {
    using #as shader: Shader;

    shader.vertex = DEFAULT_ELLIPSE_VERTEX_SHADER;
    shader.fragment = DEFAULT_ELLIPSE_FRAGMENT_SHADER;
}

#scope_module

DEFAULT_ELLIPSE_VERTEX_SHADER :: #string DONE
#version 330 core
layout (location = 0) in vec2 aPos;
layout (location = 1) in vec2 aTexCoord;

out vec2 vTexCoord;

uniform mat4 projection;
uniform mat4 view;
uniform mat4 model;

uniform vec2 uPos;
uniform vec2 uDim;
// uniform vec2 uOriginalDim;
uniform vec2 uScreenDim;
uniform vec4 uFrame;

void main() {
    gl_Position = projection * view * model * vec4(aPos, 0.0, 1.0);
    
    vTexCoord = aTexCoord * uFrame.zw + uFrame.xy;
}
DONE

DEFAULT_ELLIPSE_FRAGMENT_SHADER :: #string DONE
#version 330 core
out vec4 FragColor;
  
in vec2 vTexCoord;

uniform vec4 uTint;
uniform vec4 uBorderTint;

void main() {
    vec2 fromCenter = vTexCoord * 2.0 - 1.0;
    float distance = length(fromCenter);
    // can use that one function to get the pixel density and scale appropriately instead of hard edges
    float color = distance <= 1.0 ? 1.0 : 0.0;
    float border = distance > 0.94 && distance <= 1.0 ? 1.0 : 0.0;

    // TODO use whatever that pixel density function is

    vec4 averageColor = (uTint * uTint.a * color + uBorderTint * uBorderTint.a * border) / (uTint.a * color + uBorderTint.a * border);

    FragColor = averageColor * max(uTint.a * color, uBorderTint.a * border);
}
DONE