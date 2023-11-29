
Font :: struct {
    characters: [256] Image;
    infos: [256] CharacterInfo;
    textures: [256] Texture;
    max_height: int;
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

load_font :: (path: string, pixel_height: int) -> *Font, bool {
    file, success := read_entire_file(path);
    defer free(file);
    if !success {
        return .{}, false;
    }

    byte_view: [] u8;
    byte_view.data = file.data;
    byte_view.count = file.count;
    
    font, created := create_font(byte_view, pixel_height);
    return font, created;
}

load_serialized_font :: (serialized_path: string, hash_files: [$N] string, fallback: () -> *Font, should_upload: bool = true, $reuse_memory: bool = false) -> *Font, bool {
    font: *Font;
    success := read_serialized(serialized_path, hash_files, *font, reuse_memory);

    if success {
        font.textures = .[];

        if should_upload {
            upload(font);
        }

        return font;
    }
    
    font = fallback();
    if should_upload {
        upload(font);
    }

    write_serialized(serialized_path, hash_files, font, reuse_memory);
    return font, true;
}

upload :: (font: *Font) {
    for i: 0..font.characters.count - 1 {
        if !font.textures[i].buffer && font.characters[i].pixels.count > 0 {
            font.textures[i] = create_texture(font.characters[i]);
        }
    }
}
