
#module_parameters(PRODUCTION := false, WASM := false);

#if WASM {
    #import "JaiWasmGL";
} else {
    #import "GL";
}

// #insert #run () -> string {
//     filepath :: #filepath;

//     files := file_list(tprint("%src", #filepath));

//     builder: String_Builder;

//     for file: files {
//         if !ends_with(file, ".jai") {
//             continue;
//         }

//         relative_file: string;
//         relative_file.data = file.data + filepath.count;
//         relative_file.count = file.count - filepath.count;

//         append(*builder, "#load \"");
//         append(*builder, relative_file);
//         append(*builder, "\";\n");
//     }

//     str := builder_to_string(*builder);
//     print("output %\n", str);

//     return str;
// }();

#load "src/2d/AnimatedSprite.jai";
#load "src/2d/Camera2.jai";
#load "src/2d/Container2.jai";
#load "src/2d/FramedSprite.jai";
#load "src/2d/Font.jai";
#load "src/2d/Image.jai";
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
#load "src/3d/DecalMath.jai";
#load "src/3d/Geometry.jai";
#load "src/3d/GridGeometry.jai";
#load "src/3d/Image3.jai";
#load "src/3d/InstancedModel.jai";
#load "src/3d/Model.jai";
#load "src/3d/PanoramicMap.jai";
#load "src/3d/PlaneGeometry.jai";
#load "src/3d/Shapes3.jai";
#load "src/3d/SphereGeometry.jai";
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
#load "src/parallel/ParallelQuickSort.jai";

#load "src/shaders/deferred/FAAAShader.jai";
#load "src/shaders/deferred/GaussianDirectionalBlurShader.jai";
#load "src/shaders/deferred/GuidedBlurShader.jai";
#load "src/shaders/deferred/SharpenShader.jai";
#load "src/shaders/deferred/SSAOShader.jai";

#load "src/shaders/forward/BlurShader.jai";
#load "src/shaders/forward/CubemapShader.jai";
#load "src/shaders/forward/DefaultEllipseShader.jai";
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
#load "src/shaders/forward/TextureShader3.jai";
#load "src/shaders/forward/TorusShader3.jai";
#load "src/shaders/forward/TransformShader.jai";
#load "src/shaders/forward/VolumetricCloudShader.jai";

#load "src/shaders/ShaderManager.jai";
#load "src/shaders/Shaders.jai";

#load "src/shadows/ShadowUtilities.jai";

#load "src/CircleAllocator.jai";
#load "src/Color.jai";
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

koda: struct {
    initialized: bool;
    window: *GLFWwindow;
    width: int;
    height: int;
    frame_tracker: FrameTracker;
    time_tracker: TimeTracker;
    render_flipped: bool;
    shader: *Shader;
    view: Matrix4 = Matrix4Identity;
    fovy: float = 0.5 * PI;
    active_program: GLuint;
    active_pass_channels: [] PixelFormat = .[.RGBA8];
    cull_face: bool = true;
    cull_face_mode: CullFaceMode = .Back;
    can_render: bool = true;
};

// get_koda_asset_path :: () -> string {
//     library_path := tprint("%/assets/", get_working_directory());
//     print("asset path is %\n", library_path);
//     return library_path;
// }

// KODA_ASSET_PATH := #run () -> string {
//     if file_exists(library_path) {
//         return library_path;
//     } else {
//         return library_path; // this is probably the right way to do it but idk what to put here
//     }
// }();
// #run print("Koda asset path: %\n", KODA_ASSET_PATH);

#scope_module

static_sprite: Sprite;
#if WASM {
    core_count :: 8;
} else {
    core_count :: #run get_number_of_processors();
    #import "stb_image";
    #import "stb_image_write";
}

#load "src/assets/TriplexSansBold.jai";
#load "src/assets/TriplexSansBoldFont.jai";
#load "src/assets/White.jai";

#import "String";
#import "Hash_Table";
#import "File_Utilities";
#import "Hash";
#import "System";
#import "Random";

#import "ContiguousJsonJai"(ASSERT = false, ASM = !WASM);
#import "FixedStringJai";
#import "JaiBoundingTree";
#import "JaiSerializer";
#import "JaiParallel"(WASM);

c_alloc  :: (size : u64) -> *void #foreign crt "malloc";
c_free    :: (memory: *void) #foreign crt "free";

#if OS == .WINDOWS {
    crt :: #system_library "msvcrt";
} else #if OS == .LINUX {
    crt :: #system_library "libc";
}