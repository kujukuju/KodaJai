
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
#load "src/2d/Image.jai";
#load "src/2d/PixelFormat.jai";
#load "src/2d/RenderTexture.jai";
#load "src/2d/Shapes2.jai";
#load "src/2d/Sprite.jai";
#load "src/2d/Texture.jai";

#load "src/3d/Camera3.jai";
#load "src/3d/Container3.jai";
#load "src/3d/Geometry.jai";
#load "src/3d/InstancedModel.jai";
#load "src/3d/Mesh.jai";
#load "src/3d/Model.jai";
#load "src/3d/Shapes3.jai";
#load "src/3d/SphereGeometry.jai";

#load "src/CircleAllocator.jai";
#load "src/Color.jai";
#load "src/DefaultEllipseShader.jai";
#load "src/DefaultShader.jai";
#load "src/DefaultShader3.jai";
#load "src/FontShader.jai";
#load "src/Input.jai";
#load "src/InstancedShader2.jai";
#load "src/InstancedShader3.jai";
#load "src/Material.jai";
#load "src/Operators.jai";
#load "src/Pass.jai";
#load "src/Pipeline.jai";
#load "src/Point2.jai";
#load "src/Point3.jai";
#load "src/Point4.jai";
#load "src/Renderable.jai";
#load "src/Shaders.jai";
#load "src/ShaderUniforms.jai";
#load "src/SwapBuffer.jai";
#load "src/Text.jai";
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
    frame_tracker: FrameTracker;
    time_tracker: TimeTracker;
    render_flipped: bool;
    shader: *Shader;
    view: Matrix4 = Matrix4Identity;
    active_program: GLuint;
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

default_shader: DefaultShader;
default_shader3: DefaultShader3;
instanced_shader2: InstancedShader2;
instanced_shader3: InstancedShader3;
default_ellipse_shader: DefaultEllipseShader;
default_font_shader: FontShader;
serializer: Serializer;

#scope_module

static_sprite: Sprite;

#load "src/assets/TriplexSansBold.jai";
#load "src/assets/White.jai";

#import "String";
#import "ContiguousJsonJai"(ASSERT = false, ASM = !WASM);
#import "File_Utilities";
#import "JaiSerializer";