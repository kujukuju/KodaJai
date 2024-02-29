//======================================================================
//
//	Deferred MSAA Sample
//  by MJP
//  http://mynameismjp.wordpress.com/
//
//  All code and content licensed under Microsoft Public License (Ms-PL)
//
//======================================================================

#include "SampleFramework11/Shaders/PPIncludes.hlsl"

// Parameters for post processing
cbuffer PPConstants : register(b1)
{
    float BloomThreshold : packoffset(c0.x);
    float BloomMagnitude : packoffset(c0.y);
    float BloomBlurSigma : packoffset(c0.z);
    float Tau : packoffset(c0.w);
    float TimeDelta : packoffset(c1.x);
    float KeyValue : packoffset(c1.y);
	float EdgeThreshold : packoffset(c1.z);
	float VisualizeEdges : packoffset(c1.w);
	float ProjectionA : packoffset(c2.x);
	float ProjectionB : packoffset(c2.y);
	uint UseMultipleSamples : packoffset(c2.z);
};

// ------------------------------------------------------------------------------------------------
// Helper Functions
// ------------------------------------------------------------------------------------------------

// Approximates luminance from an RGB value
float CalcLuminance(float3 color)
{
    return max(dot(color, float3(0.299f, 0.587f, 0.114f)), 0.0001f);
}

// Retrieves the log-average luminance from the texture
float GetAvgLuminance(Texture2D lumTex, float2 texCoord)
{
	return exp(lumTex.SampleLevel(LinearSampler, texCoord, 10).x);
}

// Applies the filmic curve from John Hable's presentation
float3 ToneMapFilmicALU(float3 color)
{
    color = max(0, color - 0.004f);
    color = (color * (6.2f * color + 0.5f)) / (color * (6.2f * color + 1.7f)+ 0.06f);

    // result has 1/2.2 baked in
    return pow(color, 2.2f);
}

// Determines the color based on exposure settings
float3 CalcExposedColor(float3 color, float avgLuminance, float threshold, out float exposure)
{	
	// Use geometric mean
	avgLuminance = max(avgLuminance, 0.001f);
	float keyValue = KeyValue;
	float linearExposure = (KeyValue / avgLuminance);
	exposure = log2(max(linearExposure, 0.0001f));
    exposure -= threshold;
    return exp2(exposure) * color;
}

// Applies exposure and tone mapping to the specific color, and applies
// the threshold to the exposure value.
float3 ToneMap(float3 color, float avgLuminance, float threshold, out float exposure)
{
    float pixelLuminance = CalcLuminance(color);
    color = CalcExposedColor(color, avgLuminance, threshold, exposure);
	color = ToneMapFilmicALU(color);
    return color;
}

// Calculates the gaussian blur weight for a given distance and sigmas
float CalcGaussianWeight(int sampleDist, float sigma)
{
	float g = 1.0f / sqrt(2.0f * 3.14159 * sigma * sigma);
	return (g * exp(-(sampleDist * sampleDist) / (2 * sigma * sigma)));
}

// Performs a gaussian blue in one direction
float4 Blur(in PSInput input, float2 texScale, float sigma)
{
    float4 color = 0;
    for (int i = -6; i < 6; i++)
    {
		float weight = CalcGaussianWeight(i, sigma);
        float2 texCoord = input.TexCoord;
		texCoord += (i / InputSize0) * texScale;
		float4 sample = InputTexture0.Sample(PointSampler, texCoord);
		color += sample * weight;
    }

    return color;
}

// ================================================================================================
// Shader Entry Points
// ================================================================================================

// Uses a lower exposure to produce a value suitable for a bloom pass
float4 Threshold(in PSInput input) : SV_Target
{
    float3 color = 0;

    color = InputTexture0.Sample(LinearSampler, input.TexCoord).rgb;

    // Tone map it to threshold
    float avgLuminance = GetAvgLuminance(InputTexture1, input.TexCoord);
	float exposure = 0;
    color = ToneMap(color, avgLuminance, BloomThreshold, exposure);
    return float4(color, 1.0f);
}

// Uses hw bilinear filtering for upscaling or downscaling
float4 Scale(in PSInput input) : SV_Target
{
    return InputTexture0.Sample(LinearSampler, input.TexCoord);
}

// Horizontal gaussian blur
float4 BloomBlurH(in PSInput input) : SV_Target
{
    return Blur(input, float2(1, 0), BloomBlurSigma);
}

// Vertical gaussian blur
float4 BloomBlurV(in PSInput input) : SV_Target
{
    return Blur(input, float2(0, 1), BloomBlurSigma);
}

// Applies exposure and tone mapping to the input, and combines it with the
// results of the bloom pass
float4 Composite(in PSInput input) : SV_Target0
{
    // Tone map the primary input
    float avgLuminance = GetAvgLuminance(InputTexture1, input.TexCoord);
    float3 color = InputTexture0.Sample(PointSampler, input.TexCoord).rgb;
    float exposure = 0;
	color = ToneMap(color, avgLuminance, 0, exposure);

    // Sample the bloom
    float3 bloom = InputTexture2.Sample(LinearSampler, input.TexCoord).rgb;
    bloom = bloom * BloomMagnitude;

    // Add in the bloom
	color = color + bloom;

    return float4(color, 1.0f);
}

// Creates the luminance map for the scene
float4 LuminanceMap(in PSInput input) : SV_Target
{
    // Sample the input
    float3 color = InputTexture0.Sample(LinearSampler, input.TexCoord).rgb;

    // calculate the luminance using a weighted average
    float luminance = CalcLuminance(color);

    return float4(luminance, 1.0f, 1.0f, 1.0f);
}

// Slowly adjusts the scene luminance based on the previous scene luminance
float4 AdaptLuminance(in PSInput input) : SV_Target
{
    float lastLum = exp(InputTexture0.Sample(PointSampler, input.TexCoord).x);
    float currentLum = InputTexture1.Sample(PointSampler, input.TexCoord).x;

    // Adapt the luminance using Pattanaik's technique
    float adaptedLum = lastLum + (currentLum - lastLum) * (1 - exp(-TimeDelta * Tau));

    return float4(log(adaptedLum), 1.0f, 1.0f, 1.0f);
}

Texture2DMS<float> MSDepth : register(t1);

// Converts post-projection z/w to linear z
float LinearDepth(float perspectiveDepth)
{
	return ProjectionB / (perspectiveDepth - ProjectionA);
}

// Applies the AA pass
float4 ApplyAA(in PSInput input) : SV_Target
{
	// Sample the regular depth buffer. We convert to linear depth before comparing, so that
	// our threshold is uniform across the entire depth range.
	int2 sampleLocation = int2(input.PositionSS.xy);
	float depth = LinearDepth(InputTexture2.Sample(PointSampler, input.TexCoord).x);
		
	// Standard DX11 4xMSAA pattern
	static const float2 SamplePoints[] = 
	{
		float2(0.380f, 0.141f),
		float2(0.859f, 0.380f),
		float2(0.141f, 0.620f),
		float2(0.620f, 0.859f)			
	};
	
	// Sample the input
    float3 inputColor = InputTexture0.Sample(PointSampler, input.TexCoord).rgb;	
	
	float3 outputColor = 0;
	if (UseMultipleSamples)
	{
		// Loop through the MSAA samples and compare with the non-MSAA depth		
		for (int i = 0; i < 4; ++i)
		{
			float msDepth = LinearDepth(MSDepth.Load(sampleLocation, i));		
			if(abs(depth - msDepth) < EdgeThreshold)
				outputColor += inputColor;
			else
			{	
				// Take a new sample for each MSAA depth sample that doesn't match
				float2 samplePoint = input.PositionSS.xy  + (SamplePoints[i] - float2(0.5f, 0.5f)) * 2;
				float2 sampleCoord = samplePoint / InputSize0;
				if (VisualizeEdges)
					outputColor += float3(100, 0, 0);
				else
					outputColor += InputTexture0.Sample(LinearSampler, sampleCoord).rgb;			
			}		
		}

		outputColor /= 4;
	}
	else
	{
		// Loop through the MSAA samples and compare with the non-MSAA depth	
		float2 sampleOffset = 0;
		float sampleWeight = 0;
		for (int i = 0; i < 4; ++i)
		{
			float msDepth = LinearDepth(MSDepth.Load(sampleLocation, i));			
			if(abs(depth - msDepth) >= EdgeThreshold)
			{
				// Try to come up with a good sample point based on the coverage
				sampleOffset += (SamplePoints[i] - float2(0.5f, 0.5f)) * 2;
				++sampleWeight;
			}
		}	
		
		// Take a single sample, and lerp based on coverage
		sampleOffset /= max(sampleWeight, 0.1f);
		float2 sampleCoord = input.PositionSS.xy  + sampleOffset;
		sampleCoord /= InputSize0;
		float3 sampleColor = InputTexture0.Sample(LinearSampler, sampleCoord).rgb;
		outputColor = lerp(inputColor, sampleColor, sampleWeight / 4);

		if (VisualizeEdges && sampleWeight > 0)
			outputColor = float3(1, 0, 0);
	}
	
    return float4(outputColor, 1.0f);
}