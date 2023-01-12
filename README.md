## Setup
Just `#import "KodaJai";`. 

To bake the assets you run `jai ./generate_asset_constants.jai`.

## Core
```jai
Color :: struct {
    r, g, b, a: float;
}
Point2 :: struct {
    x, y: int;
}
Point3 :: struct {
    x, y, z: int;
}
Point4 :: struct {
    x, y, z, w: int;
}

// window
koda_init :: ();

get_window :: () -> *GLFWWindow;
create_window :: (name: string, width: int, height: int);
destroy_window :: ();
set_viewport :: (width: int, height: int);

should_exit :: () -> bool;

get_fullscreen :: () -> bool;
set_fullscreen :: (fullscreen: bool);
get_vsync :: () -> bool;
set_vsync :: (vsync: bool);
get_target_fps :: () -> float;
set_target_fps :: (fps: float);
get_mouse_capture :: () -> bool;
set_mouse_capture :: (capture: bool);
get_mouse_currently_captured :: () -> bool
get_front_face_ccw :: () -> bool;
set_front_face_ccw :: (ccw: bool);
get_depth_test :: () -> bool;
set_depth_test :: (enabled: bool);
get_cull_face :: () -> bool;
set_cull_face :: (enabled: bool);

clear :: (color: Color);

begin_render_target :: (render_texture: RenderTexture); // test
end_render_target :: (); // test
```

## Input
```jai
Key :: enum {
    W;
    A;
    S;
    D;
    R;
    SPACE;
    SHIFT;
    CONTROL;
    ESCAPE;
    NUM1;
    NUM2;
    F5;
    F1;
    DELETE;
}
Button :: enum {
    A;
    B;
    X;
    Y;
    LEFT_BUMPER;
    RIGHT_BUMPER;
    BACK;
    START;
    GUIDE;
    LEFT_JOYSTICK;
    RIGHT_JOYSTICK;
    DPAD_UP;
    DPAD_RIGHT;
    DPAD_DOWN;
    DPAD_LEFT;
}
InputState :: enum {
    NONE :: 0x0;
    DOWN :: 0x1;
    START :: 0x2;
}

input: struct {
    keys: [] InputState;
    released_keys: [] bool;

    controller_active: bool;
    controller_joystick_left: Vector2;
    controller_joystick_right: Vector2;
    controller_buttons: [] InputState;
    released_controller_buttons: [] bool;

    mouse_left: InputState;
    released_mouse_left: bool;
    mouse_right: InputState;
    released_mouse_right: bool;
    mouse: Vector2;
    mouse_delta_x: float64;
    mouse_delta_y: float64;
    scroll_delta_x: float64;
    scroll_delta_y: float64;
}

update_inputs :: (); // unsure about this
get_joystick_projected :: () -> bool;
set_joystick_projected :: (enabled: bool);
get_joystick_padding :: () -> float;
set_joystick_padding :: (padding: float);
get_abort_shortcut :: () -> bool;
set_abort_shortcut :: (enabled: bool);
```

## 2D
```jai
Camera2 :: struct {
    position: Vector2;
    rotation: float;
}
PixelFormat :: enum {
    Gray;
    GrayAlpha;
    RGB;
    RGBA;
}
Image :: struct {
    pixels: [] u8;
    width: int;
    height: int;
    format: PixelFormat;
}
Texture :: struct {
    buffer: Gluint;
    width: int;
    height: int;
    format: PixelFormat;
}
RenderTexture :: struct {
    using texture: Texture;
    framebuffer: u32;
}
Sprite :: struct {
    using renderable: Renderable;
    texture: Texture;
    position: Vector2;
    rotation: float;
    width: float;
    height: float;
    anchor: Vector2;
    tint: Color;
    texture_frame: Vector4;
}
SpriteAnimation :: struct {
    name: string;
    start: int;
    count: int;
}
AnimatedSprite :: struct {
    using sprite: Sprite;
    columns: int;
    frame_count: int;
    frame: int; // is frame necessary when there's frame_f
    animations: [..] SpriteAnimation;
    frame_f: float;
}
Container2 :: struct {
    using renderable: Renderable;
    renderables: [..] *Renderable;
    position: Vector2;
    rotation: float;
}

// pixel format
get_stride :: (format: PixelForamt) -> int;
get_gl_format :: (format: PixelFormat) -> GLenum;

// image
load_image :: (path: string) -> Image;
create_image :: (width: int, height: int, format: PixelFormat) -> Image
create_image :: (bytes: [] u8) -> Image; // test
create_image :: (image: Image, position: Point2, size: Point2) -> Image; // test
create_image :: (texture: Texture) -> Image; // test
free :: (image: Image); // test
resize_image :: (image: *Image, size: Point2); // test
resize_image_lock_ratio :: (image: *Image, size: Point2); // test
crop_image :: (image: *Image, position: Point2, size: Point2); // test
clear_image :: (image: *Image); // test
clear_image :: (image: *Image, color: Color); // test
draw_pixel :: (image: *Image, point: Point2, color: Color); // test
draw_rectangle :: (image: *Image, point: Vector2, size: Vector2, color: Color); // implement
draw_rectangle :: (image: *Image, point: Point2, size: Point2, color: Color); // implement
draw_line :: (image: *Image, p1: Vector2, p2: Vector2, width: float, color: Color); // implement
draw_line :: (image: *Image, p1: Point2, p2: Point2, width: int, color: Color); // implement
draw_circle :: (image: *Image, center: Vector2, radius: float, color: Color); // implement
draw_circle :: (image: *Image, center: Point2, radius: int, color: Color); // implement
draw_ellipse :: (image: *Image, center: Vector2, size: Vector2, color: Color); // implement
draw_ellipse :: (image: *Image, center: Point2, size: Point2, color: Color); // implement
draw_polygon :: (image: *Image, polygon: [] Vector2, color: Color); // implement
draw_polygon :: (image: *Image, polygon: [] Point2, color: Color); // implement
get_pixel :: (image: Image, point: Point2) -> Color; // implement
draw :: (destination: *Image, source: Image); // implement
draw :: (destination: *Image, source: Image, position: Point2); // implement
draw :: (destination: *Image, source: Image, dest_position: Point2, dest_size: Point2, source_position: Point2, source_size: Point2); // implement

// texture
load_texture :: (path: string) -> Texture; // test
create_texture :: (bytes: [] u8) -> Texture; // test
create_texture :: (image: Image) -> Texture; // implement
create_texture :: (texture: Texture, frame: Vector4) -> Texture; // implement
upload_texture :: (texture: Texture); // implement
unload_texture :: (texture: Texture); // implement
free :: (texture: Texture); // test
update_texture :: (texture: *Texture, image: Image); // implement
update_texture :: (texture: *Texture, point: Point2, image: Image); // implement
draw :: (texture: Texture, position: Vector2); // test
draw :: (texture: Texture, position: Vector2, size: Vector2); // test

// sprite
create_sprite :: (texture: Texture) -> Sprite; // implement
free :: (sprite: Sprite); // implement
get_scale :: (sprite: Sprite) -> Vector2;
set_scale :: (sprite: *Sprite, scale: Vector2);
draw :: (sprite: Sprite, position: Vector2);
draw :: (sprite: Sprite, transform: Matrix4); // implement
draw :: (sprite: Sprite);

// animated sprite
create_animated_sprite :: (image: Image, frames: [] Vector4) -> AnimatedSprite; // implement
create_animated_sprite :: (texture: Texture, frames: [] Vector4) -> AnimatedSprite; // implement
create_animated_sprite :: (sprite: Sprite, frames: [] Vector4) -> AnimatedSprite; // implement
free :: (animated_sprite: AnimatedSprite); // implement
add_animation :: (animated_sprite: *AnimatedSprite, frame: int, count: int); // implement
remove_animation :: (animated_sprite: *AnimatedSprite, $name: string); // implement
goto_animation :: (animated_sprite: *AnimatedSprite, $name: string, frame: int); // implement
step_animation :: (animated_sprite: *AnimatedSprite, $name: string); // implement
step_animation :: (animated_sprite: *AnimatedSprite, $name: string, frames: float); // implement
draw :: (animated_sprite: AnimatedSprite);

// parallax sprite?
create_row_column_frames :: (columns: int, $frame_count: int) -> [frame_count] Vector4; // implement

// container2
free :: (container: Container2); // test
add_child :: (container: *Container2, renderable: *$T/Renderable); // test
remove_child :: (container: *Container2, renderable: *$T/Renderable); // test
draw :: (container: Container2); // test
```

## 3D
```jai
Camera3 :: struct {
    position: Vector3;
    rotation: Quaternion;
}
Geometry :: struct {
    vao_: GLuint;
    vbo_: GLuint;
    ebo_: GLuint;
    name: string;
    vertices: [..] GeometryVertex;
    vertex_indices: [..] u32;
}
AnimationEasingType :: enum {
    Linear;
}
ModelPoseAnimation :: struct {
    name: string;
    poses: [] [..] Vector3;
    easing: AnimationEasingType;
}
Model :: struct {
    using renderable: Renderable;
    geometry: Geometry;
    uniforms: ShaderUniforms;
    position: Vector3;
    rotation: Quaternion;
    scale: Vector3;
}
AnimatedModel :: struct; // future base model that accepts animation events, maybe this can handle everything
BoneAnimatedModel :: struct; // bone animated model
PoseAnimatedModel :: struct { // key frame animated model by providing multiple poses
    using model: Model;
    animations: [] ModelPoseAnimation;
    frame: float;
}
Container3 :: struct {
    using renderable: Renderable;
    renderables: [..] *Renderable;
    position: Vector3;
    rotation: Quaternion;
}

// TODO upload/unload seems to only have to do with geometry?
// TODO I want a way to inverse kinematic limit animations so feet can't go through floors

// camera3
get_transform :: (camera: Camera3) -> Matrix4; // implement
get_forward_vector :: (camera: Camera3) -> Vector3; // implement
get_up_vector :: (camera: Camera3) -> Vector3; // implement
get_right_vector :: (camera: Camera3) -> Vector3; // implement
look_at :: (camera: *Camera3, target: Vector3); // implement
rotate :: (camera: *Camera3, pitch: float, yaw: float); // implement
rotate :: (camera: *Camera3, pitch: float, yaw: float, up: Vector3); // implement

// geometry
load_geometry :: (path: string) -> [..] *Geometry; // implement
load_and_save_serialized_geometry :: (serialized_path: string, fallback_path: string) -> [..] *Geometry; // implement
upload_geometry :: (texture: *Geometry); // implement
unload_geometry :: (texture: *Geometry); // implement
free :: (geometry: *Geometry); // implement
merge_geometry :: (geometry: *Geometry); // implement
draw :: (geometry: Geometry); // implement
draw :: (geometry: Geometry, position: Vector3); // implement

// geometry shapes
create_plane :: (radius: float) -> *Geometry; // implement
create_plane :: (size: Vector3) -> *Geometry; // implement
create_cube :: (radius: float) -> *Geometry; // implement
create_cube :: (size: Vector3) -> *Geometry; // implement
create_icosphere :: (radius: float, subdivision: int) -> *Geometry; // implement
create_icosphere :: (size: Vector3, subdivision: int) -> *Geometry; // implement
create_cylinder :: (radius: float, subdivisions: int) -> *Geometry; // implement
create_cylinder :: (size: Vector3, subdivisions: int) -> *Geometry; // implement

// model
create_model :: (geometry: Geometry) -> *Model; // implement
create_model :: (geometry: Geometry, texture: Texture) -> *Model; // implement
upload_model :: (model: *Model); // implement
unload_model :: (model: *Model); // implement
free :: (model: *Model); // implement
draw :: (model: Model); // implement

// container3
free :: (container: Container3); // implement
add_child :: (container: *Container3, renderable: *$T/Renderable); // implement
remove_child :: (container: *Container3, renderable: *$T/Renderable); // implement
draw :: (container: Container3); // implement
```

## Rendering
```jai
ShaderUniformType :: enum;
ShaderUniform :: struct {
    name: string;
    type: ShaderUniformType;
    union {};
}
ShaderUniforms :: struct {
    uniforms: [..] ShaderUniform;
}
Shader :: struct {
    program: u32;
    vertex: string;
    fragment: string;
}

// uniforms
operator [] :: (uniforms: ShaderUniforms, $name: string) -> ShaderUniform;
operator [] :: (uniforms: *ShaderUniforms, $name: string) -> *ShaderUniform;
create_uniform :: ($name: string, value: $T) -> ShaderUniform;

// shader
initialize_shader :: (shader: *Shader);
destroy_shader :: (shader: Shader);
use_shader :: (shader: *Shader);
apply_uniforms :: (shader: *Shader, uniforms: ShaderUniforms);
```

## Rendering Pipeline
```jai
Pipeline :: struct {
    passes: [] Pass;
    renderables: [..] *Renderable;
}
Pass :: struct {
    shader: *Shader;
    uniforms: ShaderUniforms;
    textures: [] *Texture;
    render_texture: [] *RenderTexture;
    pass_tags: u32;
}
Renderable :: struct {
    type: RenderableType;
    pass_tag: u32;
    render_priority: int;
}
RenderableType :: enum {
    Sprite;
    Container2;
    Model;
    Container3;
}

// TODO shaders will have a map of texture names to locations, models will have a list of textures with names, and it will auto bind model textures correctly based on name

// TODO have to be sure children don't have shader values that correspond to pass texture names

// pipeline
add_renderable :: (pipeline: *Pipeline, renderable: *Renderable); // implement
remove_renderable :: (pipeline: *Pipeline, renderable: *Renderable); // implement
draw :: (pipeline: *Pipeline); // implement

// pass
draw :: (pass: *Pass); // implement
```

## 2D Shapes
```jai
draw_line :: (p1: Vector2, p2: Vector2, width: float, color: Color); // implement
draw_triangle :: (p1: Vector2, p2: Vector2, p3: Vector2, color: Color); // implement
draw_triangle_lines :: (p1: Vector2, p2: Vector2, p3: Vector2, color: Color); // implement
draw_rectangle :: (point: Vector2, size: Vector2, color: Color); // implement
draw_rectangle_lines :: (point: Vector2, size: Vector2, color: Color); // implement
draw_circle :: (center: Vector2, radius: float, color: Color); // implement
draw_circle_lines :: (center: Vector2, radius: float, color: Color); // implement
draw_ellipse :: (center: Vector2, size: Vector2, color: Color); // implement
draw_ellipse_lines :: (center: Vector2, size: Vector2, color: Color); // implement
draw_polygon :: (polygon: [] Vector2, color: Color); // implement
draw_polygon_lines :: (polygon: [] Vector2, color: Color); // implement
```

## 3D Shapes
```jai
draw_line :: (p1: Vector3, p2: Vector3, color: Color); // implement
draw_triangle :: (p1: Vector3, p2: Vector3, p3: Vector3, color: Color); // implement
draw_cube :: (point: Vector3, size: Vector3, color: Color); // implement
draw_cube_lines :: (point: Vector3, size: Vector3, color: Color); // implement
draw_sphere :: (center: Vector3, radius: float, color: Color); // implement
draw_sphere_lines :: (center: Vector3, radius: float, color: Color); // implement
draw_ellipsoid :: (center: Vector3, size: Vector3, color: Color); // implement
draw_ellipsoid_lines :: (center: Vector3, size: Vector3, color: Color); // implement
draw_polyhedron :: (triangles: [] [3] Vector3, color: Color); // implement
draw_polyhedron_lines :: (triangles: [] [3] Vector3, color: Color); // implement
```

> NOTES
>
> Right now most methods require constant value strings and arrays. This is because it solves most common use cases and doesn't require memory jumping or freeing. I might add more flexible methods in the future if it's needed.
