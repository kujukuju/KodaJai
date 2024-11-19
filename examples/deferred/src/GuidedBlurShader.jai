
// TODO you know... maybe this is just a bilateral blur? I'm not sure...
guided_blur_shader := #run create_shader(GUIDED_BLUR_VERTEX_SHADER, GUIDED_BLUR_FRAGMENT_SHADER);

#scope_module

GUIDED_BLUR_VERTEX_SHADER :: #string ___glsl
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

GUIDED_BLUR_FRAGMENT_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) out float FragColor;

// const float OFFSETS[4] = float[](-1.5, -0.5, 0.5, 1.5);

const float gaussianWeights[25] = float[](0.3678794411714422, 0.5352614285189902, 0.6065306597126334, 0.5352614285189902, 0.3678794411714422, 0.5352614285189902, 0.7788007830714048, 0.8824969025845955, 0.7788007830714048, 0.5352614285189902, 0.6065306597126334, 0.8824969025845955, 1, 0.8824969025845955, 0.6065306597126334, 0.5352614285189902, 0.7788007830714048, 0.8824969025845955, 0.7788007830714048, 0.5352614285189902, 0.3678794411714422, 0.5352614285189902, 0.6065306597126334, 0.5352614285189902, 0.3678794411714422);

uniform mat4 view;
uniform mat4 projection;

uniform sampler2D uPosition;
uniform sampler2D uSSAO;

in vec2 vCoord;
in vec3 vCamera;
in vec3 vCameraForward;

float gaussian(float x, float sigma) {
    return exp(-(x * x) / (2.0 * sigma * sigma));
}

float depthWeight(float depthDifference, float depthThreshold) {
    return exp(-depthDifference / depthThreshold);
}

// 1.245679

void main() {
    // vec2 pixelSize = 1.0 / textureSize(uSSAO, 0);

    // float sum = 0.0;
    // for (int y = -2; y <= 2; y++) {
    //     for (int x = -2; x <= 2; x++) {
    //         vec2 offset = vec2(float(x), float(y)) * pixelSize * 0.5;

    //         sum += texture(uSSAO, vCoord + offset).r;
    //     }
    // }
    // sum /= 25.0;

    // FragColor = sum;

    float fragDepth = dot(vCamera - texture(uPosition, vCoord).rgb, vCameraForward);

    // FragColor = texture(uSSAO, vCoord).r;

    vec2 ssaoDimensions = textureSize(uSSAO, 0);

    float accSSAO = 0.0;
    float accWeight = 0.0;
    int index = 0;
    for (int y = -2; y <= 2; y++) {
        for (int x = -2; x <= 2; x++) {
            vec2 spatialDelta = vec2(float(x), float(y));

            // TODO using both dimensions you would end up with different texcoords with different sizes...
            vec2 ssaoCoord = vCoord + spatialDelta / ssaoDimensions;

            float neighborDepth = dot(vCamera - texture(uPosition, ssaoCoord).rgb, vCameraForward);
            float depthDifference = abs(fragDepth - neighborDepth);

            float wSpatial = gaussianWeights[index++];
            float wDepth = depthWeight(depthDifference, 0.02);

            float weight = wSpatial * wDepth;

            accSSAO += texture(uSSAO, ssaoCoord).r * weight;
            accWeight += weight;
        }
    }

    if (accWeight < 0.00001) {
        accWeight = 0.00001;
    }

    FragColor = accSSAO / accWeight;
    // FragColor = texture(uSSAO, vCoord).r;
}
___glsl