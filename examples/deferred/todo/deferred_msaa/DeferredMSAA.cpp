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

#include "DeferredMSAA.h"

#include "resource.h"
#include "SampleFramework11/InterfacePointers.h"
#include "SampleFramework11/Window.h"  
#include "SampleFramework11/DeviceManager.h"
#include "SampleFramework11/Input.h"
#include "SampleFramework11/SpriteRenderer.h"
#include "SampleFramework11/Model.h"
#include "SampleFramework11/Utility.h"
#include "SampleFramework11/Camera.h"
#include "SampleFramework11/ShaderCompilation.h"

using namespace SampleFramework11;
using std::wstring;

const UINT WindowWidth = 1280;
const UINT WindowHeight = 720;
const float WindowWidthF = static_cast<float>(WindowWidth);
const float WindowHeightF = static_cast<float>(WindowHeight);

// Mesh filenames
static const wstring ModelFileNames[] = 
{    
    L"TankScene\\TankScene.sdkmesh"    
};

// Scale values applied to the mesh
static const float MeshScales[] =
{
    1.0f
};

// Environment map filenames
static const wstring EnvMapFileNames[] =
{
    L"Sunny.dds",
};

// AA modes
static const wstring AAModeNames[] =
{
    L"No AA",
    L"MSAA",
    L"Deferred MSAA"
};

DeferredMSAA::DeferredMSAA() :  App(L"Deferred MSAA", MAKEINTRESOURCEW(IDI_DEFAULT)),
                                camera(WindowWidthF / WindowHeightF,  PiOver4, 0.1f, 100.0f),
                                currModel(0),
                                currEnvMap(0),
                                aaMode(DeferredAA),
                                visualizeEdges(false),
                                useMultipleSamples(true)
{
	deviceManager.SetBackBufferWidth(WindowWidth);
	deviceManager.SetBackBufferHeight(WindowHeight);
    deviceManager.SetMinFeatureLevel(D3D_FEATURE_LEVEL_10_1);
    deviceManager.SetUseAutoDSAsSR(true);

	window.SetClientArea(WindowWidth, WindowHeight);    
}

void DeferredMSAA::BeforeReset()
{

}

void DeferredMSAA::AfterReset()
{
    float aspect = static_cast<float>(deviceManager.BackBufferWidth()) / deviceManager.BackBufferHeight();
    camera.SetAspectRatio(aspect);

    CreateRenderTargets();

    postProcessor.AfterReset(deviceManager.BackBufferWidth(), deviceManager.BackBufferHeight());

    AdjustGUI();
}

void DeferredMSAA::LoadContent()
{
    ID3D11DevicePtr device = deviceManager.Device();
    ID3D11DeviceContextPtr deviceContext = deviceManager.ImmediateContext();

    // Create a font + SpriteRenderer
    font.Initialize(L"Arial", 18, SpriteFont::Regular, true, device);
    spriteRenderer.Initialize(device);

    // Camera setup    
    camera.SetPosition(XMLoadFloat3(&XMFLOAT3(0, 0, -10.0f)));

    // Mesh shaders
    ID3D10BlobPtr compiledVS;
    meshVS.Attach(CompileVSFromFile(device, L"Mesh.hlsl", "VS", "vs_4_0", NULL, NULL, &compiledVS));
    meshPS.Attach(CompilePSFromFile(device, L"Mesh.hlsl"));

    // Load the models
    for (UINT_PTR i = 0; i < NumModels; ++i)
    {
        wstring path(L"Content\\Scenes\\");
        path += ModelFileNames[i];        
        models[i].CreateFromSDKMeshFile(device, path.c_str());

        // Create the input layouts
        for (UINT_PTR meshIdx = 0; meshIdx < models[i].Meshes().size(); ++meshIdx)
        {
            Mesh& mesh = models[i].Meshes()[meshIdx];
            ID3D11InputLayoutPtr inputLayout;
            DXCall(device->CreateInputLayout(mesh.InputElements(), mesh.NumInputElements(), 
                                            compiledVS->GetBufferPointer(), compiledVS->GetBufferSize(), 
                                            &inputLayout));
            meshInputLayouts[i].push_back(inputLayout);

        }
    }      

    meshRotation = XMMatrixIdentity();

    // Init CB's
    meshVSConstants.Initialize(device);    
    meshPSSceneConstants.Initialize(device);

    // Load up the environment maps
    for (UINT_PTR i = 0; i < NumEnvMaps; ++i)
    {
        wstring path(L"Content\\EnvMaps\\");
        path += EnvMapFileNames[i];        
        DXCall(D3DX11CreateShaderResourceViewFromFileW(device, path.c_str(), NULL, NULL, &envMaps[i], NULL));
    }

    // Init the skybox
    skybox.Initialize(device);

    // Init the post processor
    postProcessor.Initialize(device);

    InitializeGUI();    
}

// Creates the sliders
void DeferredMSAA::InitializeGUI()
{
    ID3D11DevicePtr device = deviceManager.Device();

    // Sliders   
    bloomThresholdSlider.Initialize(device);    
    bloomThresholdSlider.MinVal() = 0.0f;
    bloomThresholdSlider.MaxVal() = 10.0f;
    bloomThresholdSlider.NumSteps() = 100;
    bloomThresholdSlider.Value() = 3.0f;
    bloomThresholdSlider.Name() = L"Bloom Threshold";
    guiObjects.push_back(&bloomThresholdSlider);    

    bloomMagSlider.Initialize(device);    
    bloomMagSlider.MinVal() = 0.0f;
    bloomMagSlider.MaxVal() = 2.0f;
    bloomMagSlider.NumSteps() = 100;
    bloomMagSlider.Value() = 1.0f;
    bloomMagSlider.Name() = L"Bloom Magnitude";
    guiObjects.push_back(&bloomMagSlider);    

    bloomBlurSigma.Initialize(device);    
    bloomBlurSigma.MinVal() = 0.5f;
    bloomBlurSigma.MaxVal() = 1.5f;
    bloomBlurSigma.NumSteps() = 100;
    bloomBlurSigma.Value() = 0.8f;
    bloomBlurSigma.Name() = L"Bloom Blur Sigma";
    guiObjects.push_back(&bloomBlurSigma);        

    keyValueSlider.Initialize(device);
    keyValueSlider.MinVal() = 0.0f;
    keyValueSlider.MaxVal() = 0.5f;
    keyValueSlider.NumSteps() = 100;
    keyValueSlider.Value() = 0.08f;
    keyValueSlider.Name() = L"Auto-Exposure Key Value";
    guiObjects.push_back(&keyValueSlider);    

    adaptationRateSlider.Initialize(device);
    adaptationRateSlider.MinVal() = 0.0f;
    adaptationRateSlider.MaxVal() = 4.0f;
    adaptationRateSlider.NumSteps() = 100;
    adaptationRateSlider.Value() = 1.25f;
    adaptationRateSlider.Name() = L"Adaptation Rate";
    guiObjects.push_back(&adaptationRateSlider);

    edgeThresholdSlider.Initialize(device);
    edgeThresholdSlider.MinVal() = 0.01f;
    edgeThresholdSlider.MaxVal() = 1.00f;
    edgeThresholdSlider.NumSteps() = 100;
    edgeThresholdSlider.Value() = 0.5f;
    edgeThresholdSlider.Name() = L"Edge Detection Threshold";
    guiObjects.push_back(&edgeThresholdSlider);

    AdjustGUI();
}

// Adjusts the position of the sliders
void DeferredMSAA::AdjustGUI()
{
    float width = static_cast<float>(deviceManager.BackBufferWidth());
    float x = width - 150;
    float y = 10.0f;
    const float Spacing = 40.0f;

    for (UINT_PTR i = 0; i < guiObjects.size(); ++i)
    {
        guiObjects[i]->Position() = XMFLOAT2(x, y);
        y += Spacing;
    }
}

// Creates all required render targets
void DeferredMSAA::CreateRenderTargets()
{
    ID3D11Device* device = deviceManager.Device();
    UINT width = deviceManager.BackBufferWidth();
    UINT height = deviceManager.BackBufferHeight();

    colorTarget.Initialize(device, width, height, DXGI_FORMAT_R16G16B16A16_FLOAT);
    colorTargetMS.Initialize(device, width, height, DXGI_FORMAT_R16G16B16A16_FLOAT, 1, 4, D3D11_STANDARD_MULTISAMPLE_PATTERN);
    depthBufferMS.Initialize(device, width, height, DXGI_FORMAT_D24_UNORM_S8_UINT, true, 4, D3D11_STANDARD_MULTISAMPLE_PATTERN);    
}

void DeferredMSAA::Update(const Timer& timer)
{   
    MouseState mouseState = MouseState::GetMouseState(window);
    KeyboardState kbState = KeyboardState::GetKeyboardState();

    if (kbState.IsKeyDown(Keys::Escape))
        window.Destroy();

    float CamMoveSpeed = 5.0f * timer.DeltaSecondsF();
    const float CamRotSpeed = 0.180f * timer.DeltaSecondsF();
    const float MeshRotSpeed = 0.180f * timer.DeltaSecondsF();

    // Move the camera with keyboard input
    if (kbState.IsKeyDown(LeftShift))
        CamMoveSpeed *= 0.25f;

    XMVECTOR camPos = camera.Position();
    if (kbState.IsKeyDown(Keys::W))
        camPos += camera.Forward() * CamMoveSpeed;
    else if (kbState.IsKeyDown(Keys::S))
        camPos += camera.Back() * CamMoveSpeed;
    if (kbState.IsKeyDown(Keys::A))
        camPos += camera.Left() * CamMoveSpeed;
    else if (kbState.IsKeyDown(Keys::D))
        camPos += camera.Right() * CamMoveSpeed;
    if (kbState.IsKeyDown(Keys::Q))
        camPos += camera.Up() * CamMoveSpeed;
    else if (kbState.IsKeyDown(Keys::E))
        camPos += camera.Down() * CamMoveSpeed;
    camera.SetPosition(camPos);

    // Switch the AA mode with the M key
    if (kbState.GetKeyState(M).RisingEdge)
    {
        INT_PTR change = kbState.GetKeyState(RightShift).Pressed ? -1 : 1;
        INT_PTR mode = (aaMode + change);
        if (mode == NumAAModes)
            mode = 0;
        else if (mode < 0)
            mode = NumAAModes - 1;
        aaMode = static_cast<AAMode>(mode);
    }

    // Toggle edge visualization
    if (kbState.GetKeyState(L).RisingEdge)
        visualizeEdges = !visualizeEdges;

    // Toggle multiple sample mode
    if (kbState.GetKeyState(K).RisingEdge)
        useMultipleSamples = !useMultipleSamples;

    // Rotate the camera with the mouse
    if (mouseState.RButton.Pressed && mouseState.IsOverWindow)
    {
        float xRot = camera.XRotation();
        float yRot = camera.YRotation();
        xRot += mouseState.DY * CamRotSpeed;
        yRot += mouseState.DX * CamRotSpeed;
        camera.SetXRotation(xRot);
        camera.SetYRotation(yRot);
    }

    // Rotate the model with the mouse
    if (mouseState.MButton.Pressed && mouseState.IsOverWindow)
    {
        float xRot = -mouseState.DY * MeshRotSpeed;
        float yRot = -mouseState.DX * MeshRotSpeed;
        meshRotation *= XMMatrixRotationRollPitchYaw(xRot, yRot, 0);
    }

    for (UINT_PTR i = 0; i < guiObjects.size(); ++i)
        guiObjects[i]->Update(mouseState.X, mouseState.Y, mouseState.LButton.Pressed);          
}

void DeferredMSAA::Render(const Timer& timer)
{
    ID3D11DeviceContextPtr context = deviceManager.ImmediateContext();            

    if (aaMode == DeferredAA)
        RenderPrepass();

    RenderMainPass();

    // Kick off post-processing
    D3DPERF_BeginEvent(0xFFFFFFFF, L"Post Processing");
    DMPostProcessor::Constants constants;
    constants.BloomThreshold = bloomThresholdSlider.Value();
    constants.BloomMagnitude = bloomMagSlider.Value();
    constants.BloomBlurSigma = bloomBlurSigma.Value();       
    constants.Tau = adaptationRateSlider.Value();    
    constants.KeyValue = keyValueSlider.Value();
    constants.TimeDelta = timer.DeltaSecondsF();
    constants.EdgeThreshold = edgeThresholdSlider.Value();
    constants.VisualizeEdges = visualizeEdges ? 1.0f : 0.0f;
    constants.ProjectionA = camera.FarClip() / (camera.FarClip() - camera.NearClip());
    constants.ProjectionB = (-camera.FarClip() * camera.NearClip()) / (camera.FarClip() - camera.NearClip());
    constants.UseMultipleSamples = useMultipleSamples;
    
    postProcessor.SetConstants(constants);
    postProcessor.Render(context, colorTarget.SRView, deviceManager.AutoDepthStencilSRView(), 
                        depthBufferMS.SRView, deviceManager.BackBuffer(), aaMode == DeferredAA);
    D3DPERF_EndEvent();
    
    ID3D11RenderTargetView* renderTargets[1] = { deviceManager.BackBuffer() };
    context->OMSetRenderTargets(1, renderTargets, NULL);

    D3D11_VIEWPORT vp;
    vp.Width = static_cast<float>(deviceManager.BackBufferWidth());
    vp.Height = static_cast<float>(deviceManager.BackBufferHeight());
    vp.TopLeftX = 0;
    vp.TopLeftY = 0;
    vp.MinDepth = 0;
    vp.MaxDepth = 1;
    context->RSSetViewports(1, &vp);

    RenderHUD();
}

void DeferredMSAA::RenderPrepass()
{
    PIXEvent event(L"Prepass");

    ID3D11DeviceContextPtr context = deviceManager.ImmediateContext();

    context->OMSetRenderTargets(0, NULL, depthBufferMS.DSView);
    
    context->ClearDepthStencilView(depthBufferMS.DSView, D3D11_CLEAR_DEPTH|D3D11_CLEAR_STENCIL, 1.0f, 0);

    RenderMesh();
}

void DeferredMSAA::RenderMainPass()
{
    PIXEvent event(L"Main Pass");

    ID3D11DeviceContextPtr context = deviceManager.ImmediateContext();

    ID3D11RenderTargetView* renderTargets[1];
    ID3D11DepthStencilView* ds;
    if (aaMode == MSAA)
    {
        renderTargets[0] = colorTargetMS.RTView;
        ds = depthBufferMS.DSView;
    }
    else
    {
        renderTargets[0] = colorTarget.RTView;
        ds = deviceManager.AutoDepthStencilView();
    }
        
    context->OMSetRenderTargets(1, renderTargets, ds);

    context->ClearRenderTargetView(renderTargets[0], reinterpret_cast<float*>(&XMFLOAT4(0, 0, 0, 1)));    
    context->ClearDepthStencilView(ds, D3D11_CLEAR_DEPTH|D3D11_CLEAR_STENCIL, 1.0f, 0);

    RenderMesh();

    // Render the skybox    
    XMFLOAT3 bias = XMFLOAT3(1, 1, 1);
    skybox.Render(context, envMaps[currEnvMap], camera.ViewMatrix(), camera.ProjectionMatrix(), bias);

    if (aaMode == MSAA)
        context->ResolveSubresource(colorTarget.Texture, 0, colorTargetMS.Texture, 0, colorTarget.Format);
}

void DeferredMSAA::RenderMesh()
{
    PIXEvent event(L"Mesh Rendering");

    ID3D11DeviceContextPtr context = deviceManager.ImmediateContext();

    // Set states
    float blendFactor[4] = {1, 1, 1, 1};    
    context->RSSetState(rasterizerStates.BackFaceCull());
    context->OMSetBlendState(blendStates.BlendDisabled(), blendFactor, 0xFFFFFFFF);
    context->OMSetDepthStencilState(depthStencilStates.DepthWriteEnabled(), 0);
    ID3D11SamplerState* sampStates[1] = { samplerStates.Anisotropic() };
    context->PSSetSamplers(0, 1, sampStates);

    // Set constant buffers
    float meshScale = MeshScales[currModel];
    XMMATRIX meshWorld = XMMatrixScaling(meshScale, meshScale, meshScale) * meshRotation;
    meshVSConstants.Data.World = XMMatrixTranspose(meshWorld);
    meshVSConstants.Data.WorldViewProjection = XMMatrixTranspose(meshWorld * camera.ViewProjectionMatrix());
    meshVSConstants.ApplyChanges(context);
    meshVSConstants.SetVS(context, 0);    

    // Set shaders
    context->VSSetShader(meshVS , NULL, 0);
    context->PSSetShader(meshPS, NULL, 0);
    context->GSSetShader(NULL, NULL, 0);
    context->DSSetShader(NULL, NULL, 0);
    context->HSSetShader(NULL, NULL, 0);        

    // Set per-scene PS constants   
    meshPSSceneConstants.Data.LightDir = XMFLOAT3(0.0f, -0.25f, -1);
    meshPSSceneConstants.Data.LightColor = XMFLOAT3(1.4f, 1.0f, 0.5f);
    XMStoreFloat3(&meshPSSceneConstants.Data.CameraPosWS, camera.Position());
    meshPSSceneConstants.ApplyChanges(context);
    meshPSSceneConstants.SetPS(context, 0);
    
    Model& model = models[currModel];    

    // Draw all meshes
    for (UINT_PTR meshIdx = 0; meshIdx < model.Meshes().size(); ++meshIdx)
    {
        Mesh& mesh = model.Meshes()[meshIdx];

        // Set the vertices and indices     
        ID3D11Buffer* vertexBuffers[1] = { mesh.VertexBuffer() };  
        UINT vertexStrides[1] = { mesh.VertexStride() };
        UINT offsets[1] = { 0 };
        context->IASetVertexBuffers(0, 1, vertexBuffers, vertexStrides, offsets);    
        context->IASetIndexBuffer(mesh.IndexBuffer(), mesh.IndexBufferFormat(), 0);
        context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

        // Set the input layout
        context->IASetInputLayout(meshInputLayouts[currModel][meshIdx]);

        // Draw all parts
        for (UINT_PTR partIdx = 0; partIdx < mesh.MeshParts().size(); ++partIdx)
        {
            const MeshPart& part = mesh.MeshParts()[partIdx];
            const MeshMaterial& material = model.Materials()[part.MaterialIdx];

            // Set the textures
            ID3D11ShaderResourceView* textures[3] = { envMaps[currEnvMap].GetInterfacePtr(),                                                        
                                                        material.DiffuseMap,
                                                        material.NormalMap };
            context->PSSetShaderResources(0, 3, textures);

            context->DrawIndexed(part.IndexCount, part.IndexStart, 0); 
        }
    }
}

void DeferredMSAA::RenderHUD()
{
    PIXEvent event(L"HUD Pass");

    spriteRenderer.Begin(deviceManager.ImmediateContext(), SpriteRenderer::Point);    

    // AA mode
    XMMATRIX transform = XMMatrixTranslation(25.0f, deviceManager.BackBufferHeight() - 100.0f, 0);
    wstring aaModeText(L"AA Mode(Press M to change): " + AAModeNames[aaMode]);
    spriteRenderer.RenderText(font, aaModeText.c_str(), transform, XMFLOAT4(1, 1, 0, 1));

    transform._42 += 25.0f;
    wstring edgeText(L"Visualize Edges(Press L to change): ");
    edgeText += visualizeEdges ? L"True" : L"False";
    spriteRenderer.RenderText(font, edgeText.c_str(), transform, XMFLOAT4(1, 1, 0, 1));

    transform._42 += 25.0f;
    wstring aaTypeText(L"Deferred AA Type(Press K to change): ");
    aaTypeText += useMultipleSamples ? L"Multiple Samples" : L"Single Sample";
    spriteRenderer.RenderText(font, aaTypeText.c_str(), transform, XMFLOAT4(1, 1, 0, 1));

    for (UINT_PTR i = 0; i < guiObjects.size(); ++i)
        guiObjects[i]->Render(spriteRenderer);

    spriteRenderer.End();
}

int APIENTRY wWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPWSTR lpCmdLine, int nCmdShow)
{	    			                                     
	DeferredMSAA app;
    app.Run();
}


