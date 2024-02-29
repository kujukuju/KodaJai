//======================================================================
//
//	Deferred MSAA Sample
//  by MJP
//  http://mynameismjp.wordpress.com/
//
//  All code and content licensed under Microsoft Public License (Ms-PL)
//
//======================================================================

//======================================================================================
// Constant buffers
//======================================================================================
cbuffer VSConstants : register(cb0)
{
    float4x4 World : packoffset(c0);
    float4x4 WorldViewProjection : packoffset(c4);
}

cbuffer PSSceneConstants : register(cb0)
{
    float3 LightDir : packoffset(c0);
    float3 LightColor : packoffset(c1);
    float3 CameraPosWS : packoffset(c2);
}

//======================================================================================
// Samplers
//======================================================================================
TextureCube	EnvironmentMap : register(t0);
Texture2D DiffuseMap : register(t1);
Texture2D NormalMap : register(t2);
SamplerState AnisoSampler : register(s0);

//======================================================================================
// Input/Output structs
//======================================================================================
struct VSInput
{
    float4 PositionOS : POSITION;
    float3 NormalOS : NORMAL;
    float2 TexCoord : TEXCOORD0;
    float3 TangentOS : TANGENT;
};

struct VSOutput
{
    float4 PositionCS : SV_Position;
    float3 PositionWS : POSITIONWS;
    float3 NormalWS : NORMALWS;
    float3 TangentWS : TANGENTWS;
    float2 TexCoord : TEXCOORD;	
};

struct PSInput
{
    float4 PositionSS : SV_Position;
    float3 PositionWS : POSITIONWS;
    float3 NormalWS : NORMALWS;
    float3 TangentWS : TANGENTWS;
    float2 TexCoord : TEXCOORD;
};

//======================================================================================
// Vertex Shader
//======================================================================================
VSOutput VS(in VSInput input)
{
    VSOutput output;

    // Calc the world-space position
    output.PositionWS = mul(input.PositionOS, World).xyz;

    // Calc the clip-space position
    output.PositionCS = mul(input.PositionOS, WorldViewProjection);

    // Rotate the normal and tangent into world-space
    output.NormalWS = normalize(mul(input.NormalOS, (float3x3)World));
    output.TangentWS = normalize(mul(input.TangentOS, (float3x3)World));

    // Pass along the texture coordinate
    output.TexCoord = input.TexCoord;		

    return output;
}

//======================================================================================
// Pixel Shader
//======================================================================================
float4 PS(in PSInput input) : SV_Target
{	
    // Normalize after interpolation
    float3 normalWS = normalize(input.NormalWS);
    float3 tangentWS = normalize(input.TangentWS);

    // Calculate the bitangent    
    float3 bitangentWS = normalize(cross(normalWS, tangentWS));
    float3x3 tangentToWorld = float3x3(bitangentWS, tangentWS, normalWS);

    // Sample the normal map
    float3 normalTS = NormalMap.Sample(AnisoSampler, input.TexCoord).rgb * 2.0f - 1.0f;   
    normalWS = normalize(mul(normalTS, tangentToWorld));        

    // Sample the diffuse map
    float4 texSample = DiffuseMap.Sample(AnisoSampler, input.TexCoord);
    float3 diffuseAlbedo = texSample.rgb;
    float specularAlbedo = texSample.a;

    // Calculate the specular lighting analytically
    static const float SpecularPower = 32.0f;
    float3 L = -normalize(LightDir);
    float3 V = normalize(CameraPosWS - input.PositionWS);
	float3 H = normalize(V + L);        
    float NdotH = saturate(dot(normalWS, H));	
    float3 specular = pow(NdotH, SpecularPower)* ((SpecularPower + 8.0f) / (8.0f * 3.14159265f)) * LightColor * specularAlbedo;

    // For diffuse lighting, we'll sample the 9th mip level (4x4) of the env. map using just the normal    
    float3 diffuseLight = EnvironmentMap.SampleLevel(AnisoSampler, normalWS, 9.0f).rgb;    
    float3 diffuse = diffuseLight * 1.0f * diffuseAlbedo;

    return float4(max(specular + diffuse, 0.0001f), 1.0f);
}