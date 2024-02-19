
frame_buffer: GLuint;
deferred_textures: [4] Texture;
depth_texture: Texture;

vbo: GLuint;
vao: GLuint;

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

    // glGenTextures(texture_types.count, deferred_textures.data);
    // glGenTextures(1, *depth_texture);

    for i: 0..texture_types.count - 1 {
        deferred_textures[i] = create_texture(koda.width, koda.height, .RGB32F, .Clamp, .Linear);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0 + cast(u32) i, GL_TEXTURE_2D, deferred_textures[i].buffer, 0);
    }

    depth_texture = create_texture(koda.width, koda.height, .Depth32F, .Clamp, .Linear);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, depth_texture.buffer, 0);

    glDrawBuffers(draw_buffers.count, draw_buffers.data);

    status := glCheckFramebufferStatus(GL_FRAMEBUFFER);

    if status != GL_FRAMEBUFFER_COMPLETE {
        print("Framebuffer error: %\n", status);
        return;
    }

    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);

    light_sphere_geometry := create_icosphere(1, 1);
    light_sphere = create_model(light_sphere_geometry);
    light_sphere.shader = *point_light_shader;
    assert(light_sphere_geometry.attributes.count == 1);

    vertices :: Vector2.[
        .{-1.0, 1.0}, .{-1.0, -1.0}, .{1.0, 1.0},
        .{-1.0, -1.0}, .{1.0, -1.0}, .{1.0, 1.0},
    ];

    glGenBuffers(1, *vbo);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, size_of(type_of(vertices)), vertices.data, GL_STATIC_DRAW);

    glGenVertexArrays(1, *vao);
    glBindVertexArray(vao);

    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * size_of(float), null);
    glEnableVertexAttribArray(0);

    glBindVertexArray(0);
}

deferred_render_geometry :: () {
    // bind for writing
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, frame_buffer);

    depth_write := get_depth_write();
    defer set_depth_write(depth_write);
    set_depth_write(true);

    depth_test := get_depth_test();
    defer set_depth_test(depth_test);
    set_depth_test(true);

    blend := get_blend();
    defer set_blend(blend);
    set_blend(false);

    // clear the framebuffer
    clear(.Color | .Depth);

    for model: models {
        draw(model);
    }
}

deferred_render_lighting :: () {
    // restore the screen fbo
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    blend := get_blend();
    defer set_blend(blend);
    set_blend(true);

    blend_equation := get_blend_equation();
    defer set_blend_equation(blend_equation);
    set_blend_equation(.Add);

    blend_src, blend_dst := get_blend_func();
    defer set_blend_func(blend_src, blend_dst);
    set_blend_func(.One, .One);

    depth_write := get_depth_write();
    defer set_depth_write(depth_write);
    set_depth_write(false);

    depth_test := get_depth_test();
    defer set_depth_test(depth_test);
    set_depth_test(false);

    // clear the screen
    clear(.Color);

    // bind for reading
    glBindFramebuffer(GL_READ_FRAMEBUFFER, frame_buffer);

    directional_light_shader.uniforms[xx "uPosition"] = create_uniform("uPosition", deferred_textures[0]);
    directional_light_shader.uniforms[xx "uDiffuse"] = create_uniform("uDiffuse", deferred_textures[1]);
    directional_light_shader.uniforms[xx "uNormal"] = create_uniform("uNormal", deferred_textures[2]);

    // draw quad
    use_shader(*directional_light_shader);

    uniforms: ShaderUniforms;
    defer destroy(uniforms);
    
    uniforms[xx "view"] = create_uniform("view", koda.view);
    
    apply_uniforms(*directional_light_shader, uniforms);

    glBindVertexArray(vao);
    glDrawArrays(GL_TRIANGLES, 0, 6);
    glBindVertexArray(0);

    // draw point light
    point_light_shader.uniforms[xx "uPosition"] = create_uniform("uPosition", deferred_textures[0]);
    point_light_shader.uniforms[xx "uDiffuse"] = create_uniform("uDiffuse", deferred_textures[1]);
    point_light_shader.uniforms[xx "uNormal"] = create_uniform("uNormal", deferred_textures[2]);

    light_position :: Vector3.{2, 2, -2};
    light_radius :: 4.0;

    light_sphere.position = light_position;
    light_sphere.scale = Vector3.{light_radius, light_radius, light_radius};

    cull_face_mode := get_cull_face_mode();
    defer set_cull_face_mode(cull_face_mode);
    set_cull_face_mode(.Front);

    draw(light_sphere);
}

light_sphere: Model;
