
loaded_char_count :: 256;

Font :: struct {
    characters: Table(u32, CharacterInfo);
    texture: TextureArray;
    max_width: int;
    max_height: int;
    buffer_required: bool;
    buffer_view: Matrix4;
    font_system: *InstancedModel(FontParticleGpu); @serializer_skip
    font_instances: [..] FontParticleGpu; @serializer_skip
    glyph_data: [..] u8;
    // dictionary: [] u8;
    // compressed_glyph_data: [] u8;
    loaded_characters: [loaded_char_count] RecentCharacter;
    frame: u32;
}

FontParticleGpu :: struct {
    position: Vector2;
    size: Vector2;
    texSize: Vector2;
    index: float;
    transform1: Vector3;
    transform2: Vector3;
    transform3: Vector3;
    tint: Vector4;
    padding: float;
    scale: Vector2;
    blur: float;
    rotation: float;
    world_position: Vector3;

#place transform1;
    transform: Matrix3 = ---;
}

RecentCharacter :: struct {
    character: u32;
    frame: u32;
}

CharacterInfo :: struct {
    data_index: int;
    width: int;
    height: int;
    bearing: Point2;
    advance: Point2;
}

begin_buffer_text :: (font: *Font) {
    assert(!font.buffer_required, "You cannot call begin buffer text twice in a row.\n");
    font.buffer_required = true;
    font.buffer_view = koda.view;

    font.frame += 1;
}

flush_text :: (font: *Font) {
    projection := orthographic_projection_matrix(0, xx koda.width, xx koda.height, 0, -1.0, 1.0);
    flush_text(font, projection);
}

flush_text :: (font: *Font, projection: Matrix4) {
    font.buffer_required = false;

    set_depth_test_scope(false);
    set_cull_face_scope(false);

    set_instances(font.font_system, font.font_instances);
    font.font_instances.count = 0;

    draw(font.font_system, projection);
}

get_character_bounds :: (bytes: [] u8, pixel_height: int, character_set: [] u32) -> int, int {
    #import "freetype-2.12.1";

    ft_font: FT_Library;
    error := FT_Init_FreeType(*ft_font);
    defer FT_Done_FreeType(ft_font);
    assert(!error, "FreeType error. %\n", error);
    if error {
        return 0, 0;
    }

    ft_face: FT_Face;
    error = FT_New_Memory_Face(ft_font, bytes.data, xx bytes.count, 0, *ft_face);
    defer FT_Done_Face(ft_face);
    assert(!error, "FreeType error. %\n", error);
    if error {
        return 0, 0;
    }

    error = FT_Set_Pixel_Sizes(ft_face, 0, xx pixel_height);
    assert(!error, "FreeType error. %\n", error);
    if error {
        return 0, 0;
    }

    image_width: int;
    image_height: int;
    for character: character_set {
        if !FT_Get_Char_Index(ft_face, character) {
            continue;
        }

        FT_Load_Char(ft_face, character, FT_LOAD_DEFAULT);
        FT_Render_Glyph(ft_face.glyph, .FT_RENDER_MODE_SDF);

        image_width = max(image_width, ft_face.glyph.bitmap.width);
        image_height = max(image_height, ft_face.glyph.bitmap.rows);
    }
    return image_width, image_height;
}

get_character_set :: (bytes: [] u8) -> [] u32 {
    #import "freetype-2.12.1";

    ft_font: FT_Library;
    error := FT_Init_FreeType(*ft_font);
    defer FT_Done_FreeType(ft_font);
    assert(!error, "FreeType error. %\n", error);
    if error {
        return .[];
    }

    ft_face: FT_Face;
    error = FT_New_Memory_Face(ft_font, bytes.data, xx bytes.count, 0, *ft_face);
    defer FT_Done_Face(ft_face);
    assert(!error, "FreeType error. %\n", error);
    if error {
        return .[];
    }

    found_characters: [..] u32;

    gindex: u32;
    charcode := cast(u32) FT_Get_First_Char(ft_face, *gindex);
    while gindex {
        array_add(*found_characters, charcode);
        charcode = cast(u32) FT_Get_Next_Char(ft_face, charcode, *gindex);
    }

    return found_characters;
}

load_characters :: (font: *Font, bytes: [] u8, pixel_height: int, character_set: [] u32) -> bool {
    #import "freetype-2.12.1";

    print("Warning! Calling create_font! This should never happen during a normal run.\n");
    print_stack_trace();

    assert(font.max_width != 0 && font.max_height != 0, "Cannot load characters into a font that hasn't already determined it's max size.\n");

    ft_font: FT_Library;
    error := FT_Init_FreeType(*ft_font);
    defer FT_Done_FreeType(ft_font);
    assert(!error, "FreeType error. %\n", error);
    if error {
        return false;
    }

    ft_face: FT_Face;
    error = FT_New_Memory_Face(ft_font, bytes.data, xx bytes.count, 0, *ft_face);
    defer FT_Done_Face(ft_face);
    assert(!error, "FreeType error. %\n", error);
    if error {
        return false;
    }

    error = FT_Set_Pixel_Sizes(ft_face, 0, xx pixel_height);
    assert(!error, "FreeType error. %\n", error);
    if error {
        return false;
    }

    image_width := font.max_width;
    image_height := font.max_height;
    glyph_bytes := image_width * image_height;

    glyph_data := *font.glyph_data;

    alloc_next_gylph :: () -> [] u8, int #expand {
        required_size := `glyph_data.count + `glyph_bytes;
        while `glyph_data.allocated < required_size {
            array_reserve(`glyph_data, max(`glyph_data.allocated * 2, `glyph_bytes));
        }

        next_glyph: [] u8;
        next_glyph.data = `glyph_data.data + `glyph_data.count;
        next_glyph.count = `glyph_bytes;

        memset(next_glyph.data, 0, next_glyph.count);

        data_index := `glyph_data.count;

        `glyph_data.count += `glyph_bytes;

        return next_glyph, data_index;
    }

    for character: character_set {
        if !FT_Get_Char_Index(ft_face, character) {
            continue;
        }

        // load character glyph
        error := FT_Load_Char(ft_face, character, FT_LOAD_DEFAULT);
        assert(!error, "FreeType failed to load glyph. % %\n", character, error);
        if error {
            return false;
        }

        error = FT_Render_Glyph(ft_face.glyph, .FT_RENDER_MODE_SDF);
        assert(!error, "FreeType failed to render the glyph. % %\n", character, error);
        if error {
            return false;
        }

        existing_info_found, existing_info := table_find_new(*font.characters, character);

        glyph_width := cast(int) ft_face.glyph.bitmap.width;
        glyph_height := cast(int) ft_face.glyph.bitmap.rows;
        glyph_pixel_mode := cast(FT_Pixel_Mode) ft_face.glyph.bitmap.pixel_mode;
        assert(glyph_width <= image_width, "Your glyph cannot be larger than the max width.\n");
        assert(glyph_height <= image_height, "Your glyph cannot be larger than the max height.\n");
        assert(glyph_pixel_mode == .GRAY, "Glyph must be mono. %\n", glyph_pixel_mode);

        next_glyph: [] u8;
        data_index: int;
        if existing_info_found {
            next_glyph.data = glyph_data.data + existing_info.data_index;
            next_glyph.count = glyph_bytes;
            data_index = existing_info.data_index;
        } else {
            next_glyph, data_index = alloc_next_gylph();
        }

        for y: 0..glyph_height - 1 {
            dest := next_glyph.data + y * image_width;
            src := ft_face.glyph.bitmap.buffer + y * glyph_width;
            memcpy(dest, src, glyph_width);
        }

        info: CharacterInfo;
        info.data_index = data_index;
        info.width = glyph_width;
        info.height = glyph_height;
        info.bearing = .{ft_face.glyph.bitmap_left, ft_face.glyph.bitmap_top};
        info.advance = .{ft_face.glyph.advance.x, ft_face.glyph.advance.y};
        table_set(*font.characters, character, info);
    }

    return true;
}

load_font :: (path: string, pixel_height: int, character_set: [] u32 = .[], should_upload: bool = true) -> *Font, bool {
    font, success := load_font(.[path], pixel_height, character_set, should_upload);
}

load_font :: (paths: [] string, pixel_height: int, character_set: [] u32 = .[], should_upload: bool = true) -> *Font, bool {
    file_bytes: [..] [] u8;
    file_bytes.allocator = temp;

    for path: paths {
        file, success := read_entire_file(path);
        assert(success, "Could not read font file. %\n", path);
        if !success {
            return null, false;
        }

        bytes: [] u8;
        bytes.data = file.data;
        bytes.count = file.count;

        array_add(*file_bytes, bytes);
    }

    character_sets: [..] [] u32;
    character_sets.allocator = temp;
    for bytes: file_bytes {
        if character_set {
            array_add(*character_sets, character_set);
        } else {
            array_add(*character_sets, get_character_set(bytes,, temp));
        }
    }

    defer {
        for bytes: file_bytes {
            array_free(bytes);
        }
    }

    font := New(Font);

    for bytes: file_bytes {
        print("Loading character bounds for % for % characters.\n", paths[it_index], character_sets[it_index].count);
        width, height := get_character_bounds(bytes, pixel_height, character_sets[it_index]);

        font.max_width = max(font.max_width, width);
        font.max_height = max(font.max_height, height);
    }

    print("Done loading character bounds.\n");

    for bytes: file_bytes {
        print("Loading character image data for % for % characters.\n", paths[it_index], character_sets[it_index].count);
        success := load_characters(font, bytes, pixel_height, character_sets[it_index]);
        assert(success, "Could not load font characters. %\n", paths[it_index]);
        if !success {
            return null, false;
        }
    }

    print("Done loading character image data.\n");

    {
        image: Image3;
        image.pixels = font.glyph_data;
        image.width = font.max_width;
        image.height = font.max_height;
        image.depth = font.glyph_data.count / (font.max_width * font.max_height);

        image.format = .R8;
        save_image(image, tprint("%.%.debug.png", paths[paths.count - 1], pixel_height));
    }

    if should_upload {
        upload(font);
    }

    return font, true;
}

get_character_byte_view :: (font: *Font, character: u32) -> bool, [] u8 {
    found, info := table_find_new(*font.characters, character);
    if !found {
        return false, .[];
    }

    glyph_bytes := font.max_width * font.max_height;

    byte_view: [] u8;
    byte_view.data = font.glyph_data.data + info.data_index;
    byte_view.count = glyph_bytes;
    return true, byte_view;
}

upload_character :: (font: *Font, character: u32) -> bool, layer: int {
    for *recent: font.loaded_characters {
        if recent.character == character {
            recent.frame = font.frame;
            return true, it_index;
        }
    }

    oldest_index := 0;
    oldest_frame := font.frame;

    for recent: font.loaded_characters {
        if recent.frame < oldest_frame {
            oldest_index = it_index;
            oldest_frame = recent.frame;
        }
    }

    if oldest_frame < font.frame {
        // replace and upload new character
        font.loaded_characters[oldest_index].character = character;
        font.loaded_characters[oldest_index].frame = font.frame;

        found, byte_view := get_character_byte_view(font, character);
        assert(found, "Could not get glyph for character. %\n", character);
        if !found {
            return false, 0;
        }

        update_texture_layer(*font.texture, oldest_index, byte_view);

        return true, oldest_index;
    }

    assert(false, "This shouldn't happen until it's chinsese or japanese.\n");

    return false, 0;
}

upload :: (font: *Font) {
    if font.texture.buffer {
        print("Warning: Trying to upload a font that's already uploaded.\n", true);
        return;
    }

    font.texture = create_texture_array(font.max_width, font.max_height, loaded_char_count, .R8);

    if !font_system_geometry {
        font_system_geometry = create_geometry(.[
            0.0, 0.0, 0.0,
            0.0, 1.0, 0.0,
            1.0, 1.0, 0.0,
            1.0, 0.0, 0.0,
        ], .[
            0, 1, 2,
            0, 2, 3,
        ], .[.Position]);
    }

    font.font_system = create_instanced_model(FontParticleGpu, font_system_geometry);
    font.font_system.shader = *font_particle_shader;
    font.font_system.cull_face = false;
    set(*font.font_system.uniforms, "uTexture", font.texture);
}

// create_character_set :: (ranges: ..[2] u32) -> [] u32 {
//     character_set: [..] u32;

//     for range: ranges {
//         for i: range[0]..range[1] {
//             array_add(*character_set, i);
//         }
//     }

//     return character_set;
// }

#scope_module

font_system_geometry: *Geometry;
