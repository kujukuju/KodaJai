
ssao_shader := #run create_shader(SSAO_VERTEX_SHADER, SSAO_FRAGMENT_SHADER);

SSAO_VERTEX_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) in vec2 aPos;

uniform mat4 view;

out vec2 vCoord;
flat out vec3 vCamera;
flat out vec3 vCameraForward;

void main() {
    vCoord = aPos * vec2(0.5, 0.5) + 0.5;
    vCamera = vec3(inverse(view) * vec4(0.0, 0.0, 0.0, 1.0));
    vCameraForward = vec3(inverse(view) * vec4(0.0, 0.0, -1.0, 0.0));

    gl_Position = vec4(aPos, 0.0, 1.0);
}
___glsl

SSAO_FRAGMENT_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) out float FragColor;

const int MAX_KERNEL_SIZE = 64;
const float SAMPLE_RADIUS = 0.8;
const float FAR_RADIUS = 0.2;
const float MIN_BIAS = 0.01;
const float MAX_BIAS = 0.02;
const float MAX_BIAS_RANGE = 10.0;

uniform mat4 view;
uniform mat4 projection;

uniform sampler2D uPosition;
uniform sampler2D uNormal;
uniform sampler2D uNoise;

uniform vec3 uKernel[MAX_KERNEL_SIZE];
uniform vec2 uNoiseScale;

in vec2 vCoord;
flat in vec3 vCamera;
flat in vec3 vCameraForward;

void main() {
    vec2 coords = vCoord;

    // get input for ssao algorithm
    vec3 fragPos = texture(uPosition, coords).xyz;
    vec3 fragNorm = texture(uNormal, coords).rgb * 2.0 - 1.0;

    vec3 viewFragPos = vec3(view * vec4(fragPos, 1.0));
    vec3 viewNormal = vec3(view * vec4(fragNorm, 0.0));
    vec3 randomVec = normalize(texture(uNoise, coords * uNoiseScale).xyz);
    // create TBN change-of-basis matrix: from tangent-space to view-space
    vec3 tangent = normalize(randomVec - viewNormal * dot(randomVec, viewNormal));
    vec3 bitangent = cross(viewNormal, tangent);
    mat3 TBN = mat3(tangent, bitangent, viewNormal);

    // const float bias = 0.02;

    // const float PI = 3.141592653589793;
    // float biasStrength = 1.0 - abs(dot(normalize(fragPos - vCamera), fragNorm));
    // biasStrength = 1.0 / cos(biasStrength * PI / 3.0) - 1.0;
    // biasStrength = pow(biasStrength, 2.0);

    // float bias = (MAX_BIAS - MIN_BIAS) * biasStrength + MIN_BIAS;

    float bias = (MAX_BIAS - MIN_BIAS) * dot(fragPos - vCamera, vCameraForward) / MAX_BIAS_RANGE + MIN_BIAS;

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
        
        // range check & accumulate
        float rangeCheck = smoothstep(0.0, 1.0, SAMPLE_RADIUS / abs(viewFragPos.z - sampleDepth));
        float nearCheck = step(samplePos.z + bias, sampleDepth);
        float farCheck = step(-samplePos.z - FAR_RADIUS + bias, -sampleDepth);
        occlusion += nearCheck * farCheck * rangeCheck;
    }
    occlusion = 1.0 - occlusion / float(MAX_KERNEL_SIZE);

    FragColor = occlusion;
}
___glsl