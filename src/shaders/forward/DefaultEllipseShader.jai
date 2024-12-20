
default_ellipse_shader := #run create_shader(DEFAULT_ELLIPSE_VERTEX_SHADER, DEFAULT_ELLIPSE_FRAGMENT_SHADER);

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
    float border = smoothstep(1.0 - length(fwidth(vTexCoord)) * edgeWidth * 3.0, 1.0 - length(fwidth(vTexCoord)) * edgeWidth * 2.0, distance);

    vec4 finalColor = uTint * color;
    // finalColor = finalColor * (1.0 - border) + uBorderTint * border;
    finalColor.rgb /= finalColor.a;

    FragColor = finalColor;
    // FragColor = vec4(1.0);
}
___glsl