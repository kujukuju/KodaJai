
SsaoPass :: struct {
    using #as pass: FramebufferPass(1, false, true);
    pass.initializer = (pass: *FramebufferPass(count, depth, drawable)) {
        MAX_KERNEL_SIZE :: 64;
        kernel: [MAX_KERNEL_SIZE] Vector3;
        
        for i: 0..kernel.count - 1 {  
            sample: Vector3;
            sample.x = 2.0 * random_get_zero_to_one() - 1.0;
            sample.y = 2.0 * random_get_zero_to_one() - 1.0;
            sample.z = random_get_zero_to_one();
            sample = normalize(sample);
            sample *= random_get_zero_to_one();

            // acceleration function so more points are located closer to the origin
            scale := cast(float) i / MAX_KERNEL_SIZE;      
            sample *= (0.1 + 0.9 * scale * scale);
            
            kernel[i] = sample;
        }
        pass.uniforms[xx "uKernel"] = create_uniform("uKernel", kernel);

        noise_width :: 4;
        noise_height :: 4;
        noise_image := create_image(4, 4, .RGB32F);
        for y: 0..noise_height - 1 {
            for x: 0..noise_width - 1 {
                // we rotate around the color in tangent space (z axis)
                // TODO so just use RG32F...
                color: Color;
                color.r = random_get_zero_to_one() * 2.0 - 1.0;
                color.g = random_get_zero_to_one() * 2.0 - 1.0;
                color.b = 0;
                draw_pixel(*noise_image, .{x, y}, color);
            }
        }
        noise_texture := create_texture(noise_image, .Repeat, .Nearest);
        pass.uniforms[xx "uNoise"] = create_uniform("uNoise", noise_texture);
    };
}

geometry_pass: FramebufferPass(3, true, false);
ssao_pass: SsaoPass;
lighting_pass: FramebufferPass(0, false, true);

geometry_shader: GeometryShader;
ambient_occlusion_shader: AmbientOcclusionShader;
point_light_shader: PointLightShader;
directional_light_shader: DirectionalLightShader;

// TODO side by side screenshot of framebuffer texture with linear vs nearest... I think it needs to be nearest

deferred_initialize :: () {
    init_framebuffer_pass(*geometry_pass, .RGBA32F, .RGBA32F, .RGBA32F);
    // init_framebuffer_pass(*ssao_pass, *ambient_occlusion_shader, .R32F);
    init_framebuffer_pass(*ssao_pass, *ambient_occlusion_shader, .RGBA32F);
    init_framebuffer_pass(*lighting_pass, *directional_light_shader);

    light_sphere_geometry := create_icosphere(1, 1);
    light_sphere = create_model(light_sphere_geometry);
    light_sphere.shader = *point_light_shader;
    assert(light_sphere_geometry.attributes.count == 1);
    
    for model: models {
        model.shader = *geometry_shader;
    }
}

deferred_render :: () {
    deferred_render_geometry();
    deferred_render_ssao();
    deferred_render_ssao_to_screen();
    // deferred_render_lighting();
}

deferred_render_geometry :: () {
    // bind for writing
    framebuffer_bind_write(geometry_pass);

    depth_write := get_depth_write();
    defer set_depth_write(depth_write);
    set_depth_write(true);

    depth_test := get_depth_test();
    defer set_depth_test(depth_test);
    set_depth_test(true);

    blend := get_blend();
    defer set_blend(blend);
    set_blend(false);

    for model: models {
        draw(model);
    }
}

deferred_render_ssao :: () {
    framebuffer_bind_write(ssao_pass);

    projection := get_perspective_matrix();
    ssao_pass.uniforms[xx "view"] = create_uniform("view", koda.view);
    ssao_pass.uniforms[xx "projection"] = create_uniform("projection", projection);

    ssao_pass.uniforms[xx "uPosition"] = create_uniform("uPosition", geometry_pass.textures[0]);
    ssao_pass.uniforms[xx "uNormal"] = create_uniform("uNormal", geometry_pass.textures[2]);
    ssao_pass.uniforms[xx "uDepth"] = create_uniform("uDepth", geometry_pass.depth_texture);

    assert(ssao_pass.uniforms[xx "uNoise"].type == .Texture);
    noise_texture := ssao_pass.uniforms[xx "uNoise"].texture;
    noise_scale := Vector2.{cast(float) koda.width / noise_texture.width, cast(float) koda.height / noise_texture.height};
    ssao_pass.uniforms[xx "uNoiseScale"] = create_uniform("uNoiseScale", noise_scale);

    draw(ssao_pass);
}

deferred_render_ssao_to_screen :: () {
    framebuffer_bind_read(ssao_pass);
    framebuffer_bind_write_screen();

    width := cast(s32) koda.width;
    height := cast(s32) koda.height;

    glReadBuffer(GL_COLOR_ATTACHMENT0);
    glBlitFramebuffer(0, 0, width, height, 0, 0, width, height, GL_COLOR_BUFFER_BIT, GL_LINEAR);
}

deferred_render_lighting :: () {
    // restore the screen fbo
    framebuffer_bind_write_screen();

    blend := get_blend();
    defer set_blend(blend);
    set_blend(true);

    blend_equation := get_blend_equation();
    defer set_blend_equation(blend_equation);
    set_blend_equation(.Add);

    blend_src, blend_dst := get_blend_func();
    defer set_blend_func(blend_src, blend_dst);
    set_blend_func(.One, .One);

    lighting_pass.uniforms[xx "view"] = create_uniform("view", koda.view);
    lighting_pass.uniforms[xx "uPosition"] = create_uniform("uPosition", geometry_pass.textures[0]);
    lighting_pass.uniforms[xx "uDiffuse"] = create_uniform("uDiffuse", geometry_pass.textures[1]);
    lighting_pass.uniforms[xx "uNormal"] = create_uniform("uNormal", geometry_pass.textures[2]);

    draw(lighting_pass);

    // draw point light
    point_light_shader.uniforms[xx "view"] = create_uniform("view", koda.view);
    point_light_shader.uniforms[xx "uPosition"] = create_uniform("uPosition", geometry_pass.textures[0]);
    point_light_shader.uniforms[xx "uDiffuse"] = create_uniform("uDiffuse", geometry_pass.textures[1]);
    point_light_shader.uniforms[xx "uNormal"] = create_uniform("uNormal", geometry_pass.textures[2]);

    light_position :: Vector3.{2, 2, -2};
    light_radius :: 4.0;

    light_sphere.position = light_position;
    light_sphere.scale = Vector3.{light_radius, light_radius, light_radius};

    // technically if you want to do this right you would reenable the depth test, use back face culling, and use a stencil buffer to indicate front facing or back facing sphere
    cull_face_mode := get_cull_face_mode();
    defer set_cull_face_mode(cull_face_mode);
    set_cull_face_mode(.Front);

    depth_write := get_depth_write();
    defer set_depth_write(depth_write);
    set_depth_write(false);

    depth_test := get_depth_test();
    defer set_depth_test(depth_test);
    set_depth_test(false);

    draw(light_sphere);
}

light_sphere: Model;
