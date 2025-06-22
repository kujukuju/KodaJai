
Texture :: struct {
    name: string;
    buffer: u32;
    width: s32;
    height: s32;
    format: PixelFormat;
    wrap: TextureWrap;
    interp: TextureInterp;
    border_color: Color;
    multisample: int;
    shadow: bool;
    data: *u8;
}

load_texture :: (path: string, wrap: TextureWrap = .Clamp, interp: TextureInterp = .Linear, should_upload: bool = true) -> Texture {
    return create_texture(load_image(path), wrap, interp, should_upload);
}

create_texture :: (image: Image, wrap: TextureWrap = .Clamp, interp: TextureInterp = .Linear, should_upload: bool = true) -> Texture {
    if !image.pixels.data {
        print("Could not create texture.\n");
        return .{};
    }

    texture: Texture;
    texture.data = image.pixels.data;
    texture.width = xx image.width;
    texture.height = xx image.height;
    texture.format = image.format;
    texture.wrap = wrap;
    texture.interp = interp;

    if should_upload {
        upload(*texture);
    }

    return texture;
}

create_texture :: (width: int, height: int, format: PixelFormat = .RGBA8, wrap: TextureWrap = .Clamp, interp: TextureInterp = .Linear, shadow: bool = false, should_upload: bool = true) -> Texture {
    texture: Texture;
    texture.width = xx width;
    texture.height = xx height;
    texture.format = format;
    texture.wrap = wrap;
    texture.interp = interp;
    texture.shadow = shadow;

    if should_upload {
        upload(*texture);
    }

    return texture;
}

upload :: (texture: *Texture) {
    if texture.buffer {
        return;
    }

    wrap_format := get_gl_format(texture.wrap);
    interp_min_format := get_gl_min_format(texture.interp);
    interp_mag_format := get_gl_mag_format(texture.interp);
    has_mipmap := get_mipmap(texture.interp);

    texture_type: u32 = GL_TEXTURE_2D;
    if texture.multisample > 1 {
        texture_type = GL_TEXTURE_2D_MULTISAMPLE;
    }

    glGenTextures(1, *texture.buffer);
    glBindTextureTemporary(texture_type, texture.buffer);
    glTexParameteri(texture_type, GL_TEXTURE_WRAP_S, wrap_format);
    glTexParameteri(texture_type, GL_TEXTURE_WRAP_T, wrap_format);
    glTexParameteri(texture_type, GL_TEXTURE_MIN_FILTER, interp_min_format);
    glTexParameteri(texture_type, GL_TEXTURE_MAG_FILTER, interp_mag_format);

    if texture.shadow {
        glTexParameteri(texture_type, GL_TEXTURE_COMPARE_MODE, GL_COMPARE_REF_TO_TEXTURE);
        glTexParameteri(texture_type, GL_TEXTURE_COMPARE_FUNC, GL_LEQUAL);
    }

    if texture.wrap == .Border {
        glTexParameterfv(texture_type, GL_TEXTURE_BORDER_COLOR, texture.border_color.component.data);
    }

    stride := get_stride(texture.format);

    four_divisible := (texture.width * stride) % 4 == 0;
    two_divisible := (texture.width * stride) % 2 == 0;
    pixel_store: s32;
    if four_divisible then pixel_store = 4;
    else if two_divisible then pixel_store = 2;
    else pixel_store = 1;

    glPixelStorei(GL_PACK_ALIGNMENT, pixel_store);
    glPixelStorei(GL_UNPACK_ALIGNMENT, pixel_store);

    gl_format := get_gl_format(texture.format);
    gl_internal_format := get_gl_internal_format(texture.format);
    gl_type := get_gl_type(texture.format);

    if texture.multisample > 1 {
        glTexImage2DMultisample(GL_TEXTURE_2D_MULTISAMPLE, cast(u32) texture.multisample, cast(u32) gl_internal_format, xx texture.width, xx texture.height, GL_TRUE);
    } else {
        glTexImage2D(GL_TEXTURE_2D, 0, gl_internal_format, xx texture.width, xx texture.height, 0, gl_format, gl_type, texture.data);
    }

    if has_mipmap {
        glGenerateMipmap(GL_TEXTURE_2D);
    }
}

unload :: (texture: *Texture) {
    if texture.buffer {
        release_texture_slot(texture.buffer);
        glDeleteTextures(1, *texture.buffer);
        texture.buffer = 0;
    }
}

destroy :: (texture: Texture, children: bool = true) {
    if children && texture.data {
        free(texture.data);
    }

    if texture.buffer {
        release_texture_slot(texture.buffer);
        glDeleteTextures(1, *texture.buffer);
    }

    if texture.name {
        free(texture.name);
    }
}

get_bytes :: (texture: Texture) -> int {
    return texture.width * texture.height * get_stride(texture.format);
}

scale_data :: (data: Texture, width: s32, height: s32, preserve_ratio: bool = true) -> Texture {
    byte_count := 0;
    if data.format == {
        case .R8;
            byte_count = 1;
        case .RG8;
            byte_count = 2;
        case .RGB8;
            byte_count = 3;
        case .RGBA8;
            byte_count = 4;
    }

    texture_data: Texture;
    texture_data.data = NewArray(width * height * byte_count, u8).data;
    texture_data.width = width;
    texture_data.height = height;
    texture_data.format = data.format;

    // the number of pixels that are padding for the left, and top
    padding_left: int;
    padding_top: int;
    padded_width: int;
    padded_height: int;

    if preserve_ratio {
        scale := min(cast(float) width / data.width, cast(float) height / data.height);
        padded_width = cast(int) (data.width * scale);
        padded_height = cast(int) (data.height * scale);

        padding_left = (width - padded_width) / 2;
        padding_top = (height - padded_height) / 2;
    } else {
        padded_width = width;
        padded_height = height;
    }

    assert(padding_left + padded_width <= width && padding_top + padded_height <= height && "Scale math casting incorrect.");

    for x: 0..padded_width - 1 {
        for y: 0..padded_height - 1 {
            dest_pixel_index := (y + padding_top) * width + x + padding_left;
            dest_address := texture_data.data + dest_pixel_index * byte_count;
            // TODO remove
            assert(dest_pixel_index * byte_count + byte_count <= texture_data.width * texture_data.height * byte_count && "Pixel dest out of bounds.");

            src_x := cast(int) (cast(float) x / padded_width * data.width);
            src_y := cast(int) (cast(float) y / padded_height * data.height);
            src_pixel_index := src_y * data.width + src_x;
            src_address := data.data + src_pixel_index * byte_count;
            // TODO remove
            assert(src_pixel_index * byte_count + byte_count <= data.width * data.height * byte_count && "Pixel src out of bounds.");

            memcpy(dest_address, src_address, byte_count);
        }
    }

    return texture_data;
}

// TODO add a function to just clear the data memory but keep the buffer if you're confident you want to keep this texture always available

update_texture :: (texture: *Texture, image: Image) {
    assert(texture.width == image.width && texture.height == image.height, "Dimensions must match.");
    assert(texture.format == image.format, "Formats must match.");

    glTextureSubImage2D(texture.buffer, 0, 0, 0, xx texture.width, xx texture.height, get_gl_format(texture.format), GL_UNSIGNED_BYTE, image.pixels.data);
}

// convert_format :: (texture: *Texture, desired_format: PixelFormat) {
//     assert(texture.format == .R8 || texture.format == .RG8 || texture.format == .RGB8 || texture.format == .RGBA8, tprint("Cannot convert from format of %.\n", texture.format));
//     assert(desired_format == .R8 || desired_format == .RG8 || desired_format == .RGB8 || desired_format == .RGBA8, tprint("Cannot convert to format of %.\n", desired_format));

//     if texture.format == desired_format {
//         return;
//     }

//     texture_stride := get_stride(texture.format);
//     desired_stride := get_stride(desired_format);

//     texture.format = desired_format;

//     total_pixels := texture.width * texture.height;

//     if desired_stride < texture_stride {
//         for i: 0..total_pixels - 1 {
//             texture_index := i * texture_stride;
//             desired_index := i * desired_stride;

//             memcpy(texture.data + desired_index, texture.data + texture_index, desired_stride);
//         }
//     } else {
//         // untested
//         old_data := texture.data;
//         defer c_free(old_data);

//         // honestly I'm not sure if this gives you guaranteed zeroed out memory
//         texture.data = c_alloc(cast(u64) (texture.width * texture.height * desired_stride));
//         memset(texture.data, 0, texture.width * texture.height * desired_stride);

//         for i: 0..total_pixels - 1 {
//             texture_index := i * texture_stride;
//             desired_index := i * desired_stride;

//             memcpy(texture.data + desired_index, old_data + texture_index, texture_stride);
//         }
//     }
// }

create_image_from_data :: (texture: Texture) -> Image {
    texture_stride := get_stride(texture.format);

    byte_count := texture.width * texture.height * texture_stride;

    byte_view: [] u8;
    byte_view.data = texture.data;
    byte_view.count = byte_count;

    return create_image(byte_view, texture.width, texture.height, texture.format);
}

draw :: (texture: Texture, position: Vector2, anchor: Vector2 = .{}, tint: Color = .{1, 1, 1, 1}) {
    static_sprite.texture = texture;
    static_sprite.width = xx texture.width;
    static_sprite.height = xx texture.height;
    static_sprite.position = position;
    static_sprite.rotation = 0;
    static_sprite.anchor = anchor;
    static_sprite.tint = tint;
    static_sprite.shader = *default_shader;

    draw(static_sprite);
}

draw :: (texture: Texture, position: Vector2, size: Vector2, anchor: Vector2 = .{}, tint: Color = .{1, 1, 1, 1}) {
    static_sprite.texture = texture;
    static_sprite.width = size.x;
    static_sprite.height = size.y;
    static_sprite.position = position;
    static_sprite.rotation = 0;
    static_sprite.anchor = anchor;
    static_sprite.tint = tint;
    static_sprite.shader = *default_shader;

    draw(static_sprite);
}

draw :: (texture: Texture, position: Vector2, rotation: float = 0, scale: Vector2 = .{1, 1}, anchor: Vector2 = .{}) {
    static_sprite.texture = texture;
    static_sprite.width = texture.width * scale.x;
    static_sprite.height = texture.height * scale.y;
    static_sprite.position = position;
    static_sprite.rotation = rotation;
    static_sprite.anchor = anchor;
    static_sprite.tint = .{1, 1, 1, 1};
    static_sprite.shader = *default_shader;

    draw(static_sprite);
}
