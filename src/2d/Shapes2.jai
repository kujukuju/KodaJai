// TODO if I want to optimize this I should use the same 1 by 1 quad and scale/rotate it in the shader
draw_line :: (p1: Vector2, p2: Vector2, width: float = 1.0, color: Color = .{1, 1, 1, 1}) {
    draw_line(p1.x, p1.y, p2.x, p2.y, width, color);
}

draw_line :: (x1: float, y1: float, x2: float, y2: float, width: float = 1.0, color: Color = .{1, 1, 1, 1}) {
    p1 := Vector2.{x1, y1};
    p2 := Vector2.{x2, y2};

    dir := normalize(p2 - p1);
    normal := Vector2.{-dir.y, dir.x};
    hw := width / 2.0;

    left1 := p1 - normal * hw;
    right1 := p1 + normal * hw;
    left2 := p2 - normal * hw;
    right2 := p2 + normal * hw;

    vertices: [12] Vector2;
    vertices[0] = left2;
    vertices[1] = .{0, 0};
    vertices[2] = left1;
    vertices[3] = .{0, 1};
    vertices[4] = right1;
    vertices[5] = .{1, 1};
    vertices[6] = left2;
    vertices[7] = .{0, 0};
    vertices[8] = right1;
    vertices[9] = .{1, 1};
    vertices[10] = right2;
    vertices[11] = .{1, 0};

    white_texture := get_white_texture();
    glBindTexture(GL_TEXTURE_2D, white_texture.buffer);
    defer glBindTexture(GL_TEXTURE_2D, 0);

    vao: GLuint;
    glGenVertexArrays(1, *vao);
    defer glDeleteVertexArrays(1, *vao);
    glBindVertexArray(vao);
    defer glBindVertexArray(0);

    buffer_id: GLuint;
    glGenBuffers(1, *buffer_id);
    defer glDeleteBuffers(1, *buffer_id);

    glBindBuffer(GL_ARRAY_BUFFER, buffer_id);
    glBufferData(GL_ARRAY_BUFFER, size_of(type_of(vertices)), *vertices, GL_DYNAMIC_DRAW);

    glEnableVertexAttribArray(0);
    defer glDisableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * size_of(Vector2), cast(*void) 0);

    glEnableVertexAttribArray(1);
    defer glDisableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 2 * size_of(Vector2), cast(*void) size_of(Vector2));

    use_shader(*default_shader);

    projection := get_orthographic_matrix();
    model := Matrix4Identity;
    view := koda.view;

    uniforms: ShaderUniforms;
    defer destroy(uniforms);

    set(*uniforms, "uTexture", cast(u32) 0);

    set(*uniforms, "projection", projection);
    set(*uniforms, "model", model);
    set(*uniforms, "view", view);

    set(*uniforms, "uTint", color);
    set(*uniforms, "uFrame", Vector4.{0, 0, 1, 1});

    apply_uniforms(*default_shader, uniforms);

    glDrawArrays(GL_TRIANGLES, 0, xx (vertices.count / 2));
}

draw_rect :: (top_left: Vector2, dimensions: Vector2, color: Color = .{1, 1, 1, 1}) {
    static_sprite.texture = get_white_texture();
    static_sprite.position = top_left;
    static_sprite.width = dimensions.x;
    static_sprite.height = dimensions.y;
    static_sprite.anchor = .{0, 0};
    static_sprite.rotation = 0;
    static_sprite.shader = *default_shader;
    static_sprite.tint = color;

    draw(static_sprite);
}

draw_rect :: (top_left: Vector2, dimensions: Vector2, color: Color = .{1, 1, 1, 1}, border: Color) {
    bottom_right := top_left + dimensions;

    vertices: [12] Vector2;
    vertices[0] = top_left;
    vertices[1] = .{0, 0};
    vertices[2] = xy(top_left.x, bottom_right.y);
    vertices[3] = .{0, 1};
    vertices[4] = bottom_right;
    vertices[5] = .{1, 1};
    vertices[6] = top_left;
    vertices[7] = .{0, 0};
    vertices[8] = bottom_right;
    vertices[9] = .{1, 1};
    vertices[10] = xy(bottom_right.x, top_left.y);
    vertices[11] = .{1, 0};

    white_texture := get_white_texture();
    glBindTexture(GL_TEXTURE_2D, white_texture.buffer);
    defer glBindTexture(GL_TEXTURE_2D, 0);

    vao: GLuint;
    glGenVertexArrays(1, *vao);
    defer glDeleteVertexArrays(1, *vao);
    glBindVertexArray(vao);
    defer glBindVertexArray(0);

    buffer_id: GLuint;
    glGenBuffers(1, *buffer_id);
    defer glDeleteBuffers(1, *buffer_id);

    glBindBuffer(GL_ARRAY_BUFFER, buffer_id);
    glBufferData(GL_ARRAY_BUFFER, size_of(type_of(vertices)), *vertices, GL_DYNAMIC_DRAW);

    glEnableVertexAttribArray(0);
    defer glDisableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * size_of(Vector2), cast(*void) 0);

    glEnableVertexAttribArray(1);
    defer glDisableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 2 * size_of(Vector2), cast(*void) size_of(Vector2));

    use_shader(*default_shader);

    projection := orthographic_projection_matrix(0.0, xx koda.width, xx koda.height, 0.0, -1.0, 1.0);
    model := Matrix4_Identity;
    view := koda.view;

    uniforms: ShaderUniforms;
    defer destroy(uniforms);

    set(*uniforms, "uTexture", white_texture);
    
    set(*uniforms, "projection", projection);
    set(*uniforms, "model", model);
    set(*uniforms, "view", view);
    
    set(*uniforms, "uTint", color);
    set(*uniforms, "uFrame", Vector4.{0, 0, 1, 1});

    apply_uniforms(*default_shader, uniforms);

    depth_test := get_depth_test();
    set_depth_test(false);
    defer set_depth_test(depth_test);

    glDrawArrays(GL_TRIANGLES, 0, xx (vertices.count / 2));

    if border.a != 0 {
        draw_line(top_left.x, top_left.y, top_left.x, bottom_right.y, 1.0, border);
        draw_line(top_left.x, bottom_right.y, bottom_right.x, bottom_right.y, 1.0, border);
        draw_line(bottom_right.x, bottom_right.y, bottom_right.x, top_left.y, 1.0, border);
        draw_line(bottom_right.x, top_left.y, top_left.x, top_left.y, 1.0, border);
    }
}

draw_rounded_rect :: (top_left: Vector2, dimensions: Vector2, corner_radius: float, color: Color = .{1, 1, 1, 1}) {
    static_sprite.texture = get_white_texture();
    static_sprite.width = dimensions.x;
    static_sprite.height = dimensions.y;
    static_sprite.position = top_left;
    static_sprite.anchor = .{0, 0};
    static_sprite.rotation = 0;
    static_sprite.shader = *rounded_rect_shader;
    static_sprite.tint = color;

    set(*rounded_rect_shader.uniforms, "uDimensions", dimensions);
    set(*rounded_rect_shader.uniforms, "uRadius", corner_radius);

    draw(static_sprite);
}

// draws a convex polygon
// TODO should also repeatedly use a 1x1 quad
draw_polygon :: (points: [] Vector2, color: Color = .{1, 1, 1, 1}, border: Color = .{1, 1, 1, 0}) {
    assert(points.count >= 3 && "cannot draw a line");

    // TODO why does none of this other than the draw line stuff at the end work
    vertices: [..] Vector2;
    defer array_free(vertices);
    array_resize(*vertices, points.count * 2);

    aabb := create_aabb(points);

    for i: 0..points.count - 1 {
        range := aabb.upper - aabb.lower;
        delta := points[i] - aabb.lower;
        percentage := xy(delta.x / range.x, delta.y / range.y);

        vertices[i * 2] = points[i];
        vertices[i * 2 + 1] = percentage;
    }

    white_texture := get_white_texture();
    glBindTexture(GL_TEXTURE_2D, white_texture.buffer);
    defer glBindTexture(GL_TEXTURE_2D, 0);

    // minor optimization compared to the quad thing, but I should be reusing this vao
    vao: GLuint;
    glGenVertexArrays(1, *vao);
    defer glDeleteVertexArrays(1, *vao);
    glBindVertexArray(vao);
    defer glBindVertexArray(0);

    buffer_id: GLuint;
    glGenBuffers(1, *buffer_id);
    defer glDeleteBuffers(1, *buffer_id);

    glBindBuffer(GL_ARRAY_BUFFER, buffer_id);
    glBufferData(GL_ARRAY_BUFFER, vertices.count * size_of(Vector2), vertices.data, GL_DYNAMIC_DRAW);

    glEnableVertexAttribArray(0);
    defer glDisableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * size_of(Vector2), cast(*void) 0);

    glEnableVertexAttribArray(1);
    defer glDisableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 2 * size_of(Vector2), cast(*void) size_of(Vector2));

    use_shader(*default_shader);

    projection := get_orthographic_matrix();
    model := Matrix4_Identity;
    view := koda.view;

    uniforms: ShaderUniforms;
    defer destroy(uniforms);

    set(*uniforms, "uTexture", cast(u32) 0);
    
    set(*uniforms, "projection", projection);
    set(*uniforms, "model", model);
    set(*uniforms, "view", view);
    
    set(*uniforms, "uTint", color);
    set(*uniforms, "uFrame", Vector4.{0, 0, 1, 1});

    apply_uniforms(*default_shader, uniforms);

    glDrawArrays(GL_TRIANGLE_FAN, 0, xx (vertices.count / 2));

    if border.a != 0 {
        for start: 0..points.count - 1 {
            end := (start + 1) % points.count;

            draw_line(points[start].x, points[start].y, points[end].x, points[end].y, 1.0, border);
        }
    }
}

draw_concave_polygon :: (polygon: [] Vector2, color: Color = .{1, 1, 1, 1}, border: Color = .{1, 1, 1, 0}) {
    if polygon.count >= 3 {
        if is_convex(polygon) {
            draw_polygon(polygon, color, border);
        } else {
            convex_polygons := decompose(polygon);
            defer array_free(convex_polygons);

            for convex_part: convex_polygons {
                defer array_free(convex_part);
                draw_polygon(convex_part, color, border);
            }
        }
    } else if polygon.count == 2 && border.a != 0 {
        draw_line(polygon[0].x, polygon[0].y, polygon[1].x,polygon[1].y, 1.0, border);
    }
}

draw_ellipse :: (center: Vector2, width: float, height: float, color: Color = .{1, 1, 1, 1}, border: Color = .{1, 1, 1, 0}) {
    draw_ellipse(center, xy(width, height), color, border);
}

draw_ellipse :: (center: Vector2, dimensions: Vector2, color: Color = .{1, 1, 1, 1}, border: Color = .{1, 1, 1, 0}) {
    static_sprite.texture = get_white_texture();
    static_sprite.width = dimensions.x;
    static_sprite.height = dimensions.y;
    static_sprite.position = center;
    static_sprite.anchor = .{0.5, 0.5};
    static_sprite.rotation = 0;
    static_sprite.shader = *default_ellipse_shader;
    static_sprite.tint = color;

    use_shader(*default_ellipse_shader);

    projection := get_orthographic_matrix();
    model := Matrix4Identity;
    view := koda.view;

    uniforms: ShaderUniforms;
    defer destroy(uniforms);
    
    set(*uniforms, "uTint", color);
    set(*uniforms, "uBorderTint", border);
    set(*uniforms, "uFrame", Vector4.{0, 0, 1, 1});

    apply_uniforms(*default_ellipse_shader, uniforms);

    draw(static_sprite);
}

draw_circles :: (positions: [] Vector2, radius: float, color: Color = .{1, 1, 1, 1}) {
    top_left := Vector2.{-radius, -radius};
    bottom_right := Vector2.{radius, radius};

    vertices: [12] Vector2;
    vertices[0] = top_left;
    vertices[1] = .{0, 0};
    vertices[2] = .{top_left.x, bottom_right.y};
    vertices[3] = .{0, 1};
    vertices[4] = bottom_right;
    vertices[5] = .{1, 1};
    vertices[6] = top_left;
    vertices[7] = .{0, 0};
    vertices[8] = bottom_right;
    vertices[9] = .{1, 1};
    vertices[10] = .{bottom_right.x, top_left.y};
    vertices[11] = .{1, 0};

    vao: GLuint;
    glGenVertexArrays(1, *vao);
    defer glDeleteVertexArrays(1, *vao);
    glBindVertexArray(vao);
    defer glBindVertexArray(0);

    buffer_id: GLuint;
    glGenBuffers(1, *buffer_id);
    defer glDeleteBuffers(1, *buffer_id);

    glBindBuffer(GL_ARRAY_BUFFER, buffer_id);
    glBufferData(GL_ARRAY_BUFFER, size_of(type_of(vertices)), *vertices, GL_DYNAMIC_DRAW);

    glEnableVertexAttribArray(0);
    defer glDisableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * size_of(Vector2), cast(*void) 0);

    glEnableVertexAttribArray(1);
    defer glDisableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 2 * size_of(Vector2), cast(*void) size_of(Vector2));

    use_shader(*instanced_shader2);

    projection := get_orthographic_matrix();
    model := Matrix4_Identity;
    view := koda.view;

    uniforms: ShaderUniforms;
    defer destroy(uniforms);
    
    set(*uniforms, "projection", projection);
    set(*uniforms, "model", model);
    set(*uniforms, "view", view);
    
    set(*uniforms, "uTint", color);

    // TODO use attributes or whatever instead of looping this shader 1000 times
    index: int;
    while index < positions.count {
        defer index += 1000;

        offsets: [1000] Vector2;
        remaining_count := min(1000, positions.count - index);
        memcpy(offsets.data, positions.data + index, remaining_count * size_of(Vector2));
        set(*uniforms, "offsets", offsets);

        // TODO apply 1 only
        apply_uniforms(*default_shader, uniforms);

        glDrawArraysInstanced(GL_TRIANGLES, 0, xx (vertices.count / 2), xx remaining_count);
    }
}
