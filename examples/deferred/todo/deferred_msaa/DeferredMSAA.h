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

#include "SampleFramework11/App.h"
#include "SampleFramework11/InterfacePointers.h"
#include "SampleFramework11/Camera.h"
#include "SampleFramework11/Model.h"
#include "SampleFramework11/SpriteFont.h"
#include "SampleFramework11/SpriteRenderer.h"
#include "SampleFramework11/Skybox.h"
#include "SampleFramework11/GraphicsTypes.h"
#include "SampleFramework11/Slider.h"

#include "DMPostProcessor.h"

using namespace SampleFramework11;

class DeferredMSAA : public App
{

public:

    // Constants
    static const UINT_PTR NumEnvMaps = 1;
    static const UINT_PTR NumModels = 1;
    static const UINT_PTR NumAAModes = 3;

protected:

    enum AAMode
    {
        NoAA = 0,
        MSAA = 1,
        DeferredAA = 2
    };

    FirstPersonCamera camera;

    SpriteFont font;
    SpriteRenderer spriteRenderer;
    Skybox skybox;    

    DMPostProcessor postProcessor;
    DepthStencilBuffer depthBufferMS;    
    RenderTarget2D colorTarget;
    RenderTarget2D colorTargetMS;

    // Sliders for adjusting values
    Slider bloomThresholdSlider;
    Slider bloomMagSlider;
    Slider bloomBlurSigma;   
    Slider keyValueSlider;    
    Slider adaptationRateSlider;
    Slider edgeThresholdSlider;

    std::vector<GUIObject*> guiObjects;

    AAMode aaMode;
    bool visualizeEdges;
    bool useMultipleSamples;

    // Meshes
    Model models[NumModels];
    std::vector<ID3D11InputLayoutPtr> meshInputLayouts[NumModels];    
    UINT_PTR currModel;
    ID3D11VertexShaderPtr meshVS;
    ID3D11PixelShaderPtr meshPS;
    XMMATRIX meshRotation;

    // Environment maps    
    ID3D11ShaderResourceViewPtr envMaps[NumEnvMaps];
    UINT_PTR currEnvMap;

    // Constant buffers
    struct MeshVSConstants
    {
        XMMATRIX World;
        XMMATRIX WorldViewProjection;
    };

    struct MeshPSSceneConstants
    {
        Float4Align XMFLOAT3 LightDir;        
        Float4Align XMFLOAT3 LightColor;        
        Float4Align XMFLOAT3 CameraPosWS;
    };

    ConstantBuffer<MeshVSConstants> meshVSConstants;
    ConstantBuffer<MeshPSSceneConstants> meshPSSceneConstants;    
        
    virtual void LoadContent();
    virtual void Render(const Timer& timer);
    virtual void Update(const Timer& timer);
    virtual void BeforeReset();
    virtual void AfterReset();

    void CreateRenderTargets();
    void InitializeGUI();
    void AdjustGUI();
    
    void RenderMesh();
    void RenderPrepass();
    void RenderMainPass();
    void RenderHUD();

public:

    DeferredMSAA();    
};

