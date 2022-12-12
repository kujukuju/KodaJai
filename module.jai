#load "2d/AnimatedSprite.jai";
#load "2d/Camera2.jai";
#load "2d/Container2.jai";
#load "2d/FramedSprite.jai";
#load "2d/Image.jai";
#load "2d/PixelFormat.jai";
#load "2d/RenderTexture.jai";
#load "2d/Shapes2.jai";
#load "2d/Sprite.jai";
#load "2d/Texture.jai";

#load "3d/Camera3.jai";
#load "3d/Container3.jai";
#load "3d/Geometry.jai";
#load "3d/GeometryVertex.jai";
#load "3d/Mesh.jai";
#load "3d/Model.jai";
#load "3d/Shapes3.jai";
#load "3d/SphereGeometry.jai";

#load "CircleAllocator.jai";
#load "Color.jai";
#load "DefaultEllipseShader.jai";
#load "DefaultShader.jai";
#load "DefaultShader3.jai";
#load "FontShader.jai";
#load "Input.jai";
#load "InstancedShader2.jai";
#load "InstancedShader3.jai";
#load "Material.jai";
#load "Operators.jai";
#load "Pass.jai";
#load "Pipeline.jai";
#load "Point2.jai";
#load "Point3.jai";
#load "Point4.jai";
#load "Renderable.jai";
#load "Shaders.jai";
#load "SwapBuffer.jai";
#load "Text.jai";
#load "Time.jai";
#load "Utilities.jai";
#load "Window.jai";

koda: struct {
    initialized: bool;
    window: *GLFWwindow;
    width: s32;
    height: s32;
    last_width_: s32;
    last_height_: s32;
    frame_tracker: FrameTracker;
    time_tracker: TimeTracker;
    shader: *Shader;
    transform: Matrix4 = Matrix4Identity;
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

#scope_file

#load "assets/TriplexSansBold.jai";
#load "assets/White.jai";

#import "File_Utilities";
#load "Operators.jai";
#load "../JaiSerializer/module.jai";