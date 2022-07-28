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

init :: ();

get_window :: () -> *GLFWWindow;
create_window :: ();
destroy_window :: ();

should_exit :: () -> bool;

get_fullscreen :: () -> bool;
set_fullscreen :: (fullscreen: bool);
get_vsync :: () -> bool;
set_vsync :: (vsync: bool);
get_target_fps :: () -> float;
set_target_fps :: (fps: float);
get_mouse_captured :: () -> bool;
set_mouse_captured :: (captured: bool);
get_front_face_ccw :: () -> bool;
set_front_face_ccw :: (ccw: bool);
get_depth_test :: () -> bool;
set_depth_test :: (enabled: bool);
get_cull_face :: () -> bool;
set_cull_face :: (enabled: bool);

clear :: (color: Color);

begin_render_target :: (render_texture: RenderTexture);
end_render_target :: ();
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
    controller: [] InputState;
    released_controller: [] bool;

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
clear_input_deltas :: (); // unsure about this
get_joystick_projected :: () -> bool;
set_joystick_projected :: (enabled: bool);
get_joystick_padding :: () -> float;
set_joystick_padding :: (padding: float);
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
    frame: int;
    animations: [..] SpriteAnimation;
    frame_f: float;
}
Container2 :: struct {
    using renderable: Renderable;
    models: [..] *Sprite;
    position: Vector2;
    rotation: float;
}

// pixel format
get_stride :: (format: PixelForamt) -> int;
get_gl_format :: (format: PixelFormat) -> GLenum;

// image
load_image :: (path: string) -> Image;
create_image :: (bytes: [] u8) -> Image;
create_image :: (image: Image, position: Point2, size: Point2) -> Image;
create_image :: (texture: Texture) -> Image;
destroy_image :: (image: Image);
resize_image :: (image: *Image, size: Point2);
resize_image_lock_ratio :: (image: *Image, size: Point2);
crop_image :: (image: *Image, position: Point2, size: Point2);
clear_image :: (image: *Image);
clear_image :: (image: *Image, color: Color);
draw_pixel :: (image: *Image, point: Point2, color: Color);
draw_rectangle :: (image: *Image, point: Vector2, size: Vector2, color: Color);
draw_rectangle :: (image: *Image, point: Point2, size: Point2, color: Color);
draw_line :: (image: *Image, p1: Vector2, p2: Vector2, width: float, color: Color);
draw_line :: (image: *Image, p1: Point2, p2: Point2, width: int, color: Color);
draw_circle :: (image: *Image, center: Vector2, radius: float, color: Color);
draw_circle :: (image: *Image, center: Point2, radius: int, color: Color);
draw_ellipse :: (image: *Image, center: Vector2, size: Vector2, color: Color);
draw_ellipse :: (image: *Image, center: Point2, size: Point2, color: Color);
draw_polygon :: (image: *Image, polygon: [] Vector2, color: Color);
draw_polygon :: (image: *Image, polygon: [] Point2, color: Color);
get_pixel :: (image: Image, point: Point2) -> Color;
draw :: (destination: *Image, source: Image);
draw :: (destination: *Image, source: Image, position: Point2);
draw :: (destination: *Image, source: Image, dest_position: Point2, dest_size: Point2, source_position: Point2, source_size: Point2);

// texture
load_texture :: (path: string) -> Texture;
create_texture :: (bytes: [] u8) -> Texture;
create_texture :: (image: Image) -> Texture;
create_texture :: (texture: Texture, frame: Vector4) -> Texture;
upload_texture :: (texture: Texture);
unload_texture :: (texture: Texture);
destroy_texture :: (texture: Texture);
update_texture :: (texture: *Texture, pixels: Image);
update_texture :: (texture: *Texture, point: Point2, pixels: Image);
draw :: (texture: Texture, position: Vector2);
draw :: (texture: Texture, position: Vector2, size: Vector2);

// sprite
create_sprite :: (texture: Texture) -> Sprite;
destroy_sprite :: (sprite: Sprite);
draw :: (sprite: Sprite);

// animated sprite
create_animated_sprite :: (image: Image, frames: [] Vector4) -> AnimatedSprite;
create_animated_sprite :: (texture: Texture, frames: [] Vector4) -> AnimatedSprite;
create_animated_sprite :: (sprite: Sprite, frames: [] Vector4) -> AnimatedSprite;
destroy_animayed_sprite :: (animated_sprite: AnimatedSprite);
add_animation :: (animated_sprite: *AnimatedSprite, frame: int, count: int);
remove_animation :: (animated_sprite: *AnimatedSprite, $name: string);
goto_animation :: (animated_sprite: *AnimatedSprite, $name: string, frame: int);
step_animation :: (animated_sprite: *AnimatedSprite, $name: string);
step_animation :: (animated_sprite: *AnimatedSprite, $name: string, frames: float);
draw :: (animated_sprite: AnimatedSprite);

create_row_column_frames :: (columns: int, $frame_count: int) -> [frame_count] Vector4;

// container2
destroy_container :: (container: Container2);
add_child :: (container: *Container2, renderable: *$T/Renderable);
remove_child :: (container: *Container2, renderable: *$T/Renderable);
draw :: (container: Container2);
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
Model :: struct {
    using renderable: Renderable;
    geometry: Geometry;
    textures: [] Texture;
    position: Vector3;
    rotation: Quaternion;
}
AnimatedModel :: struct; // future base model that accepts animation events, maybe this can handle everything
BoneAnimatedModel :: struct; // bone animated model
PoseAnimatedModel :: struct; // key frame animated model by providing multiple poses
Container3 :: struct {
    using renderable: Renderable;
    models: [..] *Renderable;
    position: Vector3;
    rotation: Quaternion;
}

// camera3
get_transform :: (camera: Camera3) -> Matrix4;
get_forward_vector :: (camera: Camera3) -> Vector3;
get_up_vector :: (camera: Camera3) -> Vector3;
get_right_vector :: (camera: Camera3) -> Vector3;
look_at :: (camera: *Camera3, target: Vector3);
rotate :: (camera: *Camera3, pitch: float, yaw: float);
rotate :: (camera: *Camera3, pitch: float, yaw: float, up: Vector3);

// geometry
load_geometry :: (path: string) -> Geometry;
load_and_save_serialized_geometry :: (serialized_path: string, fallback_path: string) -> Geometry;
upload_geometry :: (texture: Geometry);
unload_geometry :: (texture: Geometry);
destroy_geometry :: (geometry: Geometry);
merge_geometry :: (geometry: *Geometry);
draw_geometry :: (geometry: Geometry, position: Vector3);

// geometry shapes
create_plane :: (radius: float) -> Geometry;
create_plane :: (size: Vector3) -> Geometry;
create_cube :: (radius: float) -> Geometry;
create_cube :: (size: Vector3) -> Geometry;
create_icosphere :: (radius: float, subdivision: int) -> Geometry;
create_icosphere :: (size: Vector3, subdivision: int) -> Geometry;
create_cylinder :: (radius: float, subdivisions: int) -> Geometry;
create_cylinder :: (size: Vector3, subdivisions: int) -> Geometry;

// model
create_model :: (geometry: Geometry) -> Model;
create_model :: (geometry: Geometry, textures: [] Texture) -> Model;
upload_model :: (model: Model);
unload_model :: (model: Model);
destroy_model :: (model: Model);
draw_model :: (model: Model);

// container3
destroy_container :: (container: Container3);
add_child :: (container: *Container3, renderable: *$T/Renderable);
remove_child :: (container: *Container3, renderable: *$T/Renderable);
draw :: (container: Container3);
```

## Rendering
```jai
ShaderUniformType :: enum;
ShaderUniform :: struct {
    name: string;
    location: GLint;
    type: ShaderUniformType;
    data: *void;
    size: int;
}
Shader :: struct {
    vertex: string;
    fragment: string;
    uniforms: [..] ShaderUniform;
    program: GLuint;
}
```

## Rendering Pipeline
```jai
Pipeline :: struct {
    passes: [] Pass;
    renderables: [] *Renderable;
}
Pass :: struct {
    shader: *Shader;
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

```

## 2D Shapes
```jai
draw_line :: (p1: Vector2, p2: Vector2, width: float, color: Color);
draw_triangle :: (p1: Vector2, p2: Vector2, p3: Vector2, color: Color);
draw_triangle_lines :: (p1: Vector2, p2: Vector2, p3: Vector2, color: Color);
draw_rectangle :: (point: Vector2, size: Vector2, color: Color);
draw_rectangle_lines :: (point: Vector2, size: Vector2, color: Color);
draw_circle :: (center: Vector2, radius: float, color: Color);
draw_circle_lines :: (center: Vector2, radius: float, color: Color);
draw_ellipse :: (center: Vector2, size: Vector2, color: Color);
draw_ellipse_lines :: (center: Vector2, size: Vector2, color: Color);
draw_polygon :: (polygon: [] Vector2, color: Color);
draw_polygon_lines :: (polygon: [] Vector2, color: Color);
```

## 3D Shapes
```jai
draw_line :: (p1: Vector3, p2: Vector3, color: Color);
draw_triangle :: (p1: Vector3, p2: Vector3, p3: Vector3, color: Color);
draw_cube :: (point: Vector3, size: Vector3, color: Color);
draw_cube_lines :: (point: Vector3, size: Vector3, color: Color);
draw_sphere :: (center: Vector3, radius: float, color: Color);
draw_sphere_lines :: (center: Vector3, radius: float, color: Color);
draw_ellipsoid :: (center: Vector3, size: Vector3, color: Color);
draw_ellipsoid_lines :: (center: Vector3, size: Vector3, color: Color);
draw_polyhedron :: (triangles: [] [3] Vector3, color: Color);
draw_polyhedron_lines :: (triangles: [] [3] Vector3, color: Color);
```

> NOTES
>
> Right now most methods require constant value strings and arrays. This is because it solves most common use cases and doesn't require memory jumping or freeing. I might add more flexible methods in the future if it's needed.