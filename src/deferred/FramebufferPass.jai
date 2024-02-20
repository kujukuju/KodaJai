
FramebufferPass :: struct (count: int, depth: bool, drawable: bool) {
    framebuffer: u32;
    // the output textures
    textures: [count] Texture;
    depth_texture: Texture;
    shader: *Shader;
    uniforms: ShaderUniforms;
    vao: u32;
    vbo: u32;
    initializer: #type (pass: *FramebufferPass(count, depth, drawable));
}

create_framebuffer_pass :: (shader: *Shader, $channels: ..PixelFormat, $depth: bool, $drawable: bool) -> FramebufferPass(channels.count, depth, drawable) {
    pass: FramebufferPass(channels.count, depth, drawable);
    init_framebuffer_pass(*pass, shader);

    return pass;
}

init_framebuffer_pass :: (pass: *FramebufferPass($count, $depth, true), shader: *Shader, channels: ..PixelFormat) {
    assert(!!shader, "If your framebuffer pass is drawable you must provide a shader.\n");
    init_framebuffer_pass_internal(pass, shader, ..channels);
}

init_framebuffer_pass :: (pass: *FramebufferPass($count, $depth, false), channels: ..PixelFormat) {
    init_framebuffer_pass_internal(pass, null, ..channels);
}

init_framebuffer_pass_internal :: (pass: *FramebufferPass($count, $depth, $drawable), shader: *Shader, channels: ..PixelFormat) {
    if count != channels.count {
        assert(false, "Passed invalid number of channels to a framebuffer pass.\n");
        return;
    }

    pass.shader = shader;
    
    #if count > 0 || depth {
        glGenFramebuffers(1, *pass.framebuffer);
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, pass.framebuffer);

        for channel, index: channels {
            pass.textures[index] = create_texture(koda.width, koda.height, channel, .Clamp, .Linear);
            glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0 + cast(u32) index, GL_TEXTURE_2D, pass.textures[index].buffer, 0);
        }

        #if depth {
            pass.depth_texture = create_texture(koda.width, koda.height, .Depth32F, .Clamp, .Linear);
            glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, pass.depth_texture.buffer, 0);
        }

        draw_buffers: [count] u32;
        for i: 0..draw_buffers.count - 1 {
            draw_buffers[i] = GL_COLOR_ATTACHMENT0 + cast(u32) i;
        }

        glDrawBuffers(draw_buffers.count, draw_buffers.data);

        status := glCheckFramebufferStatus(GL_FRAMEBUFFER);

        if status != GL_FRAMEBUFFER_COMPLETE {
            print("Framebuffer error: %\n", status);
            print_stack_trace();
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

framebuffer_bind_write :: (pass: FramebufferPass) {
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, pass.framebuffer);

    clear(.Color | .Depth);
}

framebuffer_bind_write_screen :: () {
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);

    clear(.Color);
}

framebuffer_bind_read :: (pass: FramebufferPass) {
    glBindFramebuffer(GL_READ_FRAMEBUFFER, pass.framebuffer);
}

framebuffer_bind_read_screen :: () {
    glBindFramebuffer(GL_READ_FRAMEBUFFER, 0);
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