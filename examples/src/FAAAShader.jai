
// fast adaptive anti aliasing
FAAAShader :: struct {
    using #as shader: Shader;

    shader.vertex = FAAA_VERTEX_SHADER;
    shader.fragment = FAAA_FRAGMENT_SHADER;
}

faaa_shader: FAAAShader;

#scope_module

FAAA_VERTEX_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) in vec2 aPos;

out vec2 vCoord;

void main() {
    vCoord = aPos * vec2(0.5, 0.5) + 0.5;

    gl_Position = vec4(aPos, 0.0, 1.0);
}
___glsl

FAAA_FRAGMENT_SHADER :: #string ___glsl
#version 330 core

layout (location = 0) out vec4 FragColor;

// higher value is higher quality
// 1 to 9
#ifndef FXAA_QUALITY
    #define FXAA_QUALITY 9
#endif

// higher values result in more edges being detected and smoothed
// 1.0 to 9.0
#ifndef FXAA_EDGE_THRESHOLD
	#define FXAA_EDGE_THRESHOLD 8.0
#endif

// shows detected edges
// note that how detected edges are processed varies
#ifndef FXAA_SHOW_EDGES
	#define FXAA_SHOW_EDGES 0
#endif

// TODO unused... if I disable this I would be allowed to use textureGather
// if we should compute the luma value or get it from the alpha channel
#ifndef FXAA_COMPUTE_LUMA
    #define FXAA_COMPUTE_LUMA 1
#endif

#if FXAA_COMPUTE_LUMA
    // #define EDGES vec3(0.0, 1.0, 0.0)
#elif
    #if __VERSION__ >= 400
        #define FXAA_GATHER 1
    // TODO does this work? I should check it somehow by updating my glsl language version?
    // #elif __VERSION >= 130
        // #extension GL_ARB_texture_gather : enable
    #endif

    // #define EDGES vec4(0.0, 1.0, 0.0, lumaM)
#endif

#ifndef FXAA_GATHER
    #define FXAA_GATHER 0
#endif

#define OFFSET_S ivec2(0, 1)
#define OFFSET_E ivec2(1, 0)
#define OFFSET_N ivec2(0, -1)
#define OFFSET_W ivec2(-1, 0)
#define OFFSET_SW ivec2(-1, 1)
#define OFFSET_SE ivec2(1, 1)
#define OFFSET_NE ivec2(1, -1)
#define OFFSET_NW ivec2(-1, -1)

// from fxaa3 quality version low dither settings
#if (FXAA_QUALITY == 1)
	#define FXAA_QUALITY_PI 4
	#define FXAA_QUALITY_P3 8.0
#endif
#if (FXAA_QUALITY == 2)
	#define FXAA_QUALITY_PI 5
	#define FXAA_QUALITY_P4 8.0
#endif
#if (FXAA_QUALITY == 3)
	#define FXAA_QUALITY_PI 6
	#define FXAA_QUALITY_P5 8.0
#endif
#if (FXAA_QUALITY == 4)
	#define FXAA_QUALITY_PI 7
	#define FXAA_QUALITY_P5 3.0
	#define FXAA_QUALITY_P6 8.0
#endif
#if (FXAA_QUALITY == 5)
	#define FXAA_QUALITY_PI 8
	#define FXAA_QUALITY_P6 4.0
	#define FXAA_QUALITY_P7 8.0
#endif
#if (FXAA_QUALITY == 6)
	#define FXAA_QUALITY_PI 9
	#define FXAA_QUALITY_P7 4.0
	#define FXAA_QUALITY_P8 8.0
#endif
#if (FXAA_QUALITY == 7)
	#define FXAA_QUALITY_PI 10
	#define FXAA_QUALITY_P8 4.0
	#define FXAA_QUALITY_P9 8.0
#endif
#if (FXAA_QUALITY == 8)
	#define FXAA_QUALITY_PI 11
	#define FXAA_QUALITY_P9 4.0
	#define FXAA_QUALITY_P10 8.0
#endif
#if (FXAA_QUALITY == 9)
	#define FXAA_QUALITY_PI 12
    #define FXAA_QUALITY_P1 1.0
    #define FXAA_QUALITY_P2 1.0
    #define FXAA_QUALITY_P3 1.0
    #define FXAA_QUALITY_P4 1.0
    #define FXAA_QUALITY_P5 1.5
#endif

#define FXAA_QUALITY_P0 1.0
#define FXAA_QUALITY_P11 8.0

// now set the remaining quality settings that haven't already been set based on the opinionated quality
#ifndef FXAA_QUALITY_PI
	#define FXAA_QUALITY_PI 12
#endif
#ifndef FXAA_QUALITY_P1  
	#define FXAA_QUALITY_P1 1.5 
#endif
#ifndef FXAA_QUALITY_P2  
	#define FXAA_QUALITY_P2 2.0 
#endif
#ifndef FXAA_QUALITY_P3  
	#define FXAA_QUALITY_P3 2.0 
#endif
#ifndef FXAA_QUALITY_P4  
	#define FXAA_QUALITY_P4 2.0 
#endif
#ifndef FXAA_QUALITY_P5  
	#define FXAA_QUALITY_P5 2.0 
#endif
#ifndef FXAA_QUALITY_P6  
	#define FXAA_QUALITY_P6 2.0 
#endif
#ifndef FXAA_QUALITY_P7  
	#define FXAA_QUALITY_P7 2.0 
#endif
#ifndef FXAA_QUALITY_P8  
	#define FXAA_QUALITY_P8 2.0 
#endif
#ifndef FXAA_QUALITY_P9  
	#define FXAA_QUALITY_P9 2.0 
#endif
#ifndef FXAA_QUALITY_P10  
	#define FXAA_QUALITY_P10 4.0 
#endif

const float OFFSET_MUL[12] = float[](FXAA_QUALITY_P0, FXAA_QUALITY_P1,
	FXAA_QUALITY_P2, FXAA_QUALITY_P3, FXAA_QUALITY_P4, FXAA_QUALITY_P5,
	FXAA_QUALITY_P6, FXAA_QUALITY_P7, FXAA_QUALITY_P8, FXAA_QUALITY_P9,
	FXAA_QUALITY_P10, FXAA_QUALITY_P11);

const float edgeThreshold = (10.0 - FXAA_EDGE_THRESHOLD) * 0.0625;

uniform sampler2D uColor;

in vec2 vCoord;

// TODO can this be removed to reuse samples instead of calling it every time you want a color?
vec3 sampleColor(vec2 coord) {
    return texture(uColor, coord).rgb;
}

vec3 sampleColorOffset(vec2 coord, ivec2 offset) {
    return textureOffset(uColor, coord, offset).rgb;
}

#if FXAA_COMPUTE_LUMA
    float getLuma(vec3 color) {
        return dot(color, vec3(0.299, 0.587, 0.114));
    }

    float sampleLuma(vec2 coord) {
        return getLuma(sampleColor(coord));
    }

    float sampleLumaOffset(vec2 coord, ivec2 offset) {
        return getLuma(sampleColorOffset(coord, offset));
    }
#else
    float sampleLuma(vec2 coord) {
        return texture(uColor, coord).a;
    }

    float sampleLumaOffset(vec2 coord, ivec2 offset) {
        return textureOffset(uColor, coord, offset).a;
    }
#endif

#if FXAA_GATHER
    vec4 gatherLuma(vec2 coord) {
        return textureGather(uColor, coord, 3);
    }

    vec4 gatherLumaOffset(vec2 coord, ivec2 offset) {
        return textureGather(uColor, coord, offset, 3);
    }
#endif

void main() {
    vec2 bufferSize = textureSize(uColor, 0);
    vec2 pixelSize = 1.0 / bufferSize;

    #if FXAA_GATHER
        vec4 lumaDP = gatherLuma(vCoord);
        vec4 lumaDN = gatherLumaOffset(vCoord, OFFSET_NW);
        #define lumaSE lumaDP.y
        #define lumaNW lumaDN.w
    #else
        float lumaSE = sampleLumaOffset(vCoord, OFFSET_SE);
        float lumaNW = sampleLumaOffset(vCoord, OFFSET_NW);
    #endif

    float lumaSW = sampleLumaOffset(vCoord, OFFSET_SW);
	float lumaNE = sampleLumaOffset(vCoord, OFFSET_NE);

    // edge detection which is better than a luma delta
    float gradientSWNE = lumaSW - lumaNE;
	float gradientSENW = lumaSE - lumaNW;
	vec2 dirM;
	dirM.x = abs(gradientSWNE + gradientSENW);
	dirM.y = abs(gradientSWNE - gradientSENW);

	float lumaMax = max(max(lumaSW, lumaSE), max(lumaNE, lumaNW));
	float localLumaFactor = lumaMax * 0.5 + 0.5;
	float localThres = edgeThreshold * localLumaFactor;
	bool lowDelta = abs(dirM.x - dirM.y) < localThres;

    #if FXAA_SHOW_EDGES
        if (lowDelta) {
            FragColor = vec4(vec3(sampleLuma(vCoord) * 0.9), 1.0);
            return;
        } else {
            FragColor = vec4(0.0, 1.0, 0.0, 1.0);
            return;
        }
    #else
        if (lowDelta) {
            FragColor = vec4(sampleColor(vCoord), 1.0);
            return;
        }
    #endif

    bool horzSpan = dirM.x > dirM.y;

    #if FXAA_GATHER
        float lumaM = lumaDP.w;
        float lumaN = lumaDN.z;
        float lumaS = lumaDP.x;
        if (!horzSpan) lumaN = lumaDN.x;
        if (!horzSpan) lumaS = lumaDP.z;
    #else
        float lumaM = sampleLuma(vCoord);
        float lumaN, lumaS;
        if (horzSpan) lumaN = sampleLumaOffset(vCoord, OFFSET_N);
        if (horzSpan) lumaS = sampleLumaOffset(vCoord, OFFSET_S);
        if (!horzSpan) lumaN = sampleLumaOffset(vCoord, OFFSET_W);
        if (!horzSpan) lumaS = sampleLumaOffset(vCoord, OFFSET_E);
    #endif

    float gradientN = lumaN - lumaM;
	float gradientS = lumaS - lumaM;

    bool pairN = abs(gradientN) > abs(gradientS);

    float gradient = abs(gradientN);
	if (!pairN) gradient = abs(gradientS);
	float gradientScaled = gradient * 0.25;

    float lumaNN = lumaN + lumaM;
	if (!pairN) lumaNN = lumaS + lumaM;
	float lumaMN = lumaNN * 0.5;

	float lengthSign = pixelSize.y;
	if(!horzSpan) lengthSign = pixelSize.x;
	if (pairN) lengthSign = -lengthSign;

    vec2 posN = vCoord;
	if (!horzSpan) posN.x += lengthSign * 0.5;
	if (horzSpan) posN.y += lengthSign * 0.5;
	vec2 posP = posN;
	vec2 offNP = pixelSize;
	if (!horzSpan) offNP.x = 0;
	if (horzSpan) offNP.y = 0;

    int i = 0;
	posP += offNP * OFFSET_MUL[i];
	posN -= offNP * OFFSET_MUL[i];
	float lumaEndP = sampleLuma(posP);
	float lumaEndN = sampleLuma(posN);
	lumaEndP -= lumaMN;
	lumaEndN -= lumaMN;
	bool doneP = abs(lumaEndP) > gradientScaled;
	bool doneN = abs(lumaEndN) > gradientScaled;

    while (++i < FXAA_QUALITY_PI) {
		if (!doneP) {
			posP += offNP * OFFSET_MUL[i];
			lumaEndP = sampleLuma(posP);
			lumaEndP -= lumaMN;
			doneP = abs(lumaEndP) > gradientScaled;
		}
		if (!doneN) {
			posN -= offNP * OFFSET_MUL[i];
			lumaEndN = sampleLuma(posN);
			lumaEndN -= lumaMN;
			doneN = abs(lumaEndN) > gradientScaled;
		}

		if (doneN && doneP) break;
	}

    vec2 posM = vCoord;
	float dstN = posM.x - posN.x;
	float dstP = posP.x - posM.x;
	if (!horzSpan) dstN = posM.y - posN.y;
	if (!horzSpan) dstP = posP.y - posM.y;

    bool dstNLTdstP = dstN < dstP;
	bool lumaMLTZero = lumaM - lumaMN < 0;
	bool mSpanLTZero = dstNLTdstP ? lumaEndN < 0 : lumaEndP < 0;
	bool goodSpan = mSpanLTZero != lumaMLTZero;

    float dst = dstNLTdstP ? dstN : dstP;
	float spanLength = dstP + dstN;
	float pixelOffset = (-dst / spanLength) + 0.5;

	bool pixelOffsetLTZero = pixelOffset < 0;
	if (pixelOffsetLTZero || !goodSpan) {
        FragColor = vec4(sampleColor(vCoord), 1.0);
        return;
    }

	if (!horzSpan) posM.x += pixelOffset * lengthSign;
	if (horzSpan) posM.y += pixelOffset * lengthSign;

    #if FXAA_COMPUTE_LUMA
        FragColor = vec4(sampleColor(posM), 1.0);
    #elif
        FragColor = vec4(sampleColor(posM).rgb, 1.0);
    #endif

    // FragColor = texture(uColor, vCoord);
}
___glsl