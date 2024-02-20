AmbientOcclusionShader :: struct {
    using #as shader: Shader;

    shader.vertex = AMBIENT_OCCLUSION_VERTEX_SHADER;
    shader.fragment = AMBIENT_OCCLUSION_FRAGMENT_SHADER;
}

#scope_module

AMBIENT_OCCLUSION_VERTEX_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) in vec2 aPos;

out vec2 vCoord;

void main() {
    vCoord = aPos * vec2(0.5, 0.5) + 0.5;

    gl_Position = vec4(aPos, 0.0, 1.0);
}
___glsl

AMBIENT_OCCLUSION_FRAGMENT_SHADER :: #string ___glsl
#version 330 core

// TODO 64 kernel only
const int MAX_KERNEL_SIZE = 64;
const float SAMPLE_RADIUS = 0.5;
const float BIAS = 0.025;

layout (location = 0) out vec4 FragColor;

uniform mat4 view;
uniform mat4 projection;

uniform sampler2D uPosition;
uniform sampler2D uNormal;
// uniform sampler2D uDepth;
uniform sampler2D uNoise;

uniform vec3 uKernel[MAX_KERNEL_SIZE];
uniform vec2 uNoiseScale;

in vec2 vCoord;

// float linearizeDepth(float depth) {
//     float far = gl_DepthRange.far;
//     float near = gl_DepthRange.near;

//     return (2.0 * near * far) / (far + near - depth * (far - near));    
// }

vec3 getPositionFromDepth(vec2 coords, float depth) {
    // reconstruct the clip space position
    vec4 clipSpacePosition = vec4(coords * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    // convert to view space
    vec4 viewSpacePosition = inverse(projection) * clipSpacePosition;
    // perspective divide
    return viewSpacePosition.xyz / viewSpacePosition.w;
}

void main() {
    vec2 coords = vCoord;

    // get input for SSAO algorithm
    vec3 fragPos = vec3(view * vec4(texture(uPosition, coords).xyz, 1.0));
    vec3 normal = normalize(texture(uNormal, coords).rgb);
    vec3 randomVec = normalize(texture(uNoise, coords * uNoiseScale).xyz);
    // create TBN change-of-basis matrix: from tangent-space to view-space
    vec3 tangent = normalize(randomVec - normal * dot(randomVec, normal));
    vec3 bitangent = cross(normal, tangent);
    mat3 TBN = mat3(tangent, bitangent, normal);

    float occlusion = 0.0;
    for (int i = 0; i < MAX_KERNEL_SIZE; i++) {
        // get sample position
        vec3 samplePos = TBN * uKernel[i]; // from tangent to view-space
        samplePos = fragPos + samplePos * SAMPLE_RADIUS; 
        
        // project sample position (to sample texture) (to get position on screen/texture)
        vec4 offset = vec4(samplePos, 1.0);
        offset = projection * offset; // from view to clip-space
        offset.xyz /= offset.w; // perspective divide
        offset.xyz = offset.xyz * 0.5 + 0.5; // transform to range 0.0 - 1.0
        
        // get sample depth
        float sampleDepth = vec3(view * vec4(texture(uPosition, offset.xy).rgb, 1.0)).z; // get depth value of kernel sample
        
        // range check & accumulate
        float rangeCheck = smoothstep(0.0, 1.0, SAMPLE_RADIUS / abs(fragPos.z - sampleDepth));
        occlusion += (sampleDepth >= samplePos.z + BIAS ? 1.0 : 0.0) * rangeCheck;
    }
    occlusion = 1.0 - occlusion / float(MAX_KERNEL_SIZE);

    FragColor = vec4(vec3(occlusion), 1.0);







	// vec3 position = texture(uPosition, coords).xyz;
	// float depth = texture(uDepth, coords).r;
    // depth = linearizeDepth(depth);
    // vec3 position = getPositionFromDepth(coords, depth);

    // float ao = 0.0;
    // for (int i = 0; i < MAX_KERNEL_SIZE; i++) {
    //     // sample position
    //     vec3 samplePos = position + uKernel[i] * uSampleRadius;
    //     // project sample position (from view to clip space) and then to texture coordinates
    //     vec4 offset = projection * vec4(samplePos, 1.0);
    //     offset.xy /= offset.w;
    //     offset.xy = offset.xy * 0.5 + 0.5;
    //     // get sample depth
    //     float sampleDepth = texture(uDepth, offset.xy).r;
    //     sampleDepth = linearizeDepth(sampleDepth);
    //     // range check and accumulate
    //     float rangeCheck = smoothstep(0.0, 1.0, uSampleRadius / abs(position.z - sampleDepth));
    //     ao += (sampleDepth >= samplePos.z ? 1.0 : 0.0) * rangeCheck;
    // }

    // float ao = 0.0;
    // for (int i = 0; i < MAX_KERNEL_SIZE; i++) {
    //     vec3 samplePos = position; // generate a random point
    //     vec4 offset = vec4(samplePos, 1.0); // make it a 4-vector
    //     offset = projection * offset; // project on the near clipping plane
    //     offset.xy /= offset.w; // perform perspective divide
    //     offset.xy = offset.xy * 0.5 + vec2(0.5); // transform to (0,1) range

    //     float sampleDepth = texture(uPosition, offset.xy).z;

    //     if (abs(position.z - sampleDepth) < uSampleRadius) {
    //         ao += step(sampleDepth, samplePos.z);
    //     }
    // }

    // ao = 1.0 - ao / 128.0;
    // ao = 1.0 - ao / float(MAX_KERNEL_SIZE);

    // FragColor = vec4(pow(ao, 2.0));
    // FragColor = vec4(vec3(pow(ao, 2.0)), 1.0);
    // FragColor = vec4(vec3(depth), 1.0);
}
___glsl