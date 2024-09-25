
Quad :: struct {
    vao: u32;
    vbo: u32;
    ebo: u32;
    position: Vector2;
    width: float;
    height: float;
    anchor: Vector2;
    shader: *Shader;
    uniforms: ShaderUniforms;
}

create_quad :: () -> Quad {
    vertices :: float.[
        // top left
        0.0, 0.0,
        0.0, 0.0,
        // bottom left
        0.0, 1.0,
        0.0, 1.0,
        // bottom right
        1.0, 1.0,
        1.0, 1.0,
        // top right
        1.0, 0.0,
        1.0, 0.0,
    ];
    indices :: u32.[
        0, 1, 2,
        0, 2, 3,
    ];

    quad: Quad;

    glGenVertexArrays(1, *quad.vao);
    glGenBuffers(1, *quad.vbo);
    glGenBuffers(1, *quad.ebo);

    glBindVertexArray(quad.vao);
    defer glBindVertexArray(0);

    glBindBuffer(GL_ARRAY_BUFFER, quad.vbo);
    glBufferData(GL_ARRAY_BUFFER, size_of(type_of(vertices)), vertices.data, GL_STATIC_DRAW);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, quad.ebo);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, size_of(type_of(indices)), indices.data, GL_STATIC_DRAW);

    // position attribute
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * size_of(float), cast(*void) 0);
    glEnableVertexAttribArray(0);

    // texture coord attribute
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * size_of(float), cast(*void) (2 * size_of(float)));
    glEnableVertexAttribArray(1);

    return quad;
}

create_quad :: (width: float, height: float) -> Quad {
    quad := create_quad();
    quad.width = width;
    quad.height = height;
    return quad;
}

destroy :: (quad: Quad) {
    glDeleteBuffers(1, *quad.ebo);
    glDeleteBuffers(1, *quad.vbo);
    glDeleteVertexArrays(1, *quad.vao);

    destroy(quad.uniforms);
}

draw :: (quad: Quad) {
    shader: *Shader = quad.shader;
    assert(!!shader, "You have to provide a shader to draw a quad.\n");
    if !shader {
        return;
    }

    use_shader(shader);

    apply_uniforms(shader, quad.uniforms);

    applied_position := quad.position - Vector2.{quad.width, quad.height} * quad.anchor;

    projection := get_orthographic_matrix();
    model := Matrix4Identity;
    model = translate(model, Vector3.{applied_position.x, applied_position.y, 0});
    model = scale(model, Vector3.{quad.width, quad.height, 1.0});
    view := koda.view;

    uniforms: ShaderUniforms;
    defer destroy(uniforms);
    
    model_view := view * model;
    model_view_projection := projection * model_view;
    set(*uniforms, "modelViewProjection", model_view_projection);
    set(*uniforms, "modelView", model_view);
    set(*uniforms, "projection", projection);
    set(*uniforms, "model", model);
    set(*uniforms, "view", view);

    apply_uniforms(shader, uniforms);

    glBindVertexArray(quad.vao);
    defer glBindVertexArray(0);

    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, null);
}
