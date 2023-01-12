// TODO if I want to optimize this I should use the same 1 by 1 quad and scale/rotate it in the shader
draw_line :: (p1: Vector2, p2: Vector2, width: float = 1.0, color: Color = .{1, 1, 1, 1}) {
    draw_line(p1.x, p1.y, p2.x, p2.y, width, color);
}

draw_line :: (x1: float, y1: float, x2: float, y2: float, width: float = 1.0, color: Color = .{1, 1, 1, 1}) {
    p1 := xy(x1, y1);
    p2 := xy(x2, y2);

    dir := normalize(p2 - p1);
    normal := xy(-dir.y, dir.x);
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

    projection := orthographic_projection_matrix(0.0, xx koda.width, xx koda.height, 0.0, -1.0, 1.0); 
    model := Matrix4_Identity;
    view := koda.view;

    uniforms: ShaderUniforms;
    defer free(uniforms);

    uniforms["uTexture"] = create_uniform("uTexture", cast(u32) 0);

    uniforms["projection"] = create_uniform("projection", projection);
    uniforms["model"] = create_uniform("model", model);
    uniforms["view"] = create_uniform("view", view);

    uniforms["uTint"] = create_uniform("uTint", color);
    uniforms["uFrame"] = create_uniform("uFrame", Vector4.{0, 0, 1, 1});

    apply_uniforms(*default_shader, uniforms);

    glDrawArrays(GL_TRIANGLES, 0, xx (vertices.count / 2));
}

draw_rect :: (top_left: Vector2, dimensions: Vector2, color: Color = .{1, 1, 1, 1}, border: Color = .{1, 1, 1, 0}) {
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
    defer free(uniforms);

    uniforms["uTexture"] = create_uniform("uTexture", cast(u32) 0);
    
    uniforms["projection"] = create_uniform("projection", projection);
    uniforms["model"] = create_uniform("model", model);
    uniforms["view"] = create_uniform("view", view);
    
    uniforms["uTint"] = create_uniform("uTint", color);
    uniforms["uFrame"] = create_uniform("uFrame", Vector4.{0, 0, 1, 1});

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

    projection := orthographic_projection_matrix(0.0, xx koda.width, xx koda.height, 0.0, -1.0, 1.0); 
    model := Matrix4_Identity;
    view := koda.view;

    uniforms: ShaderUniforms;
    defer free(uniforms);

    uniforms["uTexture"] = create_uniform("uTexture", cast(u32) 0);
    
    uniforms["projection"] = create_uniform("projection", projection);
    uniforms["model"] = create_uniform("model", model);
    uniforms["view"] = create_uniform("view", view);
    
    uniforms["uTint"] = create_uniform("uTint", color);
    uniforms["uFrame"] = create_uniform("uFrame", Vector4.{0, 0, 1, 1});

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
    top_left := center - dimensions / 2.0;
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

    // vertices[0].x /= koda.width;
    // vertices[0].y /= koda.height;
    // vertices[0] = vertices[0] * 2.0 - 1.0;
    // vertices[2].x /= koda.width;
    // vertices[2].y /= koda.height;
    // vertices[2] = vertices[2] * 2.0 - 1.0;
    // vertices[4].x /= koda.width;
    // vertices[4].y /= koda.height;
    // vertices[4] = vertices[4] * 2.0 - 1.0;
    // vertices[6].x /= koda.width;
    // vertices[6].y /= koda.height;
    // vertices[6] = vertices[6] * 2.0 - 1.0;
    // vertices[8].x /= koda.width;
    // vertices[8].y /= koda.height;
    // vertices[8] = vertices[8] * 2.0 - 1.0;
    // vertices[10].x /= koda.width;
    // vertices[10].y /= koda.height;
    // vertices[10] = vertices[10] * 2.0 - 1.0;

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

    use_shader(*default_ellipse_shader);

    projection := orthographic_projection_matrix(0.0, xx koda.width, xx koda.height, 0.0, -1.0, 1.0); 
    model := Matrix4_Identity;
    view := koda.view;

    uniforms: ShaderUniforms;
    defer free(uniforms);
    
    uniforms["projection"] = create_uniform("projection", projection);
    uniforms["model"] = create_uniform("model", model);
    uniforms["view"] = create_uniform("view", view);
    
    uniforms["uTint"] = create_uniform("uTint", color);
    uniforms["uFrame"] = create_uniform("uFrame", Vector4.{0, 0, 1, 1});

    apply_uniforms(*default_shader, uniforms);

    glDrawArrays(GL_TRIANGLES, 0, xx (vertices.count / 2));
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

    projection := orthographic_projection_matrix(0.0, xx koda.width, xx koda.height, 0.0, -1.0, 1.0); 
    model := Matrix4_Identity;
    view := koda.view;

    uniforms: ShaderUniforms;
    defer free(uniforms);
    
    uniforms["projection"] = create_uniform("projection", projection);
    uniforms["model"] = create_uniform("model", model);
    uniforms["view"] = create_uniform("view", view);
    
    uniforms["uTint"] = create_uniform("uTint", color);

    // TODO use attributes or whatever instead of looping this shader 1000 times
    index: int;
    while index < positions.count {
        defer index += 1000;

        offsets: [1000] Vector2;
        remaining_count := min(1000, positions.count - index);
        memcpy(offsets.data, positions.data + index, remaining_count * size_of(Vector2));
        uniforms["offsets"] = create_uniform("offsets", offsets);

        // TODO apply 1 only
        apply_uniforms(*default_shader, uniforms);

        glDrawArraysInstanced(GL_TRIANGLES, 0, xx (vertices.count / 2), xx remaining_count);
    }
}
