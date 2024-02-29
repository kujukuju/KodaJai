//======================================================================
//
//	Deferred MSAA Sample
//  by MJP
//  http://mynameismjp.wordpress.com/
//
//  All code and content licensed under Microsoft Public License (Ms-PL)
//
//======================================================================

#pragma once

#include "SampleFramework11/PCH.h"

#include "SampleFramework11/GraphicsTypes.h"
#include "SampleFramework11/PostProcessor.h"

using namespace SampleFramework11;

class DMPostProcessor : public PostProcessor
{

public:

    struct Constants
    {
        float BloomThreshold;        
        float BloomMagnitude;
        float BloomBlurSigma;
        float Tau;
        float TimeDelta;        
        float KeyValue;
        float EdgeThreshold;
        float VisualizeEdges;
        float ProjectionA;
        float ProjectionB;
        UINT UseMultipleSamples;
    };

    void Initialize(ID3D11Device* device);
    
    void SetConstants(const Constants& constants);
    void Render(ID3D11DeviceContext* deviceContext, ID3D11ShaderResourceView* input, 
                ID3D11ShaderResourceView* depth, ID3D11ShaderResourceView* msDepth, ID3D11RenderTargetView* output, bool applyAA);
    void AfterReset(UINT width, UINT height);

    const Constants& GetConstants() const { return constantBuffer.Data; }    

protected:

    void CalcAvgLuminance(ID3D11ShaderResourceView* input);
    TempRenderTarget* Bloom(ID3D11ShaderResourceView* input);
    void ToneMap(ID3D11ShaderResourceView* input, ID3D11ShaderResourceView* bloom, ID3D11RenderTargetView* output);    
    void ApplyAA(ID3D11ShaderResourceView* input, ID3D11ShaderResourceView* depth, 
                    ID3D11ShaderResourceView* msDepth, ID3D11RenderTargetView* output);

    ID3D11PixelShaderPtr bloomThreshold;
    ID3D11PixelShaderPtr bloomBlurH;
    ID3D11PixelShaderPtr bloomBlurV;
    ID3D11PixelShaderPtr luminanceMap;
    ID3D11PixelShaderPtr composite;
    ID3D11PixelShaderPtr scale;
    ID3D11PixelShaderPtr adaptLuminance;
    ID3D11PixelShaderPtr applyAA;

    RenderTarget2D adaptedLuminance[2];
    RenderTarget2D initialLuminance;
    RenderTarget2D exposureMap;

    UINT_PTR currLumTarget;

    ConstantBuffer<Constants> constantBuffer;
};