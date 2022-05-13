#load "2d/Camera2.jai";

#load "3d/Camera3.jai";
#load "3d/Geometry.jai";
#load "3d/GeometryVertex.jai";
#load "3d/Mesh.jai";

#load "AnimatedSprite.jai";
#load "CircleAllocator.jai";
#load "Color.jai";
#load "DefaultEllipseShader.jai";
#load "DefaultShader.jai";
#load "DefaultShader3.jai";
#load "Enums.jai";
#load "FramedSprite.jai";
#load "Input.jai";
#load "Material.jai";
#load "Shaders.jai";
#load "Shapes.jai";
#load "Sprite.jai";
#load "SwapBuffer.jai";
#load "Text.jai";
#load "Texture.jai";
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
    static_sprite_: Sprite;
};

KODA_ASSET_PATH :: #run tprint("%assets/", #filepath);
#run print("Koda asset path: %\n", KODA_ASSET_PATH);

default_shader: DefaultShader;
default_shader3: DefaultShader3;
default_ellipse_shader: DefaultEllipseShader;
serializer: Serializer;

#scope_file

#load "Operators.jai";
#load "../JaiSerializer/module.jai";