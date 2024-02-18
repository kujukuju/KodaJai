
Font :: struct {
    characters: [256] Image;
    infos: [256] CharacterInfo;
    textures: [256] Texture;
    max_height: int;
    vao: GLuint;
    vbo: GLuint;
}

CharacterInfo :: struct {
    bearing: Point2;
    advance: int;
}

create_font :: (bytes: [] u8, pixel_height: int, should_upload: bool = true) -> *Font, bool {
    #import "freetype-2.12.1";

    font := New(Font);

    ft_font: FT_Library;
    error := FT_Init_FreeType(*ft_font);
    defer FT_Done_FreeType(ft_font);
    if error {
        print_stack_trace();
        print("FreeType error. %\n", error);
        return null, false;
    }

    ft_face: FT_Face;
    error = FT_New_Memory_Face(ft_font, bytes.data, xx bytes.count, 0, *ft_face);
    defer FT_Done_Face(ft_face);
    if error {
        print_stack_trace();
        print("FreeType error. %\n", error);
        return null, false;
    }

    error = FT_Set_Pixel_Sizes(ft_face, 0, xx pixel_height);
    if error {
        print_stack_trace();
        print("FreeType error. %\n", error);
        return null, false;
    }

    for c: 0..255 {
        // load character glyph 
        error := FT_Load_Char(ft_face, xx c, FT_LOAD_RENDER);
        if error {
            print_stack_trace();
            print("FreeType failed to load glyph. %\n", error);
            continue;
        }

        font.characters[c] = create_image(ft_face.glyph.bitmap.width, ft_face.glyph.bitmap.rows, .Gray);
        // print("image % % %\n", c, font.characters[c].width, font.characters[c].height);
        memcpy(font.characters[c].pixels.data, ft_face.glyph.bitmap.buffer, font.characters[c].pixels.count);

        font.infos[c].bearing = point2(ft_face.glyph.bitmap_left, ft_face.glyph.bitmap_top);
        font.infos[c].advance = ft_face.glyph.advance.x;

        font.max_height = max(font.max_height, font.characters[c].height);
    }

    if should_upload {
        upload(font);
    }

    return font, true;
}

load_font :: (path: string, pixel_height: int, should_upload: bool = true) -> *Font, bool {
    file, success := read_entire_file(path);
    defer free(file);
    if !success {
        return null, false;
    }

    byte_view: [] u8;
    byte_view.data = file.data;
    byte_view.count = file.count;
    
    font, created := create_font(byte_view, pixel_height, should_upload);
    return font, created;
}

load_serialized_font :: (serialized_path: string, hash_files: [$N] string, fallback: () -> *Font, should_upload: bool = true, $reuse_memory: bool = false) -> *Font, bool {
    font: *Font;
    success := read_serialized(serialized_path, hash_files, *font, reuse_memory);

    if success {
        empty: [256] Texture;
        font.textures = empty;
        font.vao = 0;
        font.vbo = 0;

        if should_upload {
            upload(font);
        }

        return font, true;
    }
    
    font = fallback();
    if should_upload {
        upload(font);
    }

    write_serialized(serialized_path, hash_files, font, reuse_memory);
    return font, true;
}

// takes the font images, adds padding and offsets data values
pad_font :: (font: *Font, padding: float) {
    assert(!font.textures[#char "a"].buffer, "You cannot have textures at the time of generating font padding.");
    assert(!!font.characters[#char "a"].pixels.data, "You must have image data at the time of generating font padding.");

    half_padding := cast(int) ceil(padding);
    total_padding := half_padding * 2;

    for i: 0..font.characters.count - 1 {
    // for i: (#char "a")..(#char "a") {
        if !font.characters[i].pixels {
            continue;
        }

        print("Generating %\n", i);

        character := font.characters[i];

        padded := create_image(character.width + total_padding, character.height + total_padding, .Gray);

        for dest_y: 0..padded.height - 1 {
            for dest_x: 0..padded.width - 1 {

                distance_to_pixel := padding + 1.0;
                for offset_y: -half_padding..half_padding {
                    for offset_x: -half_padding..half_padding {
                        source_y := dest_y - half_padding + offset_y;
                        source_x := dest_x - half_padding + offset_x;
                        source_color := get_pixel(character, point2(source_x, source_y));

                        if source_color.r > 0 {
                            distance := sqrt(cast(float) offset_y * offset_y + offset_x * offset_x) + 1.0 - source_color.r;
                            if distance < distance_to_pixel {
                                distance_to_pixel = distance;
                            }
                        }
                    }
                }

                if distance_to_pixel < padding + 1.0 {
                    alpha := clamp(padding + 1.0 - distance_to_pixel, 0, 1);

                    padded.pixels[dest_y * padded.width + dest_x] = cast(u8) round(alpha * 255);
                }
            }
        }

        destroy(font.characters[i]);
        font.characters[i] = padded;
        font.infos[i].bearing += point2(-half_padding, half_padding);
    }
}

upload :: (font: *Font) {
    if font.vao {
        return;
    }

    for i: 0..font.characters.count - 1 {
        if !font.characters[i].pixels {
            continue;
        }
        
        // if !font.textures[i].buffer && font.characters[i].pixels.count > 0 {
            font.textures[i] = create_texture(font.characters[i], interp = .Linear);
        // }
    }

    glGenVertexArrays(1, *font.vao);
    glGenBuffers(1, *font.vbo);
    glBindVertexArray(font.vao);
    glBindBuffer(GL_ARRAY_BUFFER, font.vbo);
    glBufferData(GL_ARRAY_BUFFER, 6 * size_of(Vector4), null, GL_DYNAMIC_DRAW);
    // position attribute
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * size_of(float), cast(*void) 0);
    glEnableVertexAttribArray(0);
    // texture coord attribute
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * size_of(float), cast(*void) (2 * size_of(float)));
    glEnableVertexAttribArray(1);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
}
