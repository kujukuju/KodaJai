
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
        set(*pass.uniforms, "uKernel", kernel);

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
        set(*pass.uniforms, "uNoise", noise_texture);
    };
}

shadow_pass: FramebufferPass(0, true, false);
shadow_pass_out: FramebufferPass(1, false, true);
cascaded_shadow_pass: FramebufferPass(0, true, false);
cascaded_shadow_pass_out: FramebufferPass(1, false, true);
geometry_pass: FramebufferPass(3, true, false);
ssao_pass: SsaoPass;
ssao_blur_pass: FramebufferPass(1, false, true);
lighting_pass: FramebufferPass(1, false, true);
edge_pass: FramebufferPass(1, false, true);
sharpen_pass: FramebufferPass(1, false, true);
faaa_pass: FramebufferPass(1, false, true);

// TODO side by side screenshot of framebuffer texture with linear vs nearest... I think it needs to be nearest

shadow_view: Matrix4;
shadow_projection: Matrix4;
casc_shadow_view: Matrix4;
casc_shadow_projection: Matrix4;

deferred_initialize :: () {
    // continue using rgba for byte alignment
    init_framebuffer_pass(*shadow_pass, 2048, 2048, .Depth16);
    init_framebuffer_pass(*shadow_pass_out, *shadow_depth_resolve_shader, .RGBA8);
    init_framebuffer_pass(*cascaded_shadow_pass, 512, 512, .Depth16);
    init_framebuffer_pass(*cascaded_shadow_pass_out, *shadow_depth_resolve_shader, .RGBA8);
    init_framebuffer_pass(*geometry_pass, .RGBA16F, .RGBA16F, .RGBA8, .Depth32F);
    init_framebuffer_pass(*ssao_pass, *ssao_shader, koda.width / 2, koda.height / 2, .R8);
    init_framebuffer_pass(*ssao_blur_pass, *guided_blur_shader, .R8);
    init_framebuffer_pass(*lighting_pass, *directional_light_shader, .RGBA8);
    init_framebuffer_pass(*edge_pass, *edge_shader, .RGBA8);
    init_framebuffer_pass(*sharpen_pass, *sharpen_shader, .RGBA8);
    init_framebuffer_pass(*faaa_pass, *faaa_shader, .RGBA8);

    light_sphere_geometry := create_icosphere(1, 1);
    light_sphere = create_model(light_sphere_geometry);
    light_sphere.shader = *point_light_shader;
    assert(light_sphere_geometry.attributes.count == 1);

    cube_geometry := create_cube(.{200.0, 200.0, 200.0});
    cube_model = create_model(cube_geometry);
    cube_model.shader = *geometry_shader;
    assert(cube_geometry.attributes.count == 1);
    
    for model: models {
        model.shader = *geometry_shader;
    }
}

deferred_render :: () {
    perf_track("render");

    deferred_render_shadows();
    // deferred_render_shadows_to_screen();
    deferred_render_cascaded_shadows();
    // deferred_render_cascaded_shadows_to_screen();
    deferred_render_geometry();
    // deferred_render_geometry_to_screen();
    deferred_render_ssao();
    // deferred_render_ssao_to_screen();
    deferred_render_ssao_blur();
    // deferred_render_ssao_blur_to_screen();
    deferred_render_lighting();
    // deferred_render_lighting_to_screen();
    deferred_render_edge();
    // deferred_render_edge_to_screen();
    deferred_render_sharpen();
    // deferred_render_sharpen_to_screen();
    deferred_render_faaa();
    deferred_render_faaa_to_screen();

    deferred_render_small_shadows_to_screen();
    deferred_render_small_cascaded_shadows_to_screen();

    perf_tracker_finish(1000);
}

deferred_render_shadows :: () {
    perf_track("render_shadows");
    
    framebuffer_bind_write(shadow_pass);

    shadow_dimensions := Point2.{shadow_pass.width, shadow_pass.height};
    shadow_view, shadow_projection = calculate_directional_shadow_matrices(
        light_direction,
        20.0,
        min_depth = 0.0,
        fixed_view_direction = true,
        fixed_shadow_direction = true,
        shadow_texture_dimensions = shadow_dimensions,
        fixed_depth = false);

    view := koda.view;
    defer koda.view = view;
    koda.view = shadow_view;

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
        draw(model, projection = shadow_projection, shader = *shadow_projection_shader);
    }

    cull_face_mode := get_cull_face_mode();
    defer set_cull_face_mode(cull_face_mode);
    set_cull_face_mode(.Front);

    draw(cube_model, projection = shadow_projection, shader = *shadow_projection_shader);
}

deferred_render_shadows_to_screen :: () {
    framebuffer_bind_write(shadow_pass_out);
    
    blend := get_blend();
    defer set_blend(blend);
    set_blend(false);

    set(*shadow_pass_out.uniforms, "uDepth", shadow_pass.depth_texture);

    draw(shadow_pass_out);

    framebuffer_bind_read(shadow_pass_out);
    framebuffer_bind_write_screen();

    glReadBuffer(GL_COLOR_ATTACHMENT0);
    glBlitFramebuffer(0, 0, xx shadow_pass_out.width, xx shadow_pass_out.height, 0, 0, xx koda.width, xx koda.height, GL_COLOR_BUFFER_BIT, GL_LINEAR);
}

deferred_render_small_shadows_to_screen :: () {
    framebuffer_bind_write(shadow_pass_out);
    
    blend := get_blend();
    defer set_blend(blend);
    set_blend(false);

    set(*shadow_pass_out.uniforms, "uDepth", shadow_pass.depth_texture);

    draw(shadow_pass_out);

    framebuffer_bind_read(shadow_pass_out);
    framebuffer_bind_write_screen(.None);

    glReadBuffer(GL_COLOR_ATTACHMENT0);
    glBlitFramebuffer(0, 0, xx shadow_pass_out.width, xx shadow_pass_out.height, 0, xx (koda.height * 3 / 4), xx (koda.width * 1 / 4), xx koda.height, GL_COLOR_BUFFER_BIT, GL_LINEAR);
}

deferred_render_cascaded_shadows :: () {
    perf_track("render_cascaded_shadows");
    
    framebuffer_bind_write(cascaded_shadow_pass);

    shadow_dimensions := Point2.{cascaded_shadow_pass.width, cascaded_shadow_pass.height};
    casc_shadow_view, casc_shadow_projection = calculate_directional_shadow_matrices(
        light_direction,
        80.0,
        min_depth = 20.0,
        fixed_view_direction = true,
        fixed_shadow_direction = true,
        shadow_texture_dimensions = shadow_dimensions,
        fixed_depth = false);

    view := koda.view;
    defer koda.view = view;
    koda.view = casc_shadow_view;

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
        draw(model, projection = casc_shadow_projection, shader = *shadow_projection_shader);
    }

    cull_face_mode := get_cull_face_mode();
    defer set_cull_face_mode(cull_face_mode);
    set_cull_face_mode(.Front);

    draw(cube_model, projection = casc_shadow_projection, shader = *shadow_projection_shader);
}

deferred_render_cascaded_shadows_to_screen :: () {
    framebuffer_bind_write(cascaded_shadow_pass_out);
    
    blend := get_blend();
    defer set_blend(blend);
    set_blend(false);

    set(*shadow_pass_out.uniforms, "uDepth", cascaded_shadow_pass.depth_texture);

    draw(shadow_pass_out);

    framebuffer_bind_read(shadow_pass_out);
    framebuffer_bind_write_screen();

    glReadBuffer(GL_COLOR_ATTACHMENT0);
    glBlitFramebuffer(0, 0, xx shadow_pass_out.width, xx shadow_pass_out.height, 0, 0, xx koda.width, xx koda.height, GL_COLOR_BUFFER_BIT, GL_LINEAR);
}

deferred_render_small_cascaded_shadows_to_screen :: () {
    framebuffer_bind_write(cascaded_shadow_pass_out);
    
    blend := get_blend();
    defer set_blend(blend);
    set_blend(false);

    set(*cascaded_shadow_pass_out.uniforms, "uDepth", cascaded_shadow_pass.depth_texture);

    draw(cascaded_shadow_pass_out);

    framebuffer_bind_read(cascaded_shadow_pass_out);
    framebuffer_bind_write_screen(.None);

    glReadBuffer(GL_COLOR_ATTACHMENT0);
    glBlitFramebuffer(0, 0, xx cascaded_shadow_pass_out.width, xx cascaded_shadow_pass_out.height, 0, xx (koda.height * 2 / 4), xx (koda.width * 1 / 4), xx (koda.height * 3 / 4), GL_COLOR_BUFFER_BIT, GL_LINEAR);
}

deferred_render_geometry :: () {
    perf_track("render_geometry");

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

    cull_face_mode := get_cull_face_mode();
    defer set_cull_face_mode(cull_face_mode);
    set_cull_face_mode(.Front);

    draw(cube_model);
}

deferred_render_geometry_to_screen :: () {
    framebuffer_bind_read(geometry_pass);
    framebuffer_bind_write_screen();

    glReadBuffer(GL_COLOR_ATTACHMENT0 + 2);
    glBlitFramebuffer(0, 0, xx geometry_pass.width, xx geometry_pass.height, 0, 0, xx koda.width, xx koda.height, GL_COLOR_BUFFER_BIT, GL_LINEAR);
}

deferred_render_ssao :: () {
    perf_track("render_ssao");
    framebuffer_bind_write(ssao_pass);

    blend := get_blend();
    defer set_blend(blend);
    set_blend(false);

    projection := get_perspective_matrix();
    set(*ssao_pass.uniforms, "view", koda.view);
    set(*ssao_pass.uniforms, "projection", projection);

    set(*ssao_pass.uniforms, "uPosition", geometry_pass.textures[0]);
    set(*ssao_pass.uniforms, "uNormal", geometry_pass.textures[1]);

    assert(ssao_pass.uniforms[xx "uNoise"].type == .Texture);
    noise_texture := ssao_pass.uniforms[xx "uNoise"].texture;
    noise_scale := Vector2.{cast(float) ssao_pass.width / noise_texture.width, cast(float) ssao_pass.height / noise_texture.height};
    set(*ssao_pass.uniforms, "uNoiseScale", noise_scale);

    draw(ssao_pass);
}

deferred_render_ssao_to_screen :: () {
    framebuffer_bind_read(ssao_pass);
    framebuffer_bind_write_screen();

    glReadBuffer(GL_COLOR_ATTACHMENT0);
    glBlitFramebuffer(0, 0, xx ssao_pass.width, xx ssao_pass.height, 0, 0, xx koda.width, xx koda.height, GL_COLOR_BUFFER_BIT, GL_LINEAR);
}

deferred_render_ssao_blur :: () {
    perf_track("render_ssao_blur");

    framebuffer_bind_write(ssao_blur_pass);

    blend := get_blend();
    defer set_blend(blend);
    set_blend(false);

    projection := get_perspective_matrix();
    set(*ssao_blur_pass.uniforms, "view", koda.view);
    set(*ssao_blur_pass.uniforms, "projection", projection);

    set(*ssao_blur_pass.uniforms, "uPosition", geometry_pass.textures[0]);
    set(*ssao_blur_pass.uniforms, "uSSAO", ssao_pass.textures[0]);

    draw(ssao_blur_pass);
}

deferred_render_ssao_blur_to_screen :: () {
    framebuffer_bind_read(ssao_blur_pass);
    framebuffer_bind_write_screen();

    glReadBuffer(GL_COLOR_ATTACHMENT0);
    glBlitFramebuffer(0, 0, xx ssao_blur_pass.width, xx ssao_blur_pass.height, 0, 0, xx koda.width, xx koda.height, GL_COLOR_BUFFER_BIT, GL_LINEAR);
}

deferred_render_lighting :: () {
    perf_track("render_lighting");

    framebuffer_bind_write(lighting_pass);

    blend := get_blend();
    defer set_blend(blend);
    set_blend(false);

    set(*lighting_pass.uniforms, "view", koda.view);
    set(*lighting_pass.uniforms, "uPosition", geometry_pass.textures[0]);
    set(*lighting_pass.uniforms, "uNormal", geometry_pass.textures[1]);
    set(*lighting_pass.uniforms, "uDiffuse", geometry_pass.textures[2]);
    set(*lighting_pass.uniforms, "uSSAO", ssao_blur_pass.textures[0]);
    set(*lighting_pass.uniforms, "uShadow", shadow_pass.depth_texture);
    set(*lighting_pass.uniforms, "uShadowView", shadow_view);
    set(*lighting_pass.uniforms, "uShadowProjection", shadow_projection);
    set(*lighting_pass.uniforms, "uCascShadow", cascaded_shadow_pass.depth_texture);
    set(*lighting_pass.uniforms, "uCascShadowView", casc_shadow_view);
    set(*lighting_pass.uniforms, "uCascShadowProjection", casc_shadow_projection);

    draw(lighting_pass);

    {
        blend := get_blend();
        defer set_blend(blend);
        set_blend(true);

        blend_equation := get_blend_equation();
        defer set_blend_equation(blend_equation);
        set_blend_equation(.Add);

        blend_src, blend_dst, blend_srca, blend_dsta := get_blend_func_separate();
        defer set_blend_func_separate(blend_src, blend_dst, blend_srca, blend_dsta);
        set_blend_func(.One, .One);

        // draw point light
        set(*point_light_shader.uniforms, "view", koda.view);
        set(*point_light_shader.uniforms, "uPosition", geometry_pass.textures[0]);
        set(*point_light_shader.uniforms, "uNormal", geometry_pass.textures[1]);
        set(*point_light_shader.uniforms, "uDiffuse", geometry_pass.textures[2]);

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

        // draw(light_sphere);
    }
}

deferred_render_lighting_to_screen :: () {
    framebuffer_bind_read(lighting_pass);
    framebuffer_bind_write_screen();

    glReadBuffer(GL_COLOR_ATTACHMENT0);
    glBlitFramebuffer(0, 0, xx lighting_pass.width, xx lighting_pass.height, 0, 0, xx koda.width, xx koda.height, GL_COLOR_BUFFER_BIT, GL_LINEAR);
}

deferred_render_edge :: () {
    perf_track("render_edge");

    framebuffer_bind_write(edge_pass);

    blend := get_blend();
    defer set_blend(blend);
    set_blend(false);

    set(*edge_pass.uniforms, "view", koda.view);
    set(*edge_pass.uniforms, "uColor", lighting_pass.textures[0]);
    set(*edge_pass.uniforms, "uPosition", geometry_pass.textures[0]);
    set(*edge_pass.uniforms, "uDepth", geometry_pass.depth_texture);

    draw(edge_pass);
}

deferred_render_edge_to_screen :: () {
    framebuffer_bind_read(edge_pass);
    framebuffer_bind_write_screen();

    glReadBuffer(GL_COLOR_ATTACHMENT0);
    glBlitFramebuffer(0, 0, xx edge_pass.width, xx edge_pass.height, 0, 0, xx koda.width, xx koda.height, GL_COLOR_BUFFER_BIT, GL_LINEAR);
}

deferred_render_sharpen :: () {
    perf_track("render_sharpen");

    framebuffer_bind_write(sharpen_pass);

    blend := get_blend();
    defer set_blend(blend);
    set_blend(false);

    set(*sharpen_pass.uniforms, "view", koda.view);
    set(*sharpen_pass.uniforms, "uColor", edge_pass.textures[0]);

    draw(sharpen_pass);
}

deferred_render_sharpen_to_screen :: () {
    framebuffer_bind_read(sharpen_pass);
    framebuffer_bind_write_screen();

    glReadBuffer(GL_COLOR_ATTACHMENT0);
    glBlitFramebuffer(0, 0, xx sharpen_pass.width, xx sharpen_pass.height, 0, 0, xx koda.width, xx koda.height, GL_COLOR_BUFFER_BIT, GL_LINEAR);
}

deferred_render_faaa :: () {
    perf_track("render_faaa");

    framebuffer_bind_write(faaa_pass);

    blend := get_blend();
    defer set_blend(blend);
    set_blend(false);

    set(*faaa_pass.uniforms, "uColor", sharpen_pass.textures[0]);

    draw(faaa_pass);
}

deferred_render_faaa_to_screen :: () {
    framebuffer_bind_read(faaa_pass);
    framebuffer_bind_write_screen();

    glReadBuffer(GL_COLOR_ATTACHMENT0);
    glBlitFramebuffer(0, 0, xx faaa_pass.width, xx faaa_pass.height, 0, 0, xx koda.width, xx koda.height, GL_COLOR_BUFFER_BIT, GL_LINEAR);
}

light_sphere: Model;
cube_model: Model;
