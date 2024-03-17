
FramebufferPass :: struct (count: int, depth: bool, drawable: bool, multisample: int = 0) {
    framebuffer: u32;
    // the output textures
    textures: [count] Texture;
    depth_texture: Texture;
    shader: *Shader;
    uniforms: ShaderUniforms;
    channels: [count] PixelFormat;
    depth_channel: PixelFormat;
    width: int;
    height: int;
    vao: u32;
    vbo: u32;
    initializer: #type (pass: *FramebufferPass(count, depth, drawable, multisample));
}

init_framebuffer_pass :: (pass: *FramebufferPass($count, $depth, false, $multisample)) {
    init_framebuffer_pass_internal(pass, null);
}

init_framebuffer_pass :: (pass: *FramebufferPass($count, $depth, false, $multisample), channels: ..PixelFormat) {
    init_framebuffer_pass_internal(pass, null, koda.width, koda.height, channels);
}

init_framebuffer_pass :: (pass: *FramebufferPass($count, $depth, false, $multisample), width: int, height: int, channels: ..PixelFormat) {
    init_framebuffer_pass_internal(pass, null, width, height, channels);
}

init_framebuffer_pass :: (pass: *FramebufferPass($count, $depth, false, $multisample), textures: ..Texture) {
    init_framebuffer_pass_internal(pass, null, textures[0].width, textures[0].height, textures);
}

init_framebuffer_pass :: (pass: *FramebufferPass($count, $depth, true, $multisample), shader: *Shader) {
    init_framebuffer_pass_internal(pass, shader);
}

init_framebuffer_pass :: (pass: *FramebufferPass($count, $depth, true, $multisample), shader: *Shader, channels: ..PixelFormat) {
    init_framebuffer_pass_internal(pass, shader, koda.width, koda.height, channels);
}

init_framebuffer_pass :: (pass: *FramebufferPass($count, $depth, true, $multisample), shader: *Shader, textures: ..Texture) {
    init_framebuffer_pass_internal(pass, shader, textures[0].width, textures[0].height, textures);
}

init_framebuffer_pass :: (pass: *FramebufferPass($count, $depth, true, $multisample), shader: *Shader, width: int, height: int, channels: ..PixelFormat) {
    init_framebuffer_pass_internal(pass, shader, width, height, channels);
}

init_framebuffer_pass_internal :: (pass: *FramebufferPass($count, $depth, $drawable, $multisample), shader: *Shader, width: int, height: int, channels: [] PixelFormat) {
    textures := framebuffer_create_textures(count, depth, width, height, ..channels);

    init_framebuffer_pass_internal(pass, shader, width, height, textures);
}

init_framebuffer_pass_internal :: (pass: *FramebufferPass($count, $depth, $drawable, $multisample), shader: *Shader, width: int, height: int, textures: [] Texture) {
    assert(!drawable || shader, "If your framebuffer pass is drawable you must provide a shader.\n");

    required_count :: count + #ifx depth then 1 else 0;
    if required_count != textures.count {
        assert(false, "Passed invalid number of textures to initialize a framebuffer pass.\n");
        return;
    }

    assert(multisample == 0, "Multisamlping temporary disabled. Textures aren't set up really well to work with it.\n");

    pass.shader = shader;

    init_framebuffer_pass_buffers(pass);

    #if count > 0 || depth {
        framebuffer_resize(pass, width, height, ..textures, destroy = false);
    }

    if pass.initializer {
        pass.initializer(pass);
    }
}

init_framebuffer_pass_internal :: (pass: *FramebufferPass($count, $depth, $drawable, $multisample), shader: *Shader) {
    pass.shader = shader;

    init_framebuffer_pass_buffers(pass);

    if pass.initializer {
        pass.initializer(pass);
    }
}

init_framebuffer_pass_buffers :: (pass: *FramebufferPass($count, $depth, $drawable, $multisample)) {
    #if count > 0 || depth {
        glGenFramebuffers(1, *pass.framebuffer);
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
}

framebuffer_destroy :: (pass: *FramebufferPass($count, $depth, $drawable, $multisample), children: bool = true) {
    if pass.framebuffer {
        glDeleteFramebuffers(1, *pass.framebuffer);
        pass.framebuffer = 0;
    }

    if pass.vbo {
        glDeleteBuffers(1, *pass.vbo);
        pass.vbo = 0;
    }

    if pass.vao {
        glDeleteVertexArrays(1, *pass.vao);
        pass.vao = 0;
    }

    if pass.uniforms.uniforms {
        destroy(pass.uniforms);
        pass.uniforms = .{};
    }

    if children {
        for texture: pass.textures {
            destroy(texture);
        }
        pass.textures = .[];

        destroy(depth_texture);
        pass.depth_texture = .{};
    }
}

framebuffer_create_textures :: ($count: int, $depth: bool, width: int, height: int, channels: ..PixelFormat) -> [count + cast(int) depth] Texture {
    required_count :: count + #ifx depth then 1 else 0;
    if required_count != channels.count {
        assert(false, "Passed invalid number of channels to initialize a framebuffer pass.\n");
        return .[];
    }

    textures: [required_count] Texture;

    for index: 0..count - 1 {
        textures[index] = create_texture(width, height, channels[index], .Clamp, .Nearest);
    }

    #if depth {
        // TODO I'm not sure if border helps at all honestly
        depth_texture := create_texture(width, height, channels[channels.count - 1], .Border, .Nearest, shadow = true, should_upload = false);
        depth_texture.border_color = .{1, 1, 1, 1};
        upload(*depth_texture);

        textures[textures.count - 1] = depth_texture;
    }

    return textures;
}

framebuffer_resize :: (pass: *FramebufferPass($count, $depth, $drawable, $multisample), textures: ..Texture, should_destroy: bool = false) {
    assert(textures.count > 0, "If you pass in textures you must provide at least 1.\n");
    framebuffer_resize(pass, textures[0].width, textures[0].height, textures, should_destroy);
}

framebuffer_resize :: (pass: *FramebufferPass($count, $depth, $drawable, $multisample), width: int, height: int, channels: ..PixelFormat, should_destroy: bool = false) {
    textures := framebuffer_create_textures(count, depth, width, height, ..channels);

    framebuffer_resize(pass, ..textures, should_destroy);
}

framebuffer_resize :: (pass: *FramebufferPass($count, $depth, $drawable, $multisample), width: int, height: int, textures: [] Texture, should_destroy: bool = false) {
    required_count :: count + #ifx depth then 1 else 0;
    if required_count != textures.count {
        assert(false, "Passed invalid number of textures to resize a framebuffer pass.\n");
        return;
    }
    
    for i: 0..textures.count - 1 {
        assert(textures[i].width == width && textures[i].height == height, "Your framebuffer textures must be matching dimensions per pass.\n");
    }

    pass.width = width;
    pass.height = height;

    if should_destroy {
        for i: 0..count - 1 {
            if pass.textures[i].buffer != textures[i].buffer {
                destroy(pass.textures[i]);
            }
        }

        #if depth {
            if pass.depth_texture.buffer != textures[textures.count - 1].buffer {
                destroy(pass.depth_texture);
            }
        }
    }

    for i: 0..count - 1 {
        pass.channels[i] = textures[i].format;
        pass.textures[i] = textures[i];
    }

    #if depth {
        pass.depth_channel = textures[textures.count - 1].format;
        pass.depth_texture = textures[textures.count - 1];
    }

    framebuffer_bind_textures(pass);
}

framebuffer_bind_textures :: (pass: *FramebufferPass($count, $depth, $drawable, $multisample)) {
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, pass.framebuffer);

    for index: 0..count - 1 {
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0 + cast(u32) index, GL_TEXTURE_2D, pass.textures[index].buffer, 0);
    }

    #if depth {
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
        print_caller_trace();
        assert(false, "Framebuffer error.\n");
    }
}

framebuffer_bind_write :: (pass: FramebufferPass($c, $depth, $dr, $m), mask: ClearMask = .Color | .Depth | .Stencil) {
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, pass.framebuffer);
    glViewport(0, 0, xx pass.width, xx pass.height);

    koda.active_pass_channels = pass.channels;

    #if depth {
        clear(mask & .Depth);
    } else {
        clear(mask & .Color);
    }
}

framebuffer_bind_write_screen :: (mask: ClearMask = .Color | .Depth | .Stencil) {
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
    glViewport(0, 0, xx koda.width, xx koda.height);

    screen_channel :: PixelFormat.[.RGBA8];
    koda.active_pass_channels = screen_channel;

    clear(mask & (.Color | .Depth));
}

framebuffer_bind_read :: (pass: FramebufferPass) {
    glBindFramebuffer(GL_READ_FRAMEBUFFER, pass.framebuffer);
}

framebuffer_bind_read_screen :: () {
    glBindFramebuffer(GL_READ_FRAMEBUFFER, 0);
}

// blit seems to behave weirdly with obs
// framebuffer_resolve_color :: (pass: FramebufferPass($p_c, $p_d, $p_dr, $p_ms), texture_index: int, resolved: FramebufferPass($r_c, $r_d, $r_dr, $r_ms)) {
//     assert(p_c > texture_index, "You cannot resolve a texture index that doesn't exist.");
//     assert(r_c == 1, "You cannot resolve color into a framebuffer with more than 1 texture.");

//     framebuffer_bind_read(pass);
//     framebuffer_bind_write(resolved);

//     interp: u32 = GL_NEAREST;
//     if pass.width != resolved.width || pass.height != resolved.height {
//         interp = GL_LINEAR;
//     }

//     glReadBuffer(GL_COLOR_ATTACHMENT0 + cast(u32) texture_index);
//     glBlitFramebuffer(0, 0, xx pass.width, xx pass.height, 0, 0, xx resolved.width, xx resolved.height, GL_COLOR_BUFFER_BIT, interp);
// }

// framebuffer_resolve_color_screen :: (pass: FramebufferPass(1, $p_d, $p_dr, $p_ms)) {
//     framebuffer_resolve_color_screen(pass, 0);
// }

// framebuffer_resolve_color_screen :: (pass: FramebufferPass($p_c, $p_d, $p_dr, $p_ms), texture_index: int) {
//     assert(p_c > texture_index, "You cannot resolve a texture index that doesn't exist.");

//     framebuffer_bind_read(pass);
//     framebuffer_bind_write_screen();

//     interp: u32 = GL_NEAREST;
//     if pass.width != koda.width || pass.height != koda.height {
//         interp = GL_LINEAR;
//     }

//     glReadBuffer(GL_COLOR_ATTACHMENT0 + cast(u32) texture_index);
//     glBlitFramebuffer(0, 0, xx pass.width, xx pass.height, 0, 0, xx koda.width, xx koda.height, GL_COLOR_BUFFER_BIT, interp);
// }

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
    set_depth_write_scope(false);
    set_depth_test_scope(false);

    glBindVertexArray(pass.vao);
    glDrawArrays(GL_TRIANGLES, 0, 6);
    glBindVertexArray(0);
}