
TextureArray :: struct {
    buffer: u32;
    width: s32;
    height: s32;
    depth: s32;
    format: PixelFormat;
    wrap: [2] TextureWrap;
    interp: TextureInterp;
    border_color: Color;
    data: *u8; @serializer_skip
}

load_texture_array :: (path: string, wrap: TextureWrap = .Clamp, interp: TextureInterp = .Linear, should_upload: bool = true) -> TextureArray {
    wrap_array: [2] TextureWrap;
    wrap_array[0] = wrap;
    wrap_array[1] = wrap;

    return create_texture_array(load_image3(path), wrap_array, interp, should_upload);
}

load_texture_array :: (path: string, wrap: [2] TextureWrap, interp: TextureInterp, should_upload: bool = true) -> TextureArray {
    return create_texture_array(load_image3(path), wrap, interp, should_upload);
}

create_texture_array :: (width: int, height: int, depth: int, format: PixelFormat, wrap: TextureWrap = .Clamp, interp: TextureInterp = .Linear, should_upload: bool = true) -> TextureArray {
    texture: TextureArray;
    texture.width = xx width;
    texture.height = xx height;
    texture.depth = xx depth;
    texture.format = format;
    texture.wrap = .[wrap, wrap];
    texture.interp = interp;

    if should_upload {
        upload(*texture);
    }

    return texture;
}

create_texture_array :: (image: Image3, wrap: TextureWrap = .Clamp, interp: TextureInterp = .Linear, should_upload: bool = true) -> TextureArray {
    wrap_array: [2] TextureWrap;
    wrap_array[0] = wrap;
    wrap_array[1] = wrap;

    return create_texture_array(image, wrap_array, interp, should_upload);
}

create_texture_array :: (image: Image3, wrap: [2] TextureWrap, interp: TextureInterp, should_upload: bool = true) -> TextureArray {
    if !image.pixels.data {
        print("Could not create texture.\n");
        return .{};
    }

    texture: TextureArray;
    texture.data = image.pixels.data;
    texture.width = xx image.width;
    texture.height = xx image.height;
    texture.depth = xx image.depth;
    texture.format = image.format;
    texture.wrap = wrap;
    texture.interp = interp;

    if should_upload {
        upload(*texture);
    }

    return texture;
}

// TODO clear data here and in texture unless explicitly requested otherwise
upload :: (texture: *TextureArray) {
    if texture.buffer {
        print("Warning: Trying to upload a texture array that's already uploaded.\n", true);
        return;
    }

    wrap_formats: [2] s32;
    wrap_formats[0] = get_gl_format(texture.wrap[0]);
    wrap_formats[1] = get_gl_format(texture.wrap[1]);

    interp_min_format := get_gl_min_format(texture.interp);
    interp_mag_format := get_gl_mag_format(texture.interp);

    has_mipmap := get_mipmap(texture.interp);

    glGenTextures(1, *texture.buffer);
    glBindTextureTemporary(GL_TEXTURE_2D_ARRAY, texture.buffer);
    glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_S, wrap_formats[0]);
    glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_T, wrap_formats[1]);
    glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, interp_min_format);
    glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, interp_mag_format);

    if texture.wrap[0] == .Border || texture.wrap[1] == .Border {
        glTexParameterfv(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_BORDER_COLOR, texture.border_color.component.data);
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

    glTexImage3D(GL_TEXTURE_2D_ARRAY, 0, gl_internal_format, xx texture.width, xx texture.height, xx texture.depth, 0, gl_format, gl_type, texture.data);

    if has_mipmap {
        glGenerateMipmap(GL_TEXTURE_2D_ARRAY);
    }
}

unload :: (texture: *TextureArray) {
    if texture.buffer {
        release_texture_slot(texture.buffer);
        glDeleteTextures(1, *texture.buffer);
        texture.buffer = 0;
    }
}

// TODO add method to remove data if you'll never unload

destroy :: (texture: TextureArray) {
    stbi_image_free(texture.data);
    release_texture_slot(texture.buffer);
    glDeleteTextures(1, *texture.buffer);
}

get_bytes :: (texture: TextureArray) -> int {
    return texture.width * texture.height * texture.depth * get_stride(texture.format);
}

update_texture :: (texture: *TextureArray, image: Image3) {
    assert(texture.width == image.width && texture.height == image.height && texture.depth == image.depth, "Dimensions must match.");
    assert(texture.format == image.format, "Formats must match.");

    update_texture(texture, image.pixels);
}

update_texture :: (texture: *TextureArray, bytes: [] u8) {
    // TODO can upload this in parallel of it helps
    stride := get_stride(texture.format);
    depth := bytes.count / stride / (texture.width * texture.height);

    gl_format := get_gl_format(texture.format);
    gl_type := get_gl_type(texture.format);

    glTextureSubImage3D(texture.buffer, 0, 0, 0, 0, xx texture.width, xx texture.height, xx depth, gl_format, gl_type, bytes.data);
}

update_texture_layer :: (texture: *TextureArray, layer: int, bytes: [] u8) {
    // TODO can upload this in parallel of it helps
    stride := get_stride(texture.format);
    assert(bytes.count == texture.width * texture.height * stride, "Incorrect texture layer byte count.\n");

    gl_format := get_gl_format(texture.format);
    gl_type := get_gl_type(texture.format);

    glTextureSubImage3D(texture.buffer, 0, 0, 0, xx layer, xx texture.width, xx texture.height, 1, gl_format, gl_type, bytes.data);
}

convert_format :: (texture: *TextureArray, desired_format: PixelFormat) {
    assert(texture.format == .R8 || texture.format == .RG8 || texture.format == .RGB8 || texture.format == .RGBA8, tprint("Cannot convert from format of %.\n", texture.format));
    assert(desired_format == .R8 || desired_format == .RG8 || desired_format == .RGB8 || desired_format == .RGBA8, tprint("Cannot convert to format of %.\n", desired_format));

    if texture.format == desired_format {
        return;
    }

    texture_stride := get_stride(texture.format);
    desired_stride := get_stride(desired_format);

    texture.format = desired_format;

    total_pixels := texture.width * texture.height * texture.depth;

    if desired_stride < texture_stride {
        for i: 0..total_pixels - 1 {
            texture_index := i * texture_stride;
            desired_index := i * desired_stride;

            memcpy(texture.data + desired_index, texture.data + texture_index, desired_stride);
        }
    } else {
        // untested
        old_data := texture.data;
        defer c_free(old_data);

        // honestly I'm not sure if this gives you guaranteed zeroed out memory
        texture.data = c_alloc(cast(u64) (texture.width * texture.height * texture.depth * desired_stride));
        memset(texture.data, 0, texture.width * texture.height * texture.depth * desired_stride);

        for i: 0..total_pixels - 1 {
            texture_index := i * texture_stride;
            desired_index := i * desired_stride;

            memcpy(texture.data + desired_index, old_data + texture_index, texture_stride);
        }
    }
}
