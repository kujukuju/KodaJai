
#module_parameters(WASM := false);

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

#load "src/noise/Noise.jai";
#load "src/noise/Perlin.jai";
#load "src/noise/PerlinWorley.jai";
#load "src/noise/VolumeNoise.jai";
#load "src/noise/Worley.jai";

#load "src/parallel/Parallel.jai";
#load "src/parallel/ParallelQuickSort.jai";

#load "src/shaders/CubemapShader.jai";
#load "src/shaders/DefaultEllipseShader.jai";
#load "src/shaders/DefaultShader.jai";
#load "src/shaders/DefaultShader3.jai";
#load "src/shaders/DefaultShaderColors3.jai";
#load "src/shaders/DefaultShapeShader3.jai";
#load "src/shaders/DefaultVertColorNormalShader3.jai";
#load "src/shaders/DefaultVertColorShader3.jai";
#load "src/shaders/FlatGridShader3.jai";
#load "src/shaders/FontShader.jai";
#load "src/shaders/InfiniteGridShader3.jai";
#load "src/shaders/InstancedShader2.jai";
#load "src/shaders/InstancedShader3.jai";
#load "src/shaders/OcclusionShader3.jai";
#load "src/shaders/ShaderManager.jai";
#load "src/shaders/Shaders.jai";
#load "src/shaders/SkinnedAnimationDoubleShader3.jai";
#load "src/shaders/SkinnedAnimationDoubleTextureShader3.jai";
#load "src/shaders/SkinnedAnimationNoNormalShader3.jai";
#load "src/shaders/SkinnedAnimationNoTextureShader3.jai";
#load "src/shaders/SkinnedAnimationShader3.jai";
#load "src/shaders/TextureShader3.jai";
#load "src/shaders/TorusShader3.jai";
#load "src/shaders/VolumetricCloudShader.jai";

#load "src/CircleAllocator.jai";
#load "src/Color.jai";
#load "src/GltfLoader.jai";
#load "src/Input.jai";
#load "src/Material.jai";
#load "src/Operators.jai";
#load "src/ParticleSystem.jai";
#load "src/Pass.jai";
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
    width: s32;
    height: s32;
    last_width: int;
    last_height: int;
    viewport_width: int;
    viewport_height: int;
    windowed_width: int;
    windowed_height: int;
    frame_tracker: FrameTracker;
    time_tracker: TimeTracker;
    render_flipped: bool;
    shader: *Shader;
    view: Matrix4 = Matrix4Identity;
    fovy: float = 0.5 * PI;
    active_program: GLuint;
    cull_face: bool = true;
    cull_face_mode: CullFaceMode = .Back;
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

cubemap_shader: CubemapShader;
default_shader: DefaultShader;
default_shader3: DefaultShader3;
default_color_normal_shader3: DefaultVertColorNormalShader3;
default_color_shader3: DefaultVertColorShader3;
// I probably dont want this one and instead want auto generating shaders based on bool values, like a DynamicShader class
default_shader_colors3: DefaultShaderColors3;
default_shape_shader3: DefaultShapeShader3;
skinned_animation_double_shader3: SkinnedAnimationDoubleShader3;
skinned_animation_double_texture_shader3: SkinnedAnimationDoubleTextureShader3;
skinned_animation_no_normal_shader3: SkinnedAnimationNoNormalShader3;
skinned_animation_no_texture_shader3: SkinnedAnimationNoTextureShader3;
skinned_animation_shader3: SkinnedAnimationShader3;
volumetric_cloud_shader: VolumetricCloudShader;
instanced_shader2: InstancedShader2;
instanced_shader3: InstancedShader3;
occlusion_shader3: OcclusionShader3;
texture_shader3: TextureShader3;
torus_shader: TorusShader3;
default_ellipse_shader: DefaultEllipseShader;
default_font_shader: FontShader;

#scope_module

#run print("WASM? %\n", WASM);

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

#import "ContiguousJsonJai"(ASSERT = false, ASM = !WASM);
#import "FixedStringJai";
#import "JaiBoundingTree";
#import "JaiSerializer";
#load "../JaiCapture/module.jai";
#import "JaiParallel";