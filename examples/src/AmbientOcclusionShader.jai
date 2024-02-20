AmbientOcclusionShader :: struct {
    using #as shader: Shader;

    shader.vertex = AMBIENT_OCCLUSION_VERTEX_SHADER;
    shader.fragment = AMBIENT_OCCLUSION_FRAGMENT_SHADER;
}

#scope_module

AMBIENT_OCCLUSION_VERTEX_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) in vec2 aPos;

uniform mat4 view;

out vec2 vCoord;
out vec3 vCamera;
out vec3 vCameraForward;

void main() {
    vCoord = aPos * vec2(0.5, 0.5) + 0.5;
    vCamera = vec3(inverse(view) * vec4(0.0, 0.0, 0.0, 1.0));
    vCameraForward = vec3(inverse(view) * vec4(0.0, 0.0, -1.0, 0.0));

    gl_Position = vec4(aPos, 0.0, 1.0);
}
___glsl

AMBIENT_OCCLUSION_FRAGMENT_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) out float FragColor;

const int MAX_KERNEL_SIZE = 64;
const float SAMPLE_RADIUS = 0.5;
const float BIAS = 0.025;

uniform mat4 view;
uniform mat4 projection;

uniform sampler2D uPosition;
uniform sampler2D uNormal;
// uniform sampler2D uDepth;
uniform sampler2D uNoise;

uniform vec3 uKernel[MAX_KERNEL_SIZE];
uniform vec2 uNoiseScale;

in vec2 vCoord;
in vec3 vCamera;
in vec3 vCameraForward;

void main() {
    vec2 coords = vCoord;

    // get input for ssao algorithm
    vec3 viewFragPos = vec3(view * vec4(texture(uPosition, coords).xyz, 1.0));
    vec3 viewNormal = vec3(view * vec4(normalize(texture(uNormal, coords).rgb), 0.0));
    vec3 randomVec = normalize(texture(uNoise, coords * uNoiseScale).xyz);
    // create TBN change-of-basis matrix: from tangent-space to view-space
    vec3 tangent = normalize(randomVec - viewNormal * dot(randomVec, viewNormal));
    vec3 bitangent = cross(viewNormal, tangent);
    mat3 TBN = mat3(tangent, bitangent, viewNormal);

    float occlusion = 0.0;
    for (int i = 0; i < MAX_KERNEL_SIZE; i++) {
        // get sample position
        vec3 samplePos = TBN * uKernel[i]; // from tangent to view-space
        samplePos = viewFragPos + samplePos * SAMPLE_RADIUS; 
        
        // project sample position (to sample texture) (to get position on screen/texture)
        vec4 offset = vec4(samplePos, 1.0);
        offset = projection * offset; // from view to clip-space
        offset.xyz /= offset.w; // perspective divide
        offset.xyz = offset.xyz * 0.5 + 0.5; // transform to range 0.0 - 1.0
        
        // get sample depth
        float sampleDepth = dot(vCamera - texture(uPosition, offset.xy).rgb, vCameraForward);
        // float sampleDepth = vec3(view * vec4(texture(uPosition, offset.xy).rgb, 1.0)).z; // get depth value of kernel sample
        
        // range check & accumulate
        float rangeCheck = smoothstep(0.0, 1.0, SAMPLE_RADIUS / abs(viewFragPos.z - sampleDepth));
        occlusion += (sampleDepth >= samplePos.z + BIAS ? 1.0 : 0.0) * rangeCheck;
    }
    occlusion = 1.0 - occlusion / float(MAX_KERNEL_SIZE);

    FragColor = pow(occlusion, 2.0);
    // FragColor = vec4(vec3(pow(occlusion, 2.0)), 0.0);
}
___glsl