
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
    // light_direction = Vector3.{0, 0, -1};
    // light_direction = rotate(light_direction, Quaternion.{0.173, 0.277, 0.257, 0.910});
    // light_direction.y, light_direction.z = light_direction.z, light_direction.y;
    // light_direction.z = -light_direction.z;
    print("Light direction: %\n", light_direction);

    // color_shader.uniforms[xx "uLightDirection"] = create_uniform("uLightDirection", light_direction);

    directional_light_shader.uniforms[xx "uLightDirection"] = create_uniform("uLightDirection", light_direction);
    directional_light_shader.uniforms[xx "uLightConstant"] = create_uniform("uLightConstant", 0.0);
    directional_light_shader.uniforms[xx "uLightLinear"] = create_uniform("uLightLinear", 0.04);
    directional_light_shader.uniforms[xx "uLightExp"] = create_uniform("uLightExp", 0.2);
    directional_light_shader.uniforms[xx "uSpecularPower"] = create_uniform("uSpecularPower", 0.0);
    directional_light_shader.uniforms[xx "uDiffuseIntensity"] = create_uniform("uDiffuseIntensity", 1.2);
    directional_light_shader.uniforms[xx "uAmbientIntensity"] = create_uniform("uAmbientIntensity", 0.5);

    point_light_shader.uniforms[xx "uScreenSize"] = create_uniform("uScreenSize", Vector2.{cast(float) koda.width, cast(float) koda.height});
    point_light_shader.uniforms[xx "uLightConstant"] = create_uniform("uLightConstant", 0.0);
    point_light_shader.uniforms[xx "uLightLinear"] = create_uniform("uLightLinear", 0.0);
    point_light_shader.uniforms[xx "uLightExp"] = create_uniform("uLightExp", 0.3);
    point_light_shader.uniforms[xx "uSpecularPower"] = create_uniform("uSpecularPower", 0.0);
    point_light_shader.uniforms[xx "uDiffuseIntensity"] = create_uniform("uDiffuseIntensity", 0.5);
    point_light_shader.uniforms[xx "uAmbientIntensity"] = create_uniform("uAmbientIntensity", 0.5);

    models = load_models("low_poly_medieval_tavern_reexported.glb");
    // models = load_models("low_poly_medieval_tavern_reexported_with_goblin.glb");

    camera.position = .{6, 4, 3};
    look_at(*camera, .{3, 2, -2});

    deferred_initialize();

    clear(.{0, 0, 0, 1});

    while !should_exit() {
        reset_temporary_storage();

        update_inputs();

        if input.keys[Key.A] {
            camera.position -= get_right_vector(camera) * 0.1;
        }
        if input.keys[Key.D] {
            camera.position += get_right_vector(camera) * 0.1;
        }
        if input.keys[Key.W] {
            camera.position += get_forward_vector(camera) * 0.1;
        }
        if input.keys[Key.S] {
            camera.position -= get_forward_vector(camera) * 0.1;
        }
        if input.keys[Key.SPACE] {
            camera.position += get_up_vector(camera) * 0.1;
        }
        if input.keys[Key.LEFT_CONTROL] {
            camera.position -= get_up_vector(camera) * 0.1;
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

        draw_fps(10, 10);
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
