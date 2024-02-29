
Font :: struct {
    // TODO instead of a table I could use a binary searchable array
    characters: Table(u32, CharacterInfo);
    textures: TextureArray;
    images: Image3;
    max_width: int;
    max_height: int;
    vao: GLuint;
    vbo: GLuint;
}

FontParticleGpu :: struct {
    position: Vector2;
    size: Vector2;
    texSize: Vector2;
    index: float;
}

FontParticleCpu :: struct {

}

CharacterInfo :: struct {
    index: int;
    width: int;
    height: int;
    bearing: Point2;
    advance: Point2;
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

    image_width: int;
    image_height: int;
    face_count: int;
    gindex: u32;
    charcode := FT_Get_First_Char(ft_face, *gindex);
    while gindex {
        FT_Load_Char(ft_face, charcode, FT_LOAD_RENDER);
        image_width = max(image_width, ft_face.glyph.bitmap.width);
        image_height = max(image_height, ft_face.glyph.bitmap.rows);
        face_count += 1;

        charcode = FT_Get_Next_Char(ft_face, charcode, *gindex);
    }
    image_layer_stride := image_width * image_height;
    font.max_width = image_width;
    font.max_height = image_height;

    // for i: 0..ft_face.num_fixed_sizes - 1 {
    //     size := ft_face.available_sizes + i;
    //     image_width = max(image_width, size.width);
    //     image_height = max(image_height, size.height);
    // }
    // image_layer_stride := image_width * image_height;
    // font.max_width = image_width;
    // font.max_height = image_height;

    layer_index: int;
    font.images = create_image3(image_width, image_height, face_count, .R8);

    gindex = 0;
    charcode = FT_Get_First_Char(ft_face, *gindex);
    while gindex {
        // load character glyph 
        error := FT_Load_Char(ft_face, charcode, FT_LOAD_RENDER);
        if error {
            print_stack_trace();
            print("FreeType failed to load glyph. % %\n", charcode, error);
            return null, false;
        }

        print("% % %\n", ft_face, ft_face.glyph, ft_face.glyph.bitmap);

        glyph_width := ft_face.glyph.bitmap.width;
        glyph_height := ft_face.glyph.bitmap.rows;
        assert(glyph_width <= image_width, "Your glyph cannot be larger than the max width.\n");
        assert(glyph_height <= image_height, "Your glyph cannot be larger than the max height.\n");
        assert(layer_index < face_count, "You cannot have more characters than num faces.\n");

        for y: 0..glyph_height - 1 {
            dest := font.images.pixels.data + image_layer_stride * layer_index + y * image_width;
            src := ft_face.glyph.bitmap.buffer + y * glyph_width;
            memcpy(dest, src, glyph_width);
        }

        character: CharacterInfo;
        character.index = layer_index;
        character.width = glyph_width;
        character.height = glyph_height;
        character.bearing = .{ft_face.glyph.bitmap_left, ft_face.glyph.bitmap_top};
        character.advance = .{ft_face.glyph.advance.x, ft_face.glyph.advance.y};
        table_set(*font.characters, charcode, character);

        layer_index += 1;
        
        charcode = FT_Get_Next_Char(ft_face, charcode, *gindex);
    }

    // save_image(font.images, "font.png");

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
        empty: TextureArray;
        font.textures = empty;

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
    print("WARNING NEED TO DO THIS.\n");
    return;
    assert(!font.textures.buffer, "You cannot have textures at the time of generating font padding.");
    assert(!!font.images.pixels.data, "You must have image data at the time of generating font padding.");

    // half_padding := cast(int) ceil(padding);
    // total_padding := half_padding * 2;

    // for i: 0..font.characters.count - 1 {
    // // for i: (#char "a")..(#char "a") {
    //     if !font.characters[i].pixels {
    //         continue;
    //     }

    //     print("Generating %\n", i);

    //     character := font.characters[i];

    //     padded := create_image(character.width + total_padding, character.height + total_padding, .R8);

    //     for dest_y: 0..padded.height - 1 {
    //         for dest_x: 0..padded.width - 1 {

    //             distance_to_pixel := padding + 1.0;
    //             for offset_y: -half_padding..half_padding {
    //                 for offset_x: -half_padding..half_padding {
    //                     source_y := dest_y - half_padding + offset_y;
    //                     source_x := dest_x - half_padding + offset_x;
    //                     source_color := get_pixel(character, point2(source_x, source_y));

    //                     if source_color.r > 0 {
    //                         distance := sqrt(cast(float) offset_y * offset_y + offset_x * offset_x) + 1.0 - source_color.r;
    //                         if distance < distance_to_pixel {
    //                             distance_to_pixel = distance;
    //                         }
    //                     }
    //                 }
    //             }

    //             if distance_to_pixel < padding + 1.0 {
    //                 alpha := clamp(padding + 1.0 - distance_to_pixel, 0, 1);

    //                 padded.pixels[dest_y * padded.width + dest_x] = cast(u8) round(alpha * 255);
    //             }
    //         }
    //     }

    //     destroy(font.characters[i]);
    //     font.characters[i] = padded;
    //     font.infos[i].bearing += point2(-half_padding, half_padding);
    // }
}

upload :: (font: *Font, clear_images: bool = true) {
    if font.vao {
        return;
    }

    font.textures = create_texture_array(font.images);

    if clear_images {
        destroy(font.images);
    }

    if !font_system_geometry {
        font_system_geometry = create_geometry(.[
            0.0, 1.0,
            0.0, 0.0,
            1.0, 0.0,
            1.0, 1.0,
        ], .[
            0, 1, 2,
            0, 2, 3,
        ], .[.Position2]);

        particle_system_init(*font_system, *font_particle_shader, font_system_geometry);
    }
}

#scope_module

font_system: ParticleSystem(FontParticleGpu, FontParticleCpu, sort = false);
font_system_geometry: *Geometry;
