
monitor_width :: 2560;
monitor_height :: 1440;
width :: 1920;
height :: 1080;

camera: Camera3;

models: [..] *Model;

light_direction: Vector3;

main :: () {
    koda_init();

    create_window("Deferred Example", 0, 0);
    defer destroy_window();

    major: s32;
    minor: s32;
    glGetIntegerv(GL_MAJOR_VERSION, *major);
    glGetIntegerv(GL_MINOR_VERSION, *minor);

    print("Opengl version: %.%\n", major, minor);

    set_vsync(true);

    koda.fovy = 0.5 * PI;

    light_direction = Vector3.{-0.758616, -0.310689, -0.572684};
    // light_direction = Vector3.{0, -1, 0};

    print("Light direction: %\n", light_direction);

    // set(*color_shader.uniforms, "uLightDirection", light_direction);

    set(*directional_light_shader.uniforms, "uLightDirection", light_direction);
    set(*directional_light_shader.uniforms, "uLightConstant", 0.0);
    set(*directional_light_shader.uniforms, "uLightLinear", 0.04);
    set(*directional_light_shader.uniforms, "uLightExp", 0.2);
    set(*directional_light_shader.uniforms, "uSpecularPower", 0.0);
    set(*directional_light_shader.uniforms, "uDiffuseIntensity", 1.2);
    set(*directional_light_shader.uniforms, "uAmbientIntensity", 0.5);

    set(*point_light_shader.uniforms, "uScreenSize", Vector2.{cast(float) koda.width, cast(float) koda.height});
    set(*point_light_shader.uniforms, "uLightConstant", 0.0);
    set(*point_light_shader.uniforms, "uLightLinear", 0.0);
    set(*point_light_shader.uniforms, "uLightExp", 0.3);
    set(*point_light_shader.uniforms, "uSpecularPower", 0.0);
    set(*point_light_shader.uniforms, "uDiffuseIntensity", 0.5);
    set(*point_light_shader.uniforms, "uAmbientIntensity", 0.5);

    should_bake_material_color_textures = true;
    
    // models = load_models("low_poly_medieval_tavern_reexported.glb");
    models = load_models("low_poly_medieval_tavern_reexported_with_goblin.glb");

    camera.position = .{6, 4, 3};
    look_at(*camera, .{3, 2, -2});
    // camera.position -= get_forward_vector(camera) * 10.0;

    deferred_initialize();

    clear(.{0, 0, 0, 1});

    while !should_exit() {
        reset_temporary_storage();

        update_inputs();

        speed := ifx input.keys[Key.LEFT_SHIFT] then 0.001 else 0.1;

        if input.keys[Key.A] {
            camera.position -= get_right_vector(camera) * speed;
        }
        if input.keys[Key.D] {
            camera.position += get_right_vector(camera) * speed;
        }
        if input.keys[Key.W] {
            camera.position += get_forward_vector(camera) * speed;
        }
        if input.keys[Key.S] {
            camera.position -= get_forward_vector(camera) * speed;
        }
        if input.keys[Key.SPACE] {
            camera.position += get_up_vector(camera) * speed;
        }
        if input.keys[Key.LEFT_CONTROL] {
            camera.position -= get_up_vector(camera) * speed;
        }

        set_mouse_capture(!!input.mouse_right);
        if input.mouse_right {
            yaw_quaternion: Quaternion;
            set_from_axis_and_angle(*yaw_quaternion, .{0, 1, 0}, xx input.mouse_delta_x / 4000.0);
            
            pitch_quaternion: Quaternion;
            set_from_axis_and_angle(*pitch_quaternion, .{1, 0, 0}, xx input.mouse_delta_y / 4000.0);

            camera.rotation = pitch_quaternion * camera.rotation * yaw_quaternion;
        }

        koda.view = get_transform(camera);

        deferred_render();

        draw_fps(10, 10, get_default_font());
    }
}

#import "KodaJai";
#import "JaiGLFW";

#import "Basic";
#import "GL";
#import "Hash_Table";
#import "Math";
#import "Random";
#import "String";
