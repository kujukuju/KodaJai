
#module_parameters () (PRODUCTION := false, WASM := false, VALIDATE_SERIALIZED := true, NO_GRAPHICS := false);

#if WASM {
    core_count :: 8;

    #import "JaiWasmGL";
} else {
    #import "GL"(DUMP_GL_ERRORS = !PRODUCTION, DEFAULT_MSAA = 0);
    #import "stb_image";
    #import "stb_image_write";
}

#load "src/2d/AnimatedSprite.jai";
#load "src/2d/Camera2.jai";
#load "src/2d/Container2.jai";
#load "src/2d/FramedSprite.jai";
#load "src/2d/Font.jai";
#load "src/2d/Image.jai";
#load "src/2d/Quad.jai";
#load "src/2d/RenderTexture.jai";
#load "src/2d/Shapes2.jai";
#load "src/2d/Sprite.jai";
#load "src/2d/Text.jai";
#load "src/2d/Texture.jai";
#load "src/2d/TextureArray.jai";

#load "src/3d/AnimatedModel.jai";
#load "src/3d/Animation.jai";
#load "src/3d/Camera3.jai";
#load "src/3d/Container3.jai";
#load "src/3d/CubeGeometry.jai";
#load "src/3d/CubeMap.jai";
#load "src/3d/CubemapTexture.jai";
#load "src/3d/CustomDataLoader.jai";
#load "src/3d/DecalMath.jai";
#load "src/3d/DrawCallContainer.jai";
#load "src/3d/Geometry.jai";
#load "src/3d/GridGeometry.jai";
#load "src/3d/Image3.jai";
#load "src/3d/InstancedModel.jai";
#load "src/3d/Lights.jai";
#load "src/3d/Model.jai";
#load "src/3d/PanoramicMap.jai";
#load "src/3d/ParticleEmitters.jai";
#load "src/3d/PlaneGeometry.jai";
#load "src/3d/SdfGenerator.jai";
#load "src/3d/Shapes3.jai";
#load "src/3d/SphereGeometry.jai";
#load "src/3d/Sprite3.jai";
#load "src/3d/Texture3.jai";
#load "src/3d/TorusGeometry.jai";
#load "src/3d/VolumetricCloud.jai";

#load "src/deferred/FramebufferPass.jai";
#load "src/deferred/SSAOPass.jai";

#load "src/noise/Noise.jai";
#load "src/noise/Perlin.jai";
#load "src/noise/PerlinWorley.jai";
#load "src/noise/VolumeNoise.jai";
#load "src/noise/Worley.jai";

#load "src/parallel/Parallel.jai";
#load "src/parallel/ParallelMergeSort.jai";
#load "src/parallel/ParallelQuickSort.jai";

#load "src/shaders/forward/BlurShader.jai";
#load "src/shaders/forward/CubemapShader.jai";
#load "src/shaders/forward/DefaultEllipseShader.jai";
#load "src/shaders/forward/DefaultInstancedShader3.jai";
#load "src/shaders/forward/DefaultColorNormalShader3.jai";
#load "src/shaders/forward/DefaultColorShader3.jai";
#load "src/shaders/forward/DefaultShader.jai";
#load "src/shaders/forward/DefaultShader3.jai";
#load "src/shaders/forward/DefaultShaderColors3.jai";
#load "src/shaders/forward/DefaultShapeShader3.jai";
#load "src/shaders/forward/FlatGridShader3.jai";
#load "src/shaders/forward/FontParticleShader.jai";
#load "src/shaders/forward/FontShader.jai";
#load "src/shaders/forward/InfiniteGridShader3.jai";
#load "src/shaders/forward/InstancedShader2.jai";
#load "src/shaders/forward/InstancedShader3.jai";
#load "src/shaders/forward/OcclusionShader3.jai";
#load "src/shaders/forward/RoundedRectShader.jai";
#load "src/shaders/forward/SkinnedAnimationDoubleShader3.jai";
#load "src/shaders/forward/SkinnedAnimationDoubleTextureShader3.jai";
#load "src/shaders/forward/SkinnedAnimationNoNormalShader3.jai";
#load "src/shaders/forward/SkinnedAnimationNoTextureShader3.jai";
#load "src/shaders/forward/SkinnedAnimationShader3.jai";
#load "src/shaders/forward/SpriteShader3.jai";
#load "src/shaders/forward/TextureShader3.jai";
#load "src/shaders/forward/TorusShader3.jai";
#load "src/shaders/forward/TransformShader.jai";
#load "src/shaders/forward/VolumetricCloudShader.jai";

#load "src/shaders/ShaderManager.jai";
#load "src/shaders/ShaderParts.jai";
#load "src/shaders/Shaders.jai";

#load "src/shadows/ShadowUtilities.jai";

#load "src/utilities/BoundingShapes.jai";

#load "src/CircleAllocator.jai";
#load "src/Color.jai";
// #load "src/CompressedTextures.jai";
#load "src/DebugInfo.jai";
#load "src/GltfLoader.jai";
#load "src/Input.jai";
#load "src/Material.jai";
#load "src/Operators.jai";
#load "src/ParticleSystem.jai";
#load "src/Pass.jai";
#load "src/PerfTracker.jai";
#load "src/Pipeline.jai";
#load "src/PixelFormat.jai";
#load "src/Point2.jai";
#load "src/Point3.jai";
#load "src/Point4.jai";
#load "src/QuadParticleSystem.jai";
#load "src/Renderable.jai";
#load "src/SerializeStructure.jai";
#load "src/ShaderUniforms.jai";
#load "src/StorageFormat.jai";
#load "src/SwapBuffer.jai";
#load "src/TextureInterp.jai";
#load "src/TextureWrap.jai";
#load "src/Time.jai";
#load "src/Utilities.jai";
#load "src/Window.jai";

#load "src/assets/TriplexSansBold.jai";
#load "src/assets/White.jai";

ActiveTexture :: struct {
    buffer: u32;
    bytes: int;
}

koda: struct {
    initialized: bool;
    window: *GLFWwindow;
    width: int;
    height: int;
    frame_tracker: FrameTracker;
    time_tracker: TimeTracker;
    render_flipped: bool;
    shader: u32;
    active_textures: [..] ActiveTexture;
    texture_expirations: [..] int;
    maximum_active_texture_count: int;
    shader_replacements: [..] [2] *Shader;
    view: Matrix4 = Matrix4Identity;
    projection: Matrix4 = Matrix4Identity;
    fovy: float = 0.5 * PI;
    active_program: GLuint;
    active_pass_channels: [] PixelFormat = .[.RGBA8];
    cull_face: bool = true;
    cull_face_mode: CullFaceMode = .Back;
    can_render: bool = true;
};

get_static_sprite :: () -> *Sprite {
    return *static_sprite;
}

#scope_module

static_sprite: Sprite;

#import "Basic";
#import "String";
#import "Hash_Table";
#import "File_Utilities";
#import "File";
#import "Hash";
#import "System";
#import "Random";
#import "Compiler";
#import "Math";
#import "Atomics";

#import "JaiGLFW";
#import "ContiguousJsonJai"(ASM = !WASM);
#import "FixedStringJai";
#import "JaiBoundingTree";
#import "JaiSerializer";
#import "BlockAllocatorJai";
#import "JaiMath";

#if WASM {
    parallel_init :: () {}
    parallel_for :: (start: int, end_exclusive: int, $callback: (i: int, thread: int, data: $T), data: T, thread_count: int = 0) {
        for i: start..end_exclusive {
            callback(i, 0, data);
        }
    }

    Mutex :: struct {}
    lock :: (m: *Mutex) {}
    unlock :: (m: *Mutex) {}
    init :: (m: *Mutex) {}

    c_alloc :: (size : u64) -> *void #foreign "malloc";
    c_free :: (memory: *void) #foreign "free";

    exit :: (sig: int) #foreign;
} else {
    #import "Thread";
    #import "JaiParallel";

    c_alloc :: (size : u64) -> *void #foreign crt "malloc";
    c_free :: (memory: *void) #foreign crt "free";

    #if OS == .WINDOWS {
        crt :: #system_library "msvcrt";
    } else #if OS == .LINUX {
        crt :: #system_library "libc";
    }
}

