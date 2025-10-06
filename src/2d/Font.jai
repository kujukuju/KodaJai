
Font :: struct {
    characters: Table(u32, CharacterInfo);
    texture: TextureArray;
    image: Image3;
    max_width: int;
    max_height: int;
    buffer_required: bool;
    buffer_view: Matrix4;
    font_system: *InstancedModel(FontParticleGpu); @serializer_skip
    font_instances: [..] FontParticleGpu; @serializer_skip
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

FontParticleCpu :: struct {

}

CharacterInfo :: struct {
    index: int;
    width: int;
    height: int;
    bearing: Point2;
    advance: Point2;
}

create_font :: (bytes: [] u8, pixel_height: int, character_set: [] u32 = .[], should_upload: bool = true) -> *Font, bool {
    #import "freetype-2.12.1";

    print("Warning! Calling create_font! This should never happen during a normal run.\n");
    print_stack_trace();

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

    requested_characters: [] u32;
    if character_set {
        requested_characters = character_set;
    } else {
        found_characters: [..] u32;
        found_characters.allocator = temp;

        gindex: u32;
        charcode := cast(u32) FT_Get_First_Char(ft_face, *gindex);
        while gindex {
            array_add(*found_characters, charcode);
            charcode = cast(u32) FT_Get_Next_Char(ft_face, charcode, *gindex);
        }

        requested_characters = found_characters;
    }

    // TODO this isn't right at all... load_renderer loads the bitmap
    image_width: int;
    image_height: int;
    face_count: int;
    for character: requested_characters {
        if !FT_Get_Char_Index(ft_face, character) {
            continue;
        }

        FT_Load_Char(ft_face, character, FT_LOAD_DEFAULT);
        FT_Render_Glyph(ft_face.glyph, .FT_RENDER_MODE_SDF);

        image_width = max(image_width, ft_face.glyph.bitmap.width);
        image_height = max(image_height, ft_face.glyph.bitmap.rows);
        face_count += 1;
    }
    image_layer_stride := image_width * image_height;
    font.max_width = image_width;
    font.max_height = image_height;

    layer_index: int;
    font.image = create_image3(image_width, image_height, face_count, .R8);

    for character: requested_characters {
        if !FT_Get_Char_Index(ft_face, character) {
            continue;
        }

        // load character glyph
        error := FT_Load_Char(ft_face, character, FT_LOAD_DEFAULT);
        if error {
            print_stack_trace();
            print("FreeType failed to load glyph. % %\n", character, error);
            return null, false;
        }

        error = FT_Render_Glyph(ft_face.glyph, .FT_RENDER_MODE_SDF);
        if error {
            print("FreeType failed to render the glyph. % %\n", character, error);
            return null, false;
        }

        glyph_width := cast(int) ft_face.glyph.bitmap.width;
        glyph_height := cast(int) ft_face.glyph.bitmap.rows;
        assert(glyph_width <= image_width, "Your glyph cannot be larger than the max width.\n");
        assert(glyph_height <= image_height, "Your glyph cannot be larger than the max height.\n");
        assert(layer_index < face_count, "You cannot have more characters than num faces.\n");

        for y: 0..glyph_height - 1 {
            dest := font.image.pixels.data + image_layer_stride * layer_index + y * image_width;
            src := ft_face.glyph.bitmap.buffer + y * glyph_width;
            memcpy(dest, src, glyph_width);
        }

        info: CharacterInfo;
        info.index = layer_index;
        info.width = glyph_width;
        info.height = glyph_height;
        info.bearing = .{ft_face.glyph.bitmap_left, ft_face.glyph.bitmap_top};
        info.advance = .{ft_face.glyph.advance.x, ft_face.glyph.advance.y};
        table_set(*font.characters, character, info);

        layer_index += 1;
    }

    if should_upload {
        upload(font);
    }

    return font, true;
}

load_font :: (path: string, pixel_height: int, character_set: [] u32 = .[], should_upload: bool = true) -> *Font, bool {
    file, success := read_entire_file(path);
    defer free(file);
    if !success {
        return null, false;
    }

    byte_view: [] u8;
    byte_view.data = file.data;
    byte_view.count = file.count;

    font, created := create_font(byte_view, pixel_height, character_set, should_upload);
    return font, created;
}

// takes the font image, adds padding and offsets data values
pad_font :: (font: *Font, padding: float) {
    assert(!font.texture.buffer, "You cannot have a texture at the time of generating font padding.\n");
    assert(!!font.image.pixels, "You must have image data at the time of generating font padding.\n");
    assert(font.image.format == .R8, "You can only currently pad fonts that are R8 format because you shouldn't really need anything else.\n");

    half_padding := cast(int) ceil(padding);
    total_padding := half_padding * 2;

    padded := create_image3(font.image.width + total_padding, font.image.height + total_padding, font.image.depth, .R8);

    index := 0;
    for *character: font.characters {
        defer index += 1;

        print("Generating % / %.\n", index, font.characters.count);

        layer := character.index;

        image_offset := font.image.width * font.image.height * layer;
        padded_offset := padded.width * padded.height * layer;

        for dest_y: 0..padded.height - 1 {
            for dest_x: 0..padded.width - 1 {

                distance_to_pixel := padding + 1.0;
                for offset_y: -half_padding..half_padding {
                    for offset_x: -half_padding..half_padding {
                        source_y := dest_y - half_padding + offset_y;
                        source_x := dest_x - half_padding + offset_x;

                        source_color := 0.0;
                        if source_x >= 0 && source_x < font.image.width && source_y >= 0 && source_y < font.image.height {
                            source_color = font.image.pixels[image_offset + source_y * font.image.width + source_x] / 255.0;
                        }

                        if source_color > 0.5 {
                            distance := sqrt(cast(float) offset_y * offset_y + cast(float) offset_x * offset_x) + 1.0 - (source_color - 0.5) * 2.0;
                            if distance < distance_to_pixel {
                                distance_to_pixel = distance;
                            }
                        }
                    }
                }

                if distance_to_pixel < padding + 1.0 {
                    alpha := clamp(padding + 1.0 - distance_to_pixel, 0, 1);

                    padded.pixels[padded_offset + dest_y * padded.width + dest_x] = cast(u8) round(alpha * 255);
                }
            }
        }

        character.width += total_padding;
        character.height += total_padding;
        character.bearing += point2(-half_padding, half_padding);
    }

    destroy(font.image);
    font.image = padded;
    font.max_width = padded.width;
    font.max_height = padded.height;
}

upload :: (font: *Font, clear_image: bool = true) {
    if font.texture.buffer {
        print("Warning: Trying to upload a font that's already uploaded.\n", true);
        return;
    }

    font.texture = create_texture_array(font.image);

    if clear_image {
        destroy(font.image);
        font.image = .{};
    }

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

create_character_set :: (ranges: ..[2] u32) -> [] u32 {
    character_set: [..] u32;

    for range: ranges {
        for i: range[0]..range[1] {
            array_add(*character_set, i);
        }
    }

    return character_set;
}

#scope_module

font_system_geometry: *Geometry;
