
// TODO wow this is bad, it's a texture per character lol

// Character :: struct {
//     character: u8;
//     texture: GLuint;
//     size: Point2;
//     bearing: Point2;
//     advance: int;
// }

// Text :: struct {
//     text: string;
//     position: Vector2;
//     color: Vector4 = .{1, 1, 1, 1};
//     tint: Color = .{1, 1, 1, 1};
//     anchor: Vector2;
//     max_height: int;
//     characters_: [256] Character;
//     images: [] Image;
//     vao_: GLuint;
//     vbo_: GLuint;
// }

// create_text :: (content: string, path: string, pixel_height: int) -> Text, bool {
//     file, success := read_entire_file(path);
//     defer free(file);
//     if !success {
//         return .{}, false;
//     }

//     byte_view: [] u8;
//     byte_view.data = file.data;
//     byte_view.count = file.count;
    
//     text, created := create_text(content, byte_view, pixel_height);
//     return text, created;
// }

// create_text :: (content: string, bytes: [] u8, pixel_height: int) -> Text, bool {
//     #if WASM {
//         assert(false, "You cannot create text in WASM mode.");
//         return .{}, false;
//     }

//     #import "freetype-2.12.1";

//     text: Text;
//     text.text = content;

//     font: FT_Library;
//     error := FT_Init_FreeType(*font);
//     defer FT_Done_FreeType(font);
//     if error {
//         print_stack_trace();
//         print("FreeType error. %\n", error);
//         return .{}, false;
//     }

//     face: FT_Face;
//     error = FT_New_Memory_Face(font, bytes.data, xx bytes.count, 0, *face);
//     defer FT_Done_Face(face);
//     if error {
//         print_stack_trace();
//         print("FreeType error. %\n", error);
//         return .{}, false;
//     }

//     error = FT_Set_Pixel_Sizes(face, 0, xx pixel_height);
//     if error {
//         print_stack_trace();
//         print("FreeType error. %\n", error);
//         return .{}, false;
//     }

//     // TODO do this using Texture?
//     glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
//     for c: 0..255 {
//         // load character glyph 
//         error := FT_Load_Char(face, xx c, FT_LOAD_RENDER);
//         if error {
//             print_stack_trace();
//             print("FreeType failed to load glyph. %\n", error);
//             continue;
//         }
//         // generate texture
//         texture: GLuint;
//         glGenTextures(1, *texture);
//         glBindTexture(GL_TEXTURE_2D, texture);
//         glTexImage2D(
//             GL_TEXTURE_2D,
//             0,
//             GL_RED,
//             face.glyph.bitmap.width,
//             face.glyph.bitmap.rows,
//             0,
//             GL_RED,
//             GL_UNSIGNED_BYTE,
//             face.glyph.bitmap.buffer,
//         );
//         // set texture options
//         glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
//         glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
//         glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
//         glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
//         // now store character for later use
//         character: Character;
//         character.character = cast(u8) c;
//         character.texture = texture;
//         character.size = point2(face.glyph.bitmap.width, face.glyph.bitmap.rows);
//         character.bearing = point2(face.glyph.bitmap_left, face.glyph.bitmap_top);
//         character.advance = face.glyph.advance.x;
//         text.characters_[c] = character;

//         text.max_height = max(text.max_height, character.size.y);
//     }

//     glGenVertexArrays(1, *text.vao_);
//     glGenBuffers(1, *text.vbo_);
//     glBindVertexArray(text.vao_);
//     glBindBuffer(GL_ARRAY_BUFFER, text.vbo_);
//     glBufferData(GL_ARRAY_BUFFER, 6 * size_of(Vector4), null, GL_DYNAMIC_DRAW);
//     // position attribute
//     glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * size_of(float), cast(*void) 0);
//     glEnableVertexAttribArray(0);
//     // texture coord attribute
//     glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * size_of(float), cast(*void) (2 * size_of(float)));
//     glEnableVertexAttribArray(1);
//     glBindBuffer(GL_ARRAY_BUFFER, 0);
//     glBindVertexArray(0);

//     return text, true;
// }

draw_text :: (content: string, position: Vector2, anchor: Vector2 = .{0, 0}, tint: Color = .{1, 1, 1, 1}, scale: float = 1.0) {
    font := get_default_font();

    draw_text(content, font, position, anchor, tint, scale);
}

draw_text :: (content: string, font: Font, position: Vector2, anchor: Vector2 = .{0, 0}, tint: Color = .{1, 1, 1, 1}, scale: float = 1.0, clipped: bool = false) {
    if !content {
        return;
    }

    depth_test := get_depth_test();
    cull_face := get_cull_face();
    transform := koda.view;

    set_depth_test(false);
    defer set_depth_test(depth_test);
    set_cull_face(false);
    defer set_cull_face(cull_face);
    koda.view = Matrix4_Identity;
    defer koda.view = transform;

    aabb := get_aabb(content, font, scale);
    dimensions := aabb.upper - aabb.lower;

    clipped_offset := ifx clipped then aabb.lower else Vector2.{};

    x := position.x - dimensions.x * anchor.x - clipped_offset.x;
    y := position.y - dimensions.y * anchor.y - clipped_offset.y;

    glActiveTexture(GL_TEXTURE0);
    glBindVertexArray(font.vao);

    for index: 0..content.count - 1 {
        char: u8 = content[index];
        if char < 0 || char >= font.characters.count {
            print("Character out of bounds. %\n", char);
            continue;
        }

        character := font.characters[char];
        info := font.infos[char];
        texture := font.textures[char];

        xpos := x + info.bearing.x * scale;
        ypos := y - info.bearing.y * scale + font.max_height * scale;

        w := texture.width * scale;
        h := texture.height * scale;

        zero := 0.0;
        one := 1.0;
        vertices: [6] Vector4;
        vertices[0] = xyzw(xpos, ypos + h, 0, one);
        vertices[1] = xyzw(xpos, ypos, 0, zero);
        vertices[2] = xyzw(xpos + w, ypos, 1, zero);
        vertices[3] = xyzw(xpos, ypos + h, 0, one);
        vertices[4] = xyzw(xpos + w, ypos, 1, zero);
        vertices[5] = xyzw(xpos + w, ypos + h, 1, one);

        // print("drawing % at % %, % %, % %\n", index, xpos, ypos, w, h, font.characters[index].width, font.characters[index].height);

        // draw(texture, xy(xpos, ypos), xy(w, h));

        // render glyph texture over quad
        glBindTexture(GL_TEXTURE_2D, texture.buffer);
        // update content of VBO memory
        glBindBuffer(GL_ARRAY_BUFFER, font.vbo);
        glBufferSubData(GL_ARRAY_BUFFER, 0, size_of(type_of(vertices)), vertices.data);
        glBindBuffer(GL_ARRAY_BUFFER, 0);

        // //
        // // Configure uniforms
        // //

        // // set_cull_face(false);
        // // set_front_face_ccw(false);

        use_shader(*default_font_shader);

        projection := orthographic_projection_matrix(0.0, xx koda.width, xx koda.height, 0.0, -1.0, 1.0);
        model := Matrix4_Identity;
        view := koda.view;

        uniforms: ShaderUniforms;
        defer destroy(uniforms);
        
        uniforms[xx "uTexture"] = create_uniform("uTexture", texture);
        uniforms[xx "projection"] = create_uniform("projection", projection);
        uniforms[xx "uTint"] = create_uniform("uTint", tint);

        apply_uniforms(*default_font_shader, uniforms);

        // render quad
        glDrawArrays(GL_TRIANGLES, 0, xx vertices.count);

        // now advance cursors for next glyph (note that advance is number of 1/64 pixels)
        // bitshift by 6 to get value in pixels (2^6 = 64)
        x += (info.advance >> 6) * scale;
    }

    glBindVertexArray(0);
    glBindTexture(GL_TEXTURE_2D, 0);
}

get_aabb :: (content: string, font: Font, position: Vector2 = .{0, 0}, anchor: Vector2 = .{0, 0}, scale: float = 1.0, clipped: bool = false) -> AABB2 {
    aabb := get_aabb(content, font, scale);

    clipped_offset := ifx clipped then aabb.lower else Vector2.{};

    aabb.lower += position;
    aabb.upper += position;

    dimensions := aabb.upper - aabb.lower;
    aabb.lower -= dimensions * anchor + clipped_offset;
    aabb.upper -= dimensions * anchor + clipped_offset;

    return aabb;
}

get_aabb :: (content: string, font: Font, scale: float = 1.0) -> AABB2 {
    if !content {
        return .{};
    }

    x := 0.0;
    y := 0.0;

    aabb: AABB2;
    set_aabb := false;

    for index: 0..content.count - 1 {
        char: u8 = content[index];
        if char < 0 || char >= font.characters.count {
            print("Character out of bounds. %\n", char);
            continue;
        }

        character := font.characters[char];
        info := font.infos[char];
        texture := font.textures[char];

        xpos := x + info.bearing.x * scale;
        ypos := y - info.bearing.y * scale + font.max_height * scale;

        w := texture.width * scale;
        h := texture.height * scale;

        if !set_aabb {
            set_aabb = true;

            aabb.lower = Vector2.{xpos, ypos};
            aabb.upper = Vector2.{xpos + w, ypos + h};
        } else {
            aabb.lower = min(Vector2.{xpos, ypos}, aabb.lower);
            aabb.upper = max(Vector2.{xpos + w, ypos + h}, aabb.upper);
        }

        // now advance cursors for next glyph (note that advance is number of 1/64 pixels)
        // bitshift by 6 to get value in pixels (2^6 = 64)
        x += (info.advance >> 6) * scale;
    }

    return aabb;
}

#scope_file