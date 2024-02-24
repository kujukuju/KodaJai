
FramebufferPass :: struct (count: int, depth: bool, drawable: bool, multisample: int = 0) {
    framebuffer: u32;
    // the output textures
    textures: [count] Texture;
    depth_texture: Texture;
    shader: *Shader;
    uniforms: ShaderUniforms;
    width: int;
    height: int;
    vao: u32;
    vbo: u32;
    initializer: #type (pass: *FramebufferPass(count, depth, drawable, multisample));
}

create_framebuffer_pass :: (shader: *Shader, $channels: ..PixelFormat, $depth: bool, $drawable: bool, $multisample: int = 0) -> FramebufferPass(channels.count, depth, drawable, multisample) {
    pass: FramebufferPass(channels.count, depth, drawable);
    init_framebuffer_pass(*pass, shader, ..channels);

    return pass;
}

init_framebuffer_pass :: (pass: *FramebufferPass($count, $depth, true, $multisample), shader: *Shader, channels: ..PixelFormat) {
    assert(!!shader, "If your framebuffer pass is drawable you must provide a shader.\n");
    init_framebuffer_pass_internal(pass, shader, koda.width, koda.height, ..channels);
}

init_framebuffer_pass :: (pass: *FramebufferPass($count, $depth, true, $multisample), shader: *Shader, width: int, height: int, channels: ..PixelFormat) {
    assert(!!shader, "If your framebuffer pass is drawable you must provide a shader.\n");
    init_framebuffer_pass_internal(pass, shader, width, height, ..channels);
}

init_framebuffer_pass :: (pass: *FramebufferPass($count, $depth, false, $multisample), channels: ..PixelFormat) {
    init_framebuffer_pass_internal(pass, null, koda.width, koda.height, ..channels);
}

init_framebuffer_pass :: (pass: *FramebufferPass($count, $depth, false, $multisample), width: int, height: int, channels: ..PixelFormat) {
    init_framebuffer_pass_internal(pass, null, width, height, ..channels);
}

init_framebuffer_pass_internal :: (pass: *FramebufferPass($count, $depth, $drawable, $multisample), shader: *Shader, width: int, height: int, channels: ..PixelFormat) {
    required_count := count;
    if depth then required_count += 1;
    if required_count != channels.count {
        assert(false, "Passed invalid number of predefined channels to initialize a framebuffer pass.\n");
        return;
    }

    pass.shader = shader;
    pass.width = width;
    pass.height = height;
    
    #if count > 0 || depth {
        glGenFramebuffers(1, *pass.framebuffer);
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, pass.framebuffer);

        assert(multisample == 0, "Multisamlping temporary disabled.\n");

        // TODO nearest?
        for index: 0..count - 1 {
            channel := channels[index];
            pass.textures[index] = create_texture(width, height, channel, .Clamp, .Linear);
            glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0 + cast(u32) index, GL_TEXTURE_2D, pass.textures[index].buffer, 0);
        }

        #if depth {
            pass.depth_texture = create_texture(width, height, channels[channels.count - 1], .Border, .Linear, shadow = true, should_upload = false);
            pass.depth_texture.border_color = .{1, 1, 1, 1};
            upload(*pass.depth_texture);
            glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, pass.depth_texture.buffer, 0);
        }

        #if count > 0 {
            draw_buffers: [count] u32;
            for i: 0..draw_buffers.count - 1 {
                draw_buffers[i] = GL_COLOR_ATTACHMENT0 + cast(u32) i;
            }

            glDrawBuffers(draw_buffers.count, draw_buffers.data);
        }

        status := glCheckFramebufferStatus(GL_FRAMEBUFFER);
        if status != GL_FRAMEBUFFER_COMPLETE {
            print("Framebuffer error: %\n", status);
            print_stack_trace();
            assert(false, "Framebuffer error.\n");
        }

        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
    }

    #if drawable {
        vertices :: Vector2.[
            .{-1.0, 1.0}, .{-1.0, -1.0}, .{1.0, 1.0},
            .{-1.0, -1.0}, .{1.0, -1.0}, .{1.0, 1.0},
        ];

        glGenBuffers(1, *pass.vbo);
        glBindBuffer(GL_ARRAY_BUFFER, pass.vbo);
        glBufferData(GL_ARRAY_BUFFER, size_of(type_of(vertices)), vertices.data, GL_STATIC_DRAW);

        glGenVertexArrays(1, *pass.vao);
        glBindVertexArray(pass.vao);

        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * size_of(float), null);
        glEnableVertexAttribArray(0);

        glBindVertexArray(0);
    }

    if pass.initializer {
        pass.initializer(pass);
    }
}

// TODO I'm not actually sure if there's a use for a read and write bind

// framebuffer_bind :: (pass: FramebufferPass($c, $depth, $dr, $m)) {
//     glBindFramebuffer(GL_DRAW_FRAMEBUFFER, pass.framebuffer);

//     #if depth {
//         clear(.Color | .Depth);
//     } else {
//         clear(.Color);
//     }
// }

// framebuffer_bind_screen :: () {
//     glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);

//     clear(.Color | .Depth);
// }

framebuffer_bind_write :: (pass: FramebufferPass($c, $depth, $dr, $m), mask: ClearMask = .Color | .Depth | .Stencil) {
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, pass.framebuffer);
    glViewport(0, 0, xx pass.width, xx pass.height);

    #if depth {
        clear(mask & (.Color | .Depth));
    } else {
        clear(mask & .Color);
    }
}

framebuffer_bind_write_screen :: (mask: ClearMask = .Color | .Depth | .Stencil) {
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
    glViewport(0, 0, xx koda.width, xx koda.height);

    clear(mask & (.Color | .Depth));
}

framebuffer_bind_read :: (pass: FramebufferPass) {
    glBindFramebuffer(GL_READ_FRAMEBUFFER, pass.framebuffer);
}

framebuffer_bind_read_screen :: () {
    glBindFramebuffer(GL_READ_FRAMEBUFFER, 0);
}

framebuffer_resolve_color :: (pass: FramebufferPass($p_c, $p_d, $p_dr, $p_ms), texture_index: int, resolved: FramebufferPass($r_c, $r_d, $r_dr, $r_ms)) {
    assert(p_c > texture_index, "You cannot resolve a texture index that doesn't exist.");
    assert(r_c == 1, "You cannot resolve color into a framebuffer with more than 1 texture.");

    framebuffer_bind_read(pass);
    framebuffer_bind_write(resolved);

    interp: u32 = GL_NEAREST;
    if pass.width != resolved.width || pass.height != resolved.height {
        interp = GL_LINEAR;
    }

    glReadBuffer(GL_COLOR_ATTACHMENT0 + cast(u32) texture_index);
    glBlitFramebuffer(0, 0, xx pass.width, xx pass.height, 0, 0, xx resolved.width, xx resolved.height, GL_COLOR_BUFFER_BIT, interp);
}

framebuffer_resolve_color_screen :: (pass: FramebufferPass($p_c, $p_d, $p_dr, $p_ms), texture_index: int) {
    assert(p_c > texture_index, "You cannot resolve a texture index that doesn't exist.");

    framebuffer_bind_read(pass);
    framebuffer_bind_write_screen();

    interp: u32 = GL_NEAREST;
    if pass.width != koda.width || pass.height != koda.height {
        interp = GL_LINEAR;
    }

    glReadBuffer(GL_COLOR_ATTACHMENT0 + cast(u32) texture_index);
    glBlitFramebuffer(0, 0, xx pass.width, xx pass.height, 0, 0, xx koda.width, xx koda.height, GL_COLOR_BUFFER_BIT, interp);
}

framebuffer_resolve_depth :: (pass: FramebufferPass($p_c, $p_d, $p_dr, $p_ms), resolved: FramebufferPass($r_c, $r_d, $r_dr, $r_ms)) {
    assert(p_d && r_d, "You cannot resolve depth if both framebuffers don't have a depth texture.");

    framebuffer_bind_read(pass);
    framebuffer_bind_write(resolved);

    // interp: u32 = GL_NEAREST;
    // if pass.width != resolved.width || pass.height != resolved.height {
    //     interp = GL_LINEAR;
    //     print("Warning: I don't think it makes sense to resolve a depth buffer without having matching dimensions since depth values aren't linear... But okay here we go anyways...\n");
    // }

    glBlitFramebuffer(0, 0, xx pass.width, xx pass.height, 0, 0, xx resolved.width, xx resolved.height, GL_DEPTH_BUFFER_BIT, GL_NEAREST);
}

framebuffer_resolve_depth_screen :: (pass: FramebufferPass($p_c, $p_d, $p_dr, $p_ms)) {
    assert(p_d, "You cannot resolve depth if both framebuffers don't have a depth texture.");

    framebuffer_bind_read(pass);
    framebuffer_bind_write_screen();

    // interp: u32 = GL_NEAREST;
    // if pass.width != koda.width || pass.height != koda.height {
    //     interp = GL_LINEAR;
    //     print("Warning: I don't think it makes sense to resolve a depth buffer without having matching dimensions since depth values aren't linear... But okay here we go anyways...\n");
    // }

    glBlitFramebuffer(0, 0, xx pass.width, xx pass.height, 0, 0, xx koda.width, xx koda.height, GL_DEPTH_BUFFER_BIT, GL_NEAREST);
}

draw :: (pass: FramebufferPass($count, $depth, $drawable)) {
    #if !drawable {
        assert(false, "You cannot draw a framebuffer that is not drawable.\n");
        return;
    }

    // draw quad
    use_shader(pass.shader);
    
    apply_uniforms(pass.shader, pass.uniforms);

    // uniforms: ShaderUniforms;
    // defer destroy(uniforms);
    
    // // TODO im not actually sure if this should be
    // apply_uniforms(pass.shader, uniforms);

    // we're rendering the screenspace framebuffer so no depth testing or writing
    depth_write := get_depth_write();
    defer set_depth_write(depth_write);
    set_depth_write(false);

    depth_test := get_depth_test();
    defer set_depth_test(depth_test);
    set_depth_test(false);

    glBindVertexArray(pass.vao);
    glDrawArrays(GL_TRIANGLES, 0, 6);
    glBindVertexArray(0);
}