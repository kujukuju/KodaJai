//======================================================================
//
//	Deferred MSAA Sample
//  by MJP
//  http://mynameismjp.wordpress.com/
//
//  All code and content licensed under Microsoft Public License (Ms-PL)
//
//======================================================================

#include "PCH.h"

#include "SampleFramework11/ShaderCompilation.h"

#include "DMPostProcessor.h"

void DMPostProcessor::Initialize(ID3D11Device* device)
{
    PostProcessor::Initialize(device);

    constantBuffer.Initialize(device);

    // Load the shaders
    bloomThreshold.Attach(CompilePSFromFile(device, L"PostProcessing.hlsl", "Threshold"));
    bloomBlurH.Attach(CompilePSFromFile(device, L"PostProcessing.hlsl", "BloomBlurH"));
    bloomBlurV.Attach(CompilePSFromFile(device, L"PostProcessing.hlsl", "BloomBlurV"));
    luminanceMap.Attach(CompilePSFromFile(device, L"PostProcessing.hlsl", "LuminanceMap"));
    composite.Attach(CompilePSFromFile(device, L"PostProcessing.hlsl", "Composite"));
    scale.Attach(CompilePSFromFile(device, L"PostProcessing.hlsl", "Scale"));
    adaptLuminance.Attach(CompilePSFromFile(device, L"PostProcessing.hlsl", "AdaptLuminance"));
    applyAA.Attach(CompilePSFromFile(device, L"PostProcessing.hlsl", "ApplyAA", "ps_5_0"));

    currLumTarget = 0;
    adaptedLuminance[0].Initialize(device, 1024, 1024, DXGI_FORMAT_R32_FLOAT, 11, 1, 0, true);
    adaptedLuminance[1].Initialize(device, 1024, 1024, DXGI_FORMAT_R32_FLOAT, 11, 1, 0, true);
    initialLuminance.Initialize(device, 1024, 1024, DXGI_FORMAT_R32_FLOAT, 1);
}

void DMPostProcessor::AfterReset(UINT width, UINT height)
{
    PostProcessor::AfterReset(width, height);        
}

void DMPostProcessor::SetConstants(const Constants& constants)
{
    constantBuffer.Data = constants;    
}

void DMPostProcessor::Render(ID3D11DeviceContext* deviceContext, ID3D11ShaderResourceView* input, 
                                ID3D11ShaderResourceView* depth, ID3D11ShaderResourceView* msDepth, 
                                ID3D11RenderTargetView* output, bool applyAA)
{
    PostProcessor::Render(deviceContext, input, output);

    constantBuffer.ApplyChanges(deviceContext);    
    constantBuffer.SetPS(deviceContext, 1);

    // Calculate the average luminance first
    CalcAvgLuminance(input);
    
    // Now do the bloom
    TempRenderTarget* bloom = Bloom(input);      

    // Now tone map
    if (applyAA)
    {
        TempRenderTarget* toneMapped = GetTempRenderTarget(inputWidth, inputHeight, DXGI_FORMAT_R16G16B16A16_FLOAT);
        ToneMap(input, bloom->SRView, toneMapped->RTView);    
        bloom->InUse = false;

        // Apply AA
        ApplyAA(toneMapped->SRView, depth, msDepth, output);
        toneMapped->InUse = false;
    }
    else
    {
        ToneMap(input, bloom->SRView, output);    
        bloom->InUse = false;

    }

    currLumTarget = !currLumTarget;
}

void DMPostProcessor::CalcAvgLuminance(ID3D11ShaderResourceView* input)
{
    // Luminance mapping
    PostProcess(input,initialLuminance.RTView, luminanceMap, L"Luminance Map Generation");
    
    // Adaptation
    inputs.push_back(adaptedLuminance[!currLumTarget].SRView);
    inputs.push_back(initialLuminance.SRView);
    outputs.push_back(adaptedLuminance[currLumTarget].RTView);
    PostProcess(adaptLuminance, L"Luminance Adaptation");

    // Generate the mip chain
    context->GenerateMips(adaptedLuminance[currLumTarget].SRView);
}

PostProcessor::TempRenderTarget* DMPostProcessor::Bloom(ID3D11ShaderResourceView* input)
{    
    // Downscale 
    TempRenderTarget* bloom = GetTempRenderTarget(inputWidth / 1, inputHeight / 1, DXGI_FORMAT_R16G16B16A16_FLOAT);

    inputs.push_back(input);
    inputs.push_back(adaptedLuminance[currLumTarget].SRView);
    outputs.push_back(bloom->RTView);
    PostProcess(bloomThreshold, L"Bloom Threshold");
    
    TempRenderTarget* downscale1 = GetTempRenderTarget(inputWidth / 2, inputHeight / 2, DXGI_FORMAT_R16G16B16A16_FLOAT);
    PostProcess(bloom->SRView, downscale1->RTView, scale, L"Bloom Downscale");
    bloom->InUse = false;

    TempRenderTarget* downscale2 = GetTempRenderTarget(inputWidth / 4, inputHeight / 4, DXGI_FORMAT_R16G16B16A16_FLOAT);
    PostProcess(downscale1->SRView, downscale2->RTView, scale, L"Bloom Downscale");

    TempRenderTarget* downscale3 = GetTempRenderTarget(inputWidth / 8, inputHeight / 8, DXGI_FORMAT_R16G16B16A16_FLOAT);
    PostProcess(downscale2->SRView, downscale3->RTView, scale, L"Bloom Downscale");

    // Blur it
    for (UINT_PTR i = 0; i < 4; ++i)
    {
        TempRenderTarget* blurTemp = GetTempRenderTarget(inputWidth / 8, inputHeight / 8, DXGI_FORMAT_R16G16B16A16_FLOAT);
        PostProcess(downscale3->SRView, blurTemp->RTView, bloomBlurH, L"Horizontal Bloom Blur");        
        PostProcess(blurTemp->SRView, downscale3->RTView, bloomBlurV, L"Vertical Bloom Blur");
        blurTemp->InUse = false;
    }

    PostProcess(downscale3->SRView, downscale2->RTView, scale, L"Bloom Upscale");
    downscale3->InUse = false;

    PostProcess(downscale2->SRView, downscale1->RTView, scale, L"Bloom Upscale");
    downscale2->InUse = false;
    
    return downscale1;
}

void DMPostProcessor::ToneMap(ID3D11ShaderResourceView* input, ID3D11ShaderResourceView* bloom, ID3D11RenderTargetView* output)
{    
    // Composite the bloom with the original image, and apply tone-mapping
    inputs.push_back(input);
    inputs.push_back(adaptedLuminance[currLumTarget].SRView);
    inputs.push_back(bloom);    
    outputs.push_back(output);    
    PostProcess(composite, L"Tone Map And Composite");    
}

void DMPostProcessor::ApplyAA(ID3D11ShaderResourceView* input, ID3D11ShaderResourceView* depth, 
                                ID3D11ShaderResourceView* msDepth, ID3D11RenderTargetView* output)
{        
    inputs.push_back(input);
    inputs.push_back(msDepth);
    inputs.push_back(depth);
    outputs.push_back(output);
    PostProcess(applyAA, L"AA Pass");
}