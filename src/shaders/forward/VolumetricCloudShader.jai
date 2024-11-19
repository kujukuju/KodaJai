
volumetric_cloud_shader := #run create_shader(VOLUMETRIC_CLOUD_VERTEX_SHADER3, VOLUMETRIC_CLOUD_FRAGMENT_SHADER3);

#scope_module

VOLUMETRIC_CLOUD_VERTEX_SHADER3 :: #string DONE
#version 330 core
layout (location = 0) in vec3 aPos;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

uniform vec3 uCloudDimensions;

out vec3 vCamera;
out vec3 vPos;
out vec3 vStartCoord;
// TODO I could do a vEndCoord

void main() {
    // this is the camera in model space
    // model space is from -1 -1 -1 to 1 1 1
    vCamera = (inverse(model) * inverse(view) * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    // this is the fragment position in model space
    vPos = aPos;
    // this is the 
    vStartCoord = aPos / 2.0 + 0.5;

    // TODO calculate this using the clipping plane not the camera position
    if (vCamera.x >= -1.0 && vCamera.y >= -1.0 && vCamera.z >= -1.0 && vCamera.x <= 1.0 && vCamera.y <= 1.0 && vCamera.z <= 1.0) {
        vStartCoord = vCamera / 2.0 + 0.5;
    } else {
        vec3 clipPadding = 3.0 / uCloudDimensions;
        vec3 clip = clipPadding + 1.0;
        if (vCamera.x >= -clip.x && vCamera.y >= -clip.y && vCamera.z >= -clip.z && vCamera.x <= clip.x && vCamera.y <= clip.y && vCamera.z <= clip.z) {
            vStartCoord = vCamera / 2.0 + 0.5;
        }
    }

    gl_Position = projection * view * model * vec4(aPos, 1.0);
}
DONE

// TODO I need to start the camera position at the cube intersection if I'm outside the cube
// TODO and if you start inside the cube you need to do math to project your position back to the starting point and round to the nearest point of where you are

VOLUMETRIC_CLOUD_FRAGMENT_SHADER3 :: #string ___glsl
#version 330 core
out vec4 FragColor;

uniform mat4 view;

uniform vec3 uCloudDimensions;
uniform sampler3D uNoiseTexture;
uniform float uTime;

in vec3 vCamera;
in vec3 vPos;
in vec3 vStartCoord;

#define PI 3.1415926535897932384626433832795

const float DUAL_LOBE_WEIGHT = 0.7;
const float CLOUD_EXPOSURE = 2.0;
const float CLOUD_DENSITY = 4.0;
const float CLOUD_BASE_STRENGTH = 0.8;
// lower this value for more solid colored cartoony effect
const float CLOUD_DETAIL_STRENGTH = 0.2;
const float ABSORPTION = 2.0;
const float CLOUD_LIGHT_MULTIPLIER = 4.0;
const vec3 LIGHT_COLOR = vec3(255.0 / 255.0, 239.0 / 255.0, 202.0 / 255.0);
const vec3 CLOUD_COLOR = vec3(1.0, 1.0, 1.0) * 1.0;
const float CLOUD_FALLOFF = 0.4;
const vec3 LIGHT_DIR = vec3(-0.5 / 2.25, -1.0 / 2.25, 1.0 / 2.25);
const float STEPS = 20.0;
const float LIGHT_STEPS = 8.0;
const float EXTINCTION_MULT = 0.8;
const float AMBIENT_STRENGTH = 0.2;

struct ScatteringTransmittance {
  vec3 scattering;
  float transmittance;
};

float henyeyGreenstein(float g, float mu) {
    float gg = g * g;
	return (1.0 / (4.0 * PI))  * ((1.0 - gg) / pow(1.0 + gg - 2.0 * g * mu, 1.5));
}

float dualHenyeyGreenstein(float g, float costh) {
    return mix(henyeyGreenstein(-g, costh), henyeyGreenstein(g, costh), DUAL_LOBE_WEIGHT);
}

float phaseFunction(float g, float costh) {
    return dualHenyeyGreenstein(g, costh);
}

float linearstep(float minValue, float maxValue, float v) {
    return clamp((v - minValue) / (maxValue - minValue), 0.0, 1.0);
}

float lerp(float a, float b, float t) {
    return a + (b - a) * t;
}

float inverseLerp(float a, float b, float t) {
    return (t - a) / (b - a);
}

float remap(float v, float inMin, float inMax, float outMin, float outMax) {
    float t = inverseLerp(inMin, inMax, v);
    return lerp(outMin, outMax, t);
}

float saturate(float a) {
    return clamp(a, 0.0, 1.0);
}

vec3 saturate(vec3 a) {
    return clamp(a, vec3(0.0), vec3(1.0));
}

float circularOut(float t) {
    return sqrt((2.0 - t) * t);
}

float cbrtf(float x) {
    return pow(x, 1.0 / 3.0);
}

vec3 rgbToOklab(vec3 c) 
{
    float l = 0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b;
	float m = 0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b;
	float s = 0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b;

    float l_ = cbrtf(l);
    float m_ = cbrtf(m);
    float s_ = cbrtf(s);

    return vec3(
        0.2104542553*l_ + 0.7936177850*m_ - 0.0040720468*s_,
        1.9779984951*l_ - 2.4285922050*m_ + 0.4505937099*s_,
        0.0259040371*l_ + 0.7827717662*m_ - 0.8086757660*s_
    );
}

vec3 oklabToRGB(vec3 c) {
    float l_ = c.x + 0.3963377774 * c.y + 0.2158037573 * c.z;
    float m_ = c.x - 0.1055613458 * c.y - 0.0638541728 * c.z;
    float s_ = c.x - 0.0894841775 * c.y - 1.2914855480 * c.z;

    float l = l_ * l_ * l_;
    float m = m_ * m_ * m_;
    float s = s_ * s_ * s_;

    return vec3(
        +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    );
}

float sphereGradient(vec3 coord) {
    coord = (coord - 0.5) * 2.0;
    float radius = min(length(coord), 1.0);
    float alpha = 1.0 - max(radius - 0.9, 0.0) / 0.1;
    return alpha;
}

float cubeGradient(vec3 coord) {
    coord = 1.0 - abs((coord - 0.5) * 2.0);
    return pow(min(coord.x, min(coord.y, coord.z)), 2.0);
}

float cubeSdf(vec3 coord) {
    float sdf = cubeGradient(coord);
    return circularOut(linearstep(0.0, CLOUD_FALLOFF, sdf)) * 0.85;
}

// TODO I should step through this cloud based on the fragments distance to the camera and then multiple the density by the length of the step
// this would prevent far away clouds from costing a lot of resources and keep up close clouds high quality, even if they span really deep, because
// the step in that case would be like logarithmic or something

vec3 getSampleOffset() {
    return vec3(uTime / 10000.0, uTime / 10000.0, -uTime / 10000.0) * 0.5;
}

float sampleHighDefCloud(vec3 coord) {
    // TODO do detail distance dropoff I guess
    // vec3 worldPosition = vec4(coord * 2.0 - 1.0, 1.0);

    float cloud = cubeSdf(coord);

    float shapeSize = 0.4;
    float lowDefPerlinWorleySample = texture(uNoiseTexture, coord * shapeSize).r;
    cloud = saturate(remap(cloud, CLOUD_BASE_STRENGTH * lowDefPerlinWorleySample, 1.0, 0.0, 1.0));

    if (cloud > 0.0) {
        // float distanceToSample = 0.0;
        // float detailDropout = smoothstep(1000.0, 800.0, distToSample);

        const float detailSize = 1.8 * 0.5;
        float detailStrength = CLOUD_DETAIL_STRENGTH;
        vec3 highDefCoord = coord + getSampleOffset();
        float highDefPerlinWorleySample = texture(uNoiseTexture, highDefCoord * detailSize).g;
        cloud = saturate(remap(cloud, detailStrength * highDefPerlinWorleySample, 1.0, 0.0, 1.0));
    }

    return cloud * CLOUD_DENSITY;
}

float getLightDensity(vec3 coord) {
    vec3 lightStepDir = -LIGHT_DIR / LIGHT_STEPS;
    float lightStepWeight = length(lightStepDir * uCloudDimensions);

    float density = 0.0;
    vec3 current = coord;

    bool exit = false;
    exit = exit || current.x <= 0 && lightStepDir.x < 0;
    exit = exit || current.y <= 0 && lightStepDir.y < 0;
    exit = exit || current.z <= 0 && lightStepDir.z < 0;
    exit = exit || current.x >= 1 && lightStepDir.x > 0;
    exit = exit || current.y >= 1 && lightStepDir.y > 0;
    exit = exit || current.z >= 1 && lightStepDir.z > 0;

    while (!exit) {
        vec3 sample = current + getSampleOffset();
        density += sampleHighDefCloud(current) * lightStepWeight;

        current += lightStepDir;

        exit = exit || current.x <= 0 && lightStepDir.x < 0;
        exit = exit || current.y <= 0 && lightStepDir.y < 0;
        exit = exit || current.z <= 0 && lightStepDir.z < 0;
        exit = exit || current.x >= 1 && lightStepDir.x > 0;
        exit = exit || current.y >= 1 && lightStepDir.y > 0;
        exit = exit || current.z >= 1 && lightStepDir.z > 0;
    }

    return density;
}

// https://twitter.com/FewesW/status/1364629939568451587/photo/1
float multipleOctaveScattering(float density, float mu) {
    float attenuation = 0.2;
    float contribution = 0.2;
    float phaseAttenuation = 0.5;

    float a = 1.0;
    float b = 1.0;
    float c = 1.0;
    float g = 0.85;
    const int scatteringOctaves = 4;
    
    float luminance = 0.0;

    // TODO use ints, right?
    for (int i = 0; i < scatteringOctaves; i++) {
        float phase = phaseFunction(0.3 * c, mu);
        float beers = exp(-density * EXTINCTION_MULT * a);

        luminance += b * phase * beers;

        a *= attenuation;
        b *= contribution;
        c *= (1.0 - phaseAttenuation);
    }

    return luminance;
}

float getLightEnergy(vec3 coord, float mu) {
    float lightDensity = getLightDensity(coord);

    float beersLaw = multipleOctaveScattering(lightDensity, mu);
    float powder = 1.0 - exp(-lightDensity * 2.0 * EXTINCTION_MULT);

	return beersLaw * mix(2.0 * powder, 1.0, remap(mu, -1.0, 1.0, 0.0, 1.0));
}

// TODO I'm not sampling the repeating textures based on dimensions, which I should be

ScatteringTransmittance getCloudScatteringTransmittance() {
    ScatteringTransmittance result;
    result.scattering = vec3(0.0);
    result.transmittance = 1.0;

    vec3 sunLight = LIGHT_COLOR * CLOUD_LIGHT_MULTIPLIER;
    vec3 ambient = AMBIENT_STRENGTH * LIGHT_COLOR;

    vec3 worldCameraDir = normalize((inverse(view) * vec4(0.0, 0.0, -1.0, 0.0)).xyz); // idk if normalization is necessary
    float mu = dot(worldCameraDir, LIGHT_DIR);

    vec3 stepDir = normalize(vPos - vCamera) / STEPS;
    float stepWeight = length(stepDir * uCloudDimensions);

    float density = 0.0;
    vec3 current = vStartCoord;

    bool exit = false;
    exit = exit || current.x <= 0 && stepDir.x < 0;
    exit = exit || current.y <= 0 && stepDir.y < 0;
    exit = exit || current.z <= 0 && stepDir.z < 0;
    exit = exit || current.x >= 1 && stepDir.x > 0;
    exit = exit || current.y >= 1 && stepDir.y > 0;
    exit = exit || current.z >= 1 && stepDir.z > 0;
    while (!exit) {
        bool inside = true;
        inside = inside && current.x >= 0;
        inside = inside && current.y >= 0;
        inside = inside && current.z >= 0;
        inside = inside && current.x <= 1;
        inside = inside && current.y <= 1;
        inside = inside && current.z <= 1;

        if (inside) {
            float extinction = sampleHighDefCloud(current);

            if (extinction > 0.01) {
                vec3 luminance = ambient + sunLight * getLightEnergy(current, mu);
                float transmittance = exp(-extinction * stepWeight * EXTINCTION_MULT);
                vec3 integralScatter = extinction * (luminance - luminance * transmittance) / extinction;

                result.scattering += result.transmittance * integralScatter;
                result.transmittance *= transmittance;

                // TODO abs probably not necessary
                if (abs(result.transmittance) <= 0.01) {
                    result.transmittance = 0.0;
                    break;
                }
            }
        }

        current += stepDir;

        exit = exit || current.x <= 0 && stepDir.x < 0;
        exit = exit || current.y <= 0 && stepDir.y < 0;
        exit = exit || current.z <= 0 && stepDir.z < 0;
        exit = exit || current.x >= 1 && stepDir.x > 0;
        exit = exit || current.y >= 1 && stepDir.y > 0;
        exit = exit || current.z >= 1 && stepDir.z > 0;
    }

    result.scattering = result.scattering * CLOUD_COLOR;
    result.transmittance = saturate(result.transmittance);

    return result;
}

void main() {
    // vec3 worldCameraDir = normalize((inverse(view) * vec4(0.0, 0.0, -1.0, 0.0)).xyz); // idk if normalization is necessary
    // float mu = dot(worldCameraDir, LIGHT_DIR);

    // vec3 stepDir = normalize(vPos - vCamera) / STEPS;
    // float stepWeight = length(stepDir * uCloudDimensions);

    // float density = 0.0;
    // vec3 current = vStartCoord;

    // bool exit = false;
    // exit = exit || current.x <= 0 && stepDir.x < 0;
    // exit = exit || current.y <= 0 && stepDir.y < 0;
    // exit = exit || current.z <= 0 && stepDir.z < 0;
    // exit = exit || current.x >= 1 && stepDir.x > 0;
    // exit = exit || current.y >= 1 && stepDir.y > 0;
    // exit = exit || current.z >= 1 && stepDir.z > 0;
    // while (!exit) {
    //     bool inside = true;
    //     inside = inside && current.x >= 0;
    //     inside = inside && current.y >= 0;
    //     inside = inside && current.z >= 0;
    //     inside = inside && current.x <= 1;
    //     inside = inside && current.y <= 1;
    //     inside = inside && current.z <= 1;

    //     if (inside) {
    //         float lightDensity = getLightDensity(current);
            
    //         density += sampleHighDefCloud(current) * stepWeight;
    //     }

    //     current += stepDir;

    //     exit = exit || current.x <= 0 && stepDir.x < 0;
    //     exit = exit || current.y <= 0 && stepDir.y < 0;
    //     exit = exit || current.z <= 0 && stepDir.z < 0;
    //     exit = exit || current.x >= 1 && stepDir.x > 0;
    //     exit = exit || current.y >= 1 && stepDir.y > 0;
    //     exit = exit || current.z >= 1 && stepDir.z > 0;
    // }

    // float result = 1.0 - exp(-density * ABSORPTION);

    // float result = texture(uNoiseTexture, vStartCoord).r;
    // FragColor = vec4(result, result, result, 1.0);

    ScatteringTransmittance trace = getCloudScatteringTransmittance();

    vec3 color = trace.scattering * CLOUD_EXPOSURE;
    float alpha = 1.0 - trace.transmittance;

    FragColor = vec4(color / alpha, alpha);
}
___glsl
