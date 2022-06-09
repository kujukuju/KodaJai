Text :: struct {
    text: string;
    position: Vector2;
    color: Vector4 = .{1, 1, 1, 1};
    tint: Color = .{1, 1, 1, 1};
    anchor: Vector2;
    font_: *Dynamic_Font;
}

create_text :: (content: string, path: string, basename: string, pixel_height: int) -> Text {
    text: Text;
    text.text = content;
    text.font_ = load_font(path, basename, pixel_height);

    return text;
}

draw_text :: (text: string, position: Vector2) {
    default_text := get_default_text();
    default_text.text = text;
    default_text.position = position;
    draw_text(default_text);
}

// TODO not this
draw_text :: (text: Text, position: Vector2) {
    new := text;
    new.position = position;

    draw_text(new);
}

draw_text :: (text: Text) {
    if !text.text { 
        return;
    }

    assert(text.position.x >= 0);
    assert(text.position.y >= 0);
    assert(text.font_ != null);

    vertex_array: [..] Vector4;
    defer array_free(vertex_array);

    prep_text(text.font_, 0, 0, xyzw(1.0, 1.0, 1.0, 1.0), text.text);

    height := text.font_.typical_ascender;
    width := text.font_.temporary_glyphs_width_in_pixels;
    // height := 0.0;
    // for text.font_.current_quads {
    //     quad_height := it.y1 - it.y0;
    //     height = max(height, quad_height);
    // }

    for text.font_.current_quads {
        v0 := xyzw((it.x0 - text.anchor.x * width) / koda.width * 2.0 - 1.0, (-it.y0 + (1.0 - text.anchor.y) * height) / koda.height * 2.0 - 1.0, it.u0, it.v0);
        v1 := xyzw((it.x1 - text.anchor.x * width) / koda.width * 2.0 - 1.0, (-it.y0 + (1.0 - text.anchor.y) * height) / koda.height * 2.0 - 1.0, it.u1, it.v0);
        v2 := xyzw((it.x1 - text.anchor.x * width) / koda.width * 2.0 - 1.0, (-it.y1 + (1.0 - text.anchor.y) * height) / koda.height * 2.0 - 1.0, it.u1, it.v1);
        v3 := xyzw((it.x0 - text.anchor.x * width) / koda.width * 2.0 - 1.0, (-it.y1 + (1.0 - text.anchor.y) * height) / koda.height * 2.0 - 1.0, it.u0, it.v1);

        // Add quad vertex
        array_add(*vertex_array, v0);
        array_add(*vertex_array, v1);
        array_add(*vertex_array, v2);

        array_add(*vertex_array, v2);
        array_add(*vertex_array, v3);
        array_add(*vertex_array, v0);

        if it.map && it.map.platform_specific.gl_handle {
            // @Hack Could the quads be using multiple texture maps?
            glBindTexture(GL_TEXTURE_2D, it.map.platform_specific.gl_handle);
        }
    }
    defer glBindTexture(GL_TEXTURE_2D, 0);

    vao: GLuint;
    glGenVertexArrays(1, *vao);
    defer glDeleteVertexArrays(1, *vao);
    glBindVertexArray(vao);
    defer glBindVertexArray(0);

    //
    // Generate VBO memory
    //

    buffer_id: GLuint;
    glGenBuffers(1, *buffer_id);
    defer glDeleteBuffers(1, *buffer_id);

    glBindBuffer(GL_ARRAY_BUFFER, buffer_id);
    glBufferData(GL_ARRAY_BUFFER, size_of(Vector4) * vertex_array.count, vertex_array.data, GL_DYNAMIC_DRAW);

    //
    // Configure attribute pointers
    //

    glEnableVertexAttribArray(0);
    defer glDisableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * size_of(float), cast(*void) 0);

    glEnableVertexAttribArray(1);
    defer glDisableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * size_of(float), cast(*void) (size_of(float) * 2));

    //
    // Configure uniforms
    //

    use_shader(*default_shader);

    projection := orthographic_projection_matrix(0.0, xx koda.width, xx koda.height, 0.0, -1.0, 1.0); 
    model := Matrix4_Identity;
    view := koda.transform;

    set_uniform(*default_shader, "uTexture", 0);

    set_uniform(*default_shader, "projection", projection);
    set_uniform(*default_shader, "model", model);
    set_uniform(*default_shader, "view", view);

    set_uniform(*default_shader, "uPos", text.position);
    set_uniform(*default_shader, "uDim", xy(xx koda.width, xx koda.height));
    set_uniform(*default_shader, "uScreenDim", xy(xx koda.width, xx koda.height));
    set_uniform(*default_shader, "uTint", text.tint);
    set_uniform(*default_shader, "uFrame", xyzw(0, 0, 1, 1));

    apply_shader_uniforms();

    glDrawArrays(GL_TRIANGLES, 0, xx vertex_array.count);
}

#scope_file

#import "Render";