
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

draw_text :: (content: string, position: Vector2, anchor: Vector2 = .{0, 0}, tint: Color = .{1, 1, 1, 1}, scale: float = 1.0, padding: float = 0.0) {
    font := get_default_font();

    draw_text(content, font, position, anchor, tint, scale, padding);
}

draw_text :: (content: string, font: *Font, position: Vector2, anchor: Vector2 = .{0, 0}, tint: Color = .{1, 1, 1, 1}, scale: float = 1.0, padding: float = 0.0, clipped: bool = false) {
    if !content {
        return;
    }

    depth_test := get_depth_test();
    defer set_depth_test(depth_test);
    set_depth_test(false);

    cull_face := get_cull_face();
    defer set_cull_face(cull_face);
    set_cull_face(false);

    view := koda.view;
    defer koda.view = view;
    koda.view = Matrix4Identity;

    aabb := get_aabb(content, font, scale);
    dimensions := aabb.upper - aabb.lower;

    clipped_offset := ifx clipped then aabb.lower else Vector2.{};

    x := position.x - dimensions.x * anchor.x - clipped_offset.x;
    y := position.y - dimensions.y * anchor.y - clipped_offset.y;

    particle_system_clear(*font_system);

    char: u32;
    index: int;
    while index < content.count {
        char, index = get_unicode_char(content, index);
        character, found := table_find(*font.characters, char);
        if !found {
            print("Character out of bounds. %\n", char);
            continue;
        }

        xpos := x + character.bearing.x * scale;
        ypos := y - character.bearing.y * scale + font.max_height * scale;

        w := character.width * scale;
        h := character.height * scale;

        gpu: FontParticleGpu;
        gpu.position = .{xpos, ypos};
        gpu.size = .{w, h};
        gpu.texSize = .{cast(float) character.width / font.max_width, cast(float) character.height / font.max_height};
        gpu.index = cast(float) character.index;

        particle_system_add_particle(*font_system, gpu, .{});

        // now advance cursors for next glyph (note that advance is number of 1/64 pixels)
        // bitshift by 6 to get value in pixels (2^6 = 64)
        x += (character.advance.x >> 6) * scale;
    }

    projection := orthographic_projection_matrix(0.0, xx koda.width, xx koda.height, 0.0, -1.0, 1.0);

    real_padding := padding / scale;
    if real_padding > 16 {
        print("Warning: Your font padding can't be larger than your 16 * your scale.\n");
        real_padding = 16;
    }

    font_system.uniforms[xx "uTexture"] = create_uniform("uTexture", font.texture);
    font_system.uniforms[xx "uTint"] = create_uniform("uTint", tint);
    font_system.uniforms[xx "uPadding"] = create_uniform("uPadding", real_padding);
    font_system.uniforms[xx "uScale"] = create_uniform("uScale", scale);
    
    particle_system_update_and_render(*font_system, 0, projection);
}

get_aabb :: (content: string, font: *Font, position: Vector2 = .{0, 0}, anchor: Vector2 = .{0, 0}, scale: float = 1.0, clipped: bool = false) -> AABB2 {
    aabb := get_aabb(content, font, scale);

    clipped_offset := ifx clipped then aabb.lower else Vector2.{};

    aabb.lower += position;
    aabb.upper += position;

    dimensions := aabb.upper - aabb.lower;
    aabb.lower -= dimensions * anchor + clipped_offset;
    aabb.upper -= dimensions * anchor + clipped_offset;

    return aabb;
}

get_aabb :: (content: string, font: *Font, scale: float = 1.0) -> AABB2 {
    if !content {
        return .{};
    }

    x := 0.0;
    y := 0.0;

    aabb: AABB2;
    set_aabb := false;

    char: u32;
    index: int;
    while index < content.count {
        char, index = get_unicode_char(content, index);
        character, found := table_find(*font.characters, char);
        if !found {
            print("Character out of bounds. %\n", char);
            continue;
        }

        xpos := x + character.bearing.x * scale;
        ypos := y - character.bearing.y * scale + font.max_height * scale;

        w := character.width * scale;
        h := character.height * scale;

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
        x += (character.advance.x >> 6) * scale;
    }

    return aabb;
}

get_unicode_char :: (content: string, index: int) -> character: u32, index: int {
    if content[index] & 0b11111000 == 0b11110000 {
        if index + 3 >= content.count {
            return 0, index + 3;
        }

        char: u32 = (content[index] & 0b00000111) << 18;
        char |= (content[index + 1] & 0b00111111) << 12;
        char |= (content[index + 2] & 0b00111111) << 6;
        char |= content[index + 3] & 0b00111111;
        return char, index + 4;
    } else if content[index] & 0b11110000 == 0b11100000 {
        if index + 2 >= content.count {
            return 0, index + 2;
        }
        
        char: u32 = (content[index] & 0b00001111) << 12;
        char |= (content[index + 1] & 0b00111111) << 6;
        char |= content[index + 2] & 0b00111111;
        return char, index + 3;
    } else if content[index] & 0b11100000 == 0b11000000 {
        if index + 1 >= content.count {
            return 0, index + 1;
        }
        
        char: u32 = (content[index] & 0b00011111) << 6;
        char |= content[index + 1] & 0b00111111;
        return char, index + 2;
    } else if content[index] & 0b11000000 == 0b10000000 {
        // you're in the middle of a unicode string
        return 0, index + 1;
    } else {
        if index >= content.count {
            return 0, index;
        }

        return content[index], index + 1;
    }
}
