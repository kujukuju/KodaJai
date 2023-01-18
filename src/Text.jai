Character :: struct {
    character: u8;
    texture: GLuint;
    size: Point2;
    bearing: Point2;
    advance: int;
}

Text :: struct {
    text: string;
    position: Vector2;
    color: Vector4 = .{1, 1, 1, 1};
    tint: Color = .{1, 1, 1, 1};
    anchor: Vector2;
    max_height: int;
    characters_: [256] Character;
    vao_: GLuint;
    vbo_: GLuint;
}

create_text :: (content: string, path: string, pixel_height: int) -> Text, bool {
    file, success := read_entire_file(path);
    defer free(file);
    if !success {
        return .{}, false;
    }

    byte_view: [] u8;
    byte_view.data = file.data;
    byte_view.count = file.count;
    
    text, created := create_text(content, byte_view, pixel_height);
    return text, created;
}

create_text :: (content: string, bytes: [] u8, pixel_height: int) -> Text, bool {
    text: Text;
    text.text = content;

    font: FT_Library;
    error := FT_Init_FreeType(*font);
    defer FT_Done_FreeType(font);
    if error {
        print_stack_trace();
        print("FreeType error. %\n", error);
        return .{}, false;
    }

    face: FT_Face;
    error = FT_New_Memory_Face(font, bytes.data, xx bytes.count, 0, *face);
    defer FT_Done_Face(face);
    if error {
        print_stack_trace();
        print("FreeType error. %\n", error);
        return .{}, false;
    }

    error = FT_Set_Pixel_Sizes(face, 0, xx pixel_height);  
    if error {
        print_stack_trace();
        print("FreeType error. %\n", error);
        return .{}, false;
    }

    // TODO do this using Texture?
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    for c: 0..255 {
        // load character glyph 
        error := FT_Load_Char(face, xx c, FT_LOAD_RENDER);
        if error {
            print_stack_trace();
            print("FreeType failed to load glyph. %\n", error);
            continue;
        }
        // generate texture
        texture: GLuint;
        glGenTextures(1, *texture);
        glBindTexture(GL_TEXTURE_2D, texture);
        glTexImage2D(
            GL_TEXTURE_2D,
            0,
            GL_RED,
            face.glyph.bitmap.width,
            face.glyph.bitmap.rows,
            0,
            GL_RED,
            GL_UNSIGNED_BYTE,
            face.glyph.bitmap.buffer,
        );
        // set texture options
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        // now store character for later use
        character: Character;
        character.character = cast(u8) c;
        character.texture = texture;
        character.size = point2(face.glyph.bitmap.width, face.glyph.bitmap.rows);
        character.bearing = point2(face.glyph.bitmap_left, face.glyph.bitmap_top);
        character.advance = face.glyph.advance.x;
        text.characters_[c] = character;

        text.max_height = max(text.max_height, character.size.y);
    }

    glGenVertexArrays(1, *text.vao_);
    glGenBuffers(1, *text.vbo_);
    glBindVertexArray(text.vao_);
    glBindBuffer(GL_ARRAY_BUFFER, text.vbo_);
    glBufferData(GL_ARRAY_BUFFER, 6 * size_of(Vector4), null, GL_DYNAMIC_DRAW);
    // position attribute
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * size_of(float), cast(*void) 0);
    glEnableVertexAttribArray(0);
    // texture coord attribute
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * size_of(float), cast(*void) (2 * size_of(float)));
    glEnableVertexAttribArray(1);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);      

    return text, true;
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

    depth_test := get_depth_test();
    cull_face := get_cull_face();
    transform := koda.view;

    set_depth_test(false);
    defer set_depth_test(depth_test);
    set_cull_face(false);
    defer set_cull_face(cull_face);
    koda.view = Matrix4_Identity;
    defer koda.view = transform;

    scale := 1.0;

    x := text.position.x;
    y := text.position.y;

    glActiveTexture(GL_TEXTURE0);
    glBindVertexArray(text.vao_);

    for index: 0..text.text.count - 1 {
        char: u8 = text.text[index];
        if char < 0 || char >= text.characters_.count {
            print("Character out of bounds. %\n", char);
            continue;
        }

        character := text.characters_[char];

        xpos := x + character.bearing.x * scale;
        ypos := y - character.bearing.y * scale + text.max_height * scale;

        w := character.size.x * scale;
        h := character.size.y * scale;

        zero := 0.0;
        one := 1.0;
        vertices: [6] Vector4;
        vertices[0] = xyzw(xpos, ypos + h, 0, one);
        vertices[1] = xyzw(xpos, ypos, 0, zero);
        vertices[2] = xyzw(xpos + w, ypos, 1, zero);
        vertices[3] = xyzw(xpos, ypos + h, 0, one);
        vertices[4] = xyzw(xpos + w, ypos, 1, zero);
        vertices[5] = xyzw(xpos + w, ypos + h, 1, one);

        // render glyph texture over quad
        glBindTexture(GL_TEXTURE_2D, character.texture);
        // update content of VBO memory
        glBindBuffer(GL_ARRAY_BUFFER, text.vbo_);
        glBufferSubData(GL_ARRAY_BUFFER, 0, size_of(type_of(vertices)), vertices.data); 
        glBindBuffer(GL_ARRAY_BUFFER, 0);

        //
        // Configure uniforms
        //

        // set_cull_face(false);
        // set_front_face_ccw(false);

        use_shader(*default_font_shader);

        projection := orthographic_projection_matrix(0.0, xx koda.width, xx koda.height, 0.0, -1.0, 1.0);
        model := Matrix4_Identity;
        view := koda.view;

        uniforms: ShaderUniforms;
        defer destroy(uniforms);
        
        uniforms["uTexture"] = create_uniform("uTexture", character.texture);

        uniforms["projection"] = create_uniform("projection", projection);

        uniforms["uTint"] = create_uniform("uTint", text.tint);

        apply_uniforms(*default_font_shader, uniforms);

        // render quad
        glDrawArrays(GL_TRIANGLES, 0, xx vertices.count);

        // now advance cursors for next glyph (note that advance is number of 1/64 pixels)
        // bitshift by 6 to get value in pixels (2^6 = 64)
        x += (character.advance >> 6) * scale;
    }

    glBindVertexArray(0);
    glBindTexture(GL_TEXTURE_2D, 0);







    // slot: FT_GlyphSlot = text.face_.glyph;
    // pen_x, pen_y, n: int;

    // pen_x = cast(int) text.position.x;
    // pen_y = cast(int) text.position.y;

    // for i: 0..text.text.count - 1 {
    //     glyph_index: FT_UInt;

    //     glyph_index = FT_Get_Char_Index(text.face_, text.text[i]);

    //     error := FT_Load_Glyph(text.face_, glyph_index, FT_LOAD_DEFAULT);
    //     if error {
    //         print("FreeType load glyph error. %\n", error);
    //         continue;
    //     }

    //     error = FT_Render_Glyph(text.face_.glyph, FT_RENDER_MODE_NORMAL);
    //     if error {
    //         print("FreeType render glyph error. %\n", error);
    //         continue;
    //     }

    //     pen_x += slot.advance.x >> 6;
    //     pen_y += slot.advance.y >> 6;
    // }

    // vertex_array: [..] Vector4;
    // defer array_free(vertex_array);

    // prep_text(text.font_, 0, 0, xyzw(1.0, 1.0, 1.0, 1.0), text.text);

    // height := text.font_.typical_ascender;
    // width := text.font_.temporary_glyphs_width_in_pixels;
    // // height := 0.0;
    // // for text.font_.current_quads {
    // //     quad_height := it.y1 - it.y0;
    // //     height = max(height, quad_height);
    // // }

    // for text.font_.current_quads {
    //     v0 := xyzw((it.x0 - text.anchor.x * width) / koda.width * 2.0 - 1.0, (-it.y0 + (1.0 - text.anchor.y) * height) / koda.height * 2.0 - 1.0, it.u0, it.v0);
    //     v1 := xyzw((it.x1 - text.anchor.x * width) / koda.width * 2.0 - 1.0, (-it.y0 + (1.0 - text.anchor.y) * height) / koda.height * 2.0 - 1.0, it.u1, it.v0);
    //     v2 := xyzw((it.x1 - text.anchor.x * width) / koda.width * 2.0 - 1.0, (-it.y1 + (1.0 - text.anchor.y) * height) / koda.height * 2.0 - 1.0, it.u1, it.v1);
    //     v3 := xyzw((it.x0 - text.anchor.x * width) / koda.width * 2.0 - 1.0, (-it.y1 + (1.0 - text.anchor.y) * height) / koda.height * 2.0 - 1.0, it.u0, it.v1);

    //     // Add quad vertex
    //     array_add(*vertex_array, v0);
    //     array_add(*vertex_array, v1);
    //     array_add(*vertex_array, v2);

    //     array_add(*vertex_array, v2);
    //     array_add(*vertex_array, v3);
    //     array_add(*vertex_array, v0);

    //     if it.map && it.map.platform_specific.gl_handle {
    //         // @Hack Could the quads be using multiple texture maps?
    //         glBindTexture(GL_TEXTURE_2D, it.map.platform_specific.gl_handle);
    //     }
    // }
    // defer glBindTexture(GL_TEXTURE_2D, 0);

    // vao: GLuint;
    // glGenVertexArrays(1, *vao);
    // defer glDeleteVertexArrays(1, *vao);
    // glBindVertexArray(vao);
    // defer glBindVertexArray(0);

    // //
    // // Generate VBO memory
    // //

    // buffer_id: GLuint;
    // glGenBuffers(1, *buffer_id);
    // defer glDeleteBuffers(1, *buffer_id);

    // glBindBuffer(GL_ARRAY_BUFFER, buffer_id);
    // glBufferData(GL_ARRAY_BUFFER, size_of(Vector4) * vertex_array.count, vertex_array.data, GL_DYNAMIC_DRAW);

    // //
    // // Configure attribute pointers
    // //

    // glEnableVertexAttribArray(0);
    // defer glDisableVertexAttribArray(0);
    // glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * size_of(float), cast(*void) 0);

    // glEnableVertexAttribArray(1);
    // defer glDisableVertexAttribArray(1);
    // glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * size_of(float), cast(*void) (size_of(float) * 2));

    // //
    // // Configure uniforms
    // //

    // use_shader(*default_shader);

    // projection := get_orthographic_matrix();
    // model := Matrix4_Identity;
    // view := koda.view;

    // set_uniform(*default_shader, "uTexture", 0);

    // set_uniform(*default_shader, "projection", projection);
    // set_uniform(*default_shader, "model", model);
    // set_uniform(*default_shader, "view", view);

    // set_uniform(*default_shader, "uPos", text.position);
    // set_uniform(*default_shader, "uDim", xy(xx koda.width, xx koda.height));
    // set_uniform(*default_shader, "uScreenDim", xy(xx koda.width, xx koda.height));
    // set_uniform(*default_shader, "uTint", text.tint);
    // set_uniform(*default_shader, "uFrame", xyzw(0, 0, 1, 1));

    // apply_shader_uniforms();

    // glDrawArrays(GL_TRIANGLES, 0, xx vertex_array.count);
}

#scope_file

#import "freetype-2.12.1";