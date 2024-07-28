
draw_text :: (content: string, font: *Font, position: Vector2, anchor: Vector2 = .{0, 0}, scale: float = 1.0, tint: Color = .{1, 1, 1, 1}, padding: float = 0.0, blur: float = 0.0, rotation: float = 0.0, world_position: Vector3 = .{}, fixed_height_string: string = "", fixed_width_string: string = "") {
    assert(!font.buffer_required, "Cannot draw text when doing a text buffer.\n");

    begin_buffer_text(font);
    buffer_text(content, font, position, anchor, scale, tint, padding, blur, rotation, world_position, fixed_height_string, fixed_width_string);
    flush_text(font);
}

// draw_text :: (content: string, font: *Font, transform: Matrix3, anchor: Vector2, scale: float, tint: Color, padding: float, blur: float, fixed_height_string: string = "") {
//     // draw_text(content, font, )
// }

draw_text :: (content: string, font: *Font, transform: Matrix3, anchor: Vector2, scale: float, tint: Color, padding: float, blur: float, rotation: float, world_position: Vector3, fixed_height_string: string = "", fixed_width_string: string = "") {
    assert(!font.buffer_required, "Cannot draw text when doing a text buffer.\n");

    begin_buffer_text(font);
    buffer_text(content, font, transform, anchor, scale, tint, padding, blur, rotation, world_position, fixed_height_string, fixed_width_string);
    flush_text(font);
}

begin_buffer_text :: (font: *Font) {
    assert(!font.buffer_required, "You cannot call begin buffer text twice in a row.\n");
    font.buffer_required = true;
    font.buffer_view = koda.view;
}

buffer_text :: (content: string, font: *Font, position: Vector2, anchor: Vector2 = .{0, 0}, scale: float = 1.0, tint: Color = .{1, 1, 1, 1}, padding: float = 0.0, blur: float = 0.0, rotation: float = 0.0, world_position: Vector3 = .{}, fixed_height_string: string = "", fixed_width_string: string = "") {
    translation := make_translation_matrix3(position);

    buffer_text(content, font, translation, anchor, scale, tint, padding, blur, rotation, world_position, fixed_height_string, fixed_width_string);
}

buffer_text :: (content: string, font: *Font, transform: Matrix3, anchor: Vector2, scale: float, tint: Color, padding: float, blur: float, rotation: float, world_position: Vector3, fixed_height_string: string = "", fixed_width_string: string = "") {
    assert(font.buffer_required, "You should call buffer text after calling begin buffer text.\n");
    if !font.buffer_required {
        return;
    }

    if !content {
        return;
    }

    assert(font.buffer_view == koda.view, "You cannot change your view in between buffer text calls.\n");
    if font.buffer_view != koda.view {
        old_view := koda.view;

        set_view(font.buffer_view);
        flush_text(font);
        
        set_view(old_view);
        begin_buffer_text(font);
    }

    offset_x := 0;
    if fixed_width_string {
        maximum_bearing_x := cast(int) S32_MIN;
        char: u32;
        index: int;
        while index < fixed_width_string.count {
            char, index = get_unicode_char(fixed_width_string, index);
            character, found := table_find(*font.characters, char);
            if !found {
                continue;
            }
            
            maximum_bearing_x = max(maximum_bearing_x, character.bearing.x);
        }

        char = get_unicode_char(content, 0);
        character, found := table_find(*font.characters, char);
        if found {
            offset_x = character.bearing.x - maximum_bearing_x;
        }
    }

    aabb := get_aabb(content, font, scale);
    if fixed_height_string {
        fixed_aabb := get_aabb(fixed_height_string, font, scale);
        aabb.lower.y = fixed_aabb.lower.y;
        aabb.upper.y = fixed_aabb.upper.y;
    }
    dimensions := aabb.upper - aabb.lower;

    x := -dimensions.x * anchor.x - aabb.lower.x + offset_x;
    y := -dimensions.y * anchor.y - aabb.lower.y;

    real_padding := padding / scale;
    if real_padding > 16 {
        // if !PRODUCTION then print("Warning: Your font padding can't be larger than 16 * your scale.\n");
        real_padding = 16;
    }

    real_blur := blur / scale;
    if real_blur + real_padding > 16 {
        // if !PRODUCTION then print("Warning: Your font blur + padding can't be larger than 16 * your scale.\n");
        real_blur = 16 - real_padding;
    }
    
    advance_y := 0;

    char: u32;
    index: int;
    while index < content.count {
        char, index = get_unicode_char(content, index);
        if char == #char "\n" {
            x = -dimensions.x * anchor.x - aabb.lower.x;
            y += advance_y * scale;
            advance_y = 0;
            continue;
        }

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
        gpu.transform = transform;
        gpu.tint = tint.rgba;
        gpu.padding = real_padding;
        gpu.scale = scale;
        gpu.blur = real_blur;
        gpu.rotation = rotation;
        gpu.world_position = world_position;

        particle_system_add_particle(*font.font_system, gpu, .{});

        // now advance cursors for next glyph (note that advance is number of 1/64 pixels)
        // bitshift by 6 to get value in pixels (2^6 = 64)
        x += (character.advance.x >> 6) * scale;
        advance_y = max(advance_y, character.height);
    }
}

flush_text :: (font: *Font) {
    projection := orthographic_projection_matrix(0, xx koda.width, xx koda.height, 0, -1.0, 1.0);
    flush_text(font, projection);
}

flush_text :: (font: *Font, projection: Matrix4) {
    font.buffer_required = false;

    set_depth_test_scope(false);
    set_cull_face_scope(false);

    particle_system_update_and_render(*font.font_system, 0, projection);
    particle_system_clear(*font.font_system);
}

get_aabb :: (content: string, font: *Font, position: Vector2 = .{0, 0}, anchor: Vector2 = .{0, 0}, scale: float = 1.0, fixed_height_string: string = "") -> AABB2 {
    aabb := get_aabb(content, font, scale);

    clip_offset := aabb.lower;
    dimensions := aabb.upper - aabb.lower;
    if fixed_height_string {
        fixed_aabb := get_aabb(fixed_height_string, font, scale);
        clip_offset = fixed_aabb.lower;
        dimensions = fixed_aabb.upper - fixed_aabb.lower;
    }

    aabb.lower += position;
    aabb.upper += position;

    aabb.lower += -dimensions * anchor - clip_offset;
    aabb.upper += -dimensions * anchor - clip_offset;

    return aabb;
}

get_aabb :: (content: string, font: *Font, scale: float) -> AABB2 {
    if !content {
        return .{};
    }

    x := 0.0;
    y := 0.0;

    aabb: AABB2;
    set_aabb := false;
    
    advance_y := 0;

    char: u32;
    index: int;
    while index < content.count {
        char, index = get_unicode_char(content, index);
        if char == #char "\n" {
            x = 0;
            y += advance_y * scale;
            advance_y = 0;
            continue;
        }

        character, found := table_find(*font.characters, char);
        if !found {
            print("Character out of bounds. %\n", char);
            continue;
        }

        xpos := x + character.bearing.x * scale;
        ypos := y - character.bearing.y * scale + font.max_height * scale;

        w := character.width * scale;
        h := character.height * scale;

        p1 := Vector2.{xpos, ypos};
        p2 := Vector2.{xpos + w, ypos + h};

        if !set_aabb {
            set_aabb = true;

            aabb.lower = min(p1, p2);
            aabb.upper = max(p1, p2);
        } else {
            aabb.lower = min(aabb.lower, min(p1, p2));
            aabb.upper = max(aabb.upper, max(p1, p2));
        }

        // now advance cursors for next glyph (note that advance is number of 1/64 pixels)
        // bitshift by 6 to get value in pixels (2^6 = 64)
        x += (character.advance.x >> 6) * scale;
        advance_y = max(advance_y, character.height);
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
