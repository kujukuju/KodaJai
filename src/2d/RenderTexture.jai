RenderTexture :: struct {
    using #as texture: Texture;
    framebuffer: u32;
    depth: Texture;
}

create_render_texture :: (width: int, height: int, format: PixelFormat) -> *RenderTexture {
    rt := New(RenderTexture);
    rt.texture.width = xx width;
    rt.texture.height = xx height;
    rt.texture.format = format;
    rt.depth.width = xx width;
    rt.depth.height = xx height;
    rt.depth.format = .Depth32F;

    gl_format := get_gl_format(format);

    glGenFramebuffers(1, *rt.framebuffer);
    glGenTextures(1, *rt.texture.buffer);
    // I could also `glGenRenderBuffers` for the depth buffer but idk what the difference is
    glGenTextures(1, *rt.depth.buffer);

    glBindFramebuffer(GL_FRAMEBUFFER, rt.framebuffer);

    glBindTexture(GL_TEXTURE_2D, rt.texture.buffer);
    glTexImage2D(GL_TEXTURE_2D, 0, xx gl_format, xx width, xx height, 0, gl_format, GL_UNSIGNED_BYTE, null);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, rt.texture.buffer, 0); 

    glBindTexture(GL_TEXTURE_2D, rt.depth.buffer);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT32F, xx width, xx height, 0, GL_DEPTH_COMPONENT, GL_FLOAT, null);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, rt.depth.buffer, 0);

    glClear(GL_DEPTH_BUFFER_BIT);

    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);

    return rt;
}

destroy :: (render_texture: *RenderTexture) {
    glDeleteFramebuffers(1, *render_texture.framebuffer);
    glDeleteTextures(1, *render_texture.texture.buffer);
    glDeleteTextures(1, *render_texture.depth.buffer);
    free(render_texture);
}

get_texture_and_free :: (render_texture: *RenderTexture) -> Texture {
    texture := render_texture.texture;
    glDeleteFramebuffers(1, *render_texture.framebuffer);
    glDeleteTextures(1, *render_texture.depth.buffer);
    free(render_texture);

    return texture;
}
