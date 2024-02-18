
frame_buffer: GLuint;
deferred_textures: [4] GLuint;
depth_texture: GLuint;

DeferredType :: enum {
    Position;
    Diffuse;
    Normal;
    Texcoord;
}

texture_types :: DeferredType.[.Position, .Diffuse, .Normal, .Texcoord];
draw_buffers :: GLenum.[GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1, GL_COLOR_ATTACHMENT2, GL_COLOR_ATTACHMENT3];

#run assert(cast(int) DeferredType.Texcoord == 3, "This needs to count or I can't lookup by casting.");

deferred_initialize :: () {
    glGenFramebuffers(1, *frame_buffer);
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, frame_buffer);
    glViewport(0, 0, cast(u32) koda.width, cast(u32) koda.height);

    glGenTextures(texture_types.count, deferred_textures.data);
    glGenTextures(1, *depth_texture);

    for i: 0..texture_types.count - 1 {
       glBindTexture(GL_TEXTURE_2D, deferred_textures[i]);
       glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB32F, cast(u32) koda.width, cast(u32) koda.height, 0, GL_RGB, GL_FLOAT, null);
       glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0 + cast(u32) i, GL_TEXTURE_2D, deferred_textures[i], 0);
    }

    glBindTexture(GL_TEXTURE_2D, depth_texture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT32F, cast(u32) koda.width, cast(u32) koda.height, 0, GL_DEPTH_COMPONENT, GL_FLOAT, null);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, depth_texture, 0);

    glDrawBuffers(draw_buffers.count, draw_buffers.data);

    status := glCheckFramebufferStatus(GL_FRAMEBUFFER);

    if status != GL_FRAMEBUFFER_COMPLETE {
        print("Framebuffer error: %\n", status);
        return;
    }

    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
}

deferred_render_geometry :: () {
    // bind for writing
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, frame_buffer);
    glViewport(0, 0, cast(u32) koda.width, cast(u32) koda.height);

    blend := get_blend();
    defer set_blend(blend);
    set_blend(false);

    // clear the framebuffer
    clear(.{0, 0, 0, 1});

    for model: models {
        draw(model);
    }
}

deferred_render_lighting :: () {
    // restore the screen fbo
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glViewport(0, 0, cast(u32) koda.width, cast(u32) koda.height);

    // clear the screen
    clear(.{0, 0, 0, 1});

    // bind for reading
    glBindFramebuffer(GL_READ_FRAMEBUFFER, frame_buffer);
    glViewport(0, 0, cast(u32) koda.width, cast(u32) koda.height);

    width := cast(s32) koda.width;
    height := cast(s32) koda.height;
    half_width := width / 2;
    half_height := height / 2;

    // set the frame buffer read buffer for the blit copy operation
    glReadBuffer(GL_COLOR_ATTACHMENT0 + 0);
    glBlitFramebuffer(0, 0, width, height, 0, 0, half_width, half_height, GL_COLOR_BUFFER_BIT, GL_LINEAR);

    glReadBuffer(GL_COLOR_ATTACHMENT0 + 1);
    glBlitFramebuffer(0, 0, width, height, 0, half_height, half_width, height, GL_COLOR_BUFFER_BIT, GL_LINEAR);

    glReadBuffer(GL_COLOR_ATTACHMENT0 + 2);
    glBlitFramebuffer(0, 0, width, height, half_width, half_height, width, height, GL_COLOR_BUFFER_BIT, GL_LINEAR);

    glReadBuffer(GL_COLOR_ATTACHMENT0 + 3);
    glBlitFramebuffer(0, 0, width, height, half_width, 0, width, half_height, GL_COLOR_BUFFER_BIT, GL_LINEAR);

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}
