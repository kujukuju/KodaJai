Texture3 :: struct {
    buffer: u32;
    width: s32;
    height: s32;
    depth: s32;
    format: PixelFormat;
    storage: StorageFormat;
    wrap: [3] TextureWrap;
    interp: TextureInterp;
    border_color: Color;
    data: *u8;
}

create_texture3 :: (bytes: [] u8, wrap: TextureWrap = .Clamp, interp: TextureInterp = .Linear, storage: StorageFormat = .U8, should_upload: bool = true) -> Texture3 {
    wrap_array: [3] TextureWrap;
    wrap_array[0] = wrap;
    wrap_array[1] = wrap;
    wrap_array[2] = wrap;

    return create_texture3(bytes, wrap_array, interp, storage, should_upload);
}

create_texture3 :: (bytes: [] u8, wrap: [3] TextureWrap, interp: TextureInterp, storage: StorageFormat = .U8, should_upload: bool = true) -> Texture3 {
    texture := load_data(bytes);
    texture.wrap = wrap;
    texture.interp = interp;
    texture.storage = storage;

    if texture.data == null {
        print("Could not load texture.\n");
        return .{};
    }

    if should_upload {
        upload(*texture);
    }

    return texture;
}

create_texture3 :: (image: Image3, wrap: TextureWrap = .Clamp, interp: TextureInterp = .Linear, storage: StorageFormat = .U8, should_upload: bool = true) -> Texture3 {
    wrap_array: [3] TextureWrap;
    wrap_array[0] = wrap;
    wrap_array[1] = wrap;
    wrap_array[2] = wrap;

    return create_texture3(image, wrap_array, interp, storage, should_upload);
}

create_texture3 :: (image: Image3, wrap: [3] TextureWrap, interp: TextureWrap, storage: StorageFormat, should_upload: bool = true) -> Texture3 {
    if !image.pixels.data {
        print("Could not create texture.\n");
        return .{};
    }

    texture: Texture3;
    texture.data = image.pixels.data;
    texture.width = xx image.width;
    texture.height = xx image.height;
    texture.depth = xx image.depth;
    texture.format = image.format;
    texture.wrap = wrap;
    texture.interp = interp;
    texture.storage = storage;

    if should_upload {
        upload(*texture);
    }

    return texture;
}

load_texture3 :: (path: string, wrap: TextureWrap = .Clamp, interp: TextureInterp = .Linear, storage: StorageFormat = .U8, should_upload: bool = true) -> Texture3 {
    wrap_array: [3] TextureWrap;
    wrap_array[0] = wrap;
    wrap_array[1] = wrap;
    wrap_array[2] = wrap;

    return load_texture3(path, wrap_array, interp, storage, should_upload);
}

load_texture3 :: (path: string, wrap: [3] TextureWrap, interp: TextureInterp, storage: StorageFormat, should_upload: bool = true) -> Texture3 {
    file, success := read_entire_file(path, false);
    defer free(file);

    bytes: [] u8;
    bytes.data = file.data;
    bytes.count = file.count;

    return create_texture3(bytes, wrap, interp, storage, should_upload);
}

upload :: (texture: *Texture3) {
    if texture.buffer {
        return;
    }
    
    assert(!!texture.data, "Cannot generate texture with no data.");

    wrap_formats: [3] s32;
    wrap_formats[0] = get_gl_format(texture.wrap[0]);
    wrap_formats[1] = get_gl_format(texture.wrap[1]);
    wrap_formats[2] = get_gl_format(texture.wrap[2]);

    interp_min_format := get_gl_min_format(texture.interp);
    interp_mag_format := get_gl_mag_format(texture.interp);

    glGenTextures(1, *texture.buffer);
    glBindTexture(GL_TEXTURE_3D, texture.buffer);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_S, wrap_formats[0]);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_T, wrap_formats[1]);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_R, wrap_formats[2]);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, interp_min_format);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, interp_mag_format);
    // glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    // glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    // glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_NEAREST_MIPMAP_LINEAR);
    // glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    if texture.wrap[0] == .Border || texture.wrap[1] == .Border || texture.wrap[2] == .Border {
        glTexParameterfv(GL_TEXTURE_3D, GL_TEXTURE_BORDER_COLOR, texture.border_color.component.data);
    }

    eight_divible := (texture.width * texture.height * texture.depth) % 8 == 0;
    four_divisible := (texture.width * texture.height * texture.depth) % 4 == 0;
    two_divisible := (texture.width * texture.height * texture.depth) % 2 == 0;
    pixel_store: s32;
    if eight_divible then pixel_store = 8;
    else if four_divisible then pixel_store = 4;
    else if two_divisible then pixel_store = 2;
    else pixel_store = 1;

    // storage_format := get_gl_format(texture.storage);

    // glPixelStorei(GL_PACK_ALIGNMENT, pixel_store);
    glPixelStorei(GL_PACK_ALIGNMENT, 1);
    if texture.format == .Gray {
        if texture.storage == .U8 {
            glTexImage3D(GL_TEXTURE_3D, 0, GL_R8, xx texture.width, xx texture.height, xx texture.depth, 0, GL_RED, GL_UNSIGNED_BYTE, texture.data);
        } else {
            glTexImage3D(GL_TEXTURE_3D, 0, GL_R32F, xx texture.width, xx texture.height, xx texture.depth, 0, GL_RED, GL_FLOAT, texture.data);
        }
    } else if texture.format == .RG {
        if texture.storage == .U8 {
            glTexImage3D(GL_TEXTURE_3D, 0, GL_RG8, xx texture.width, xx texture.height, xx texture.depth, 0, GL_RG, GL_UNSIGNED_BYTE, texture.data);
        } else {
            glTexImage3D(GL_TEXTURE_3D, 0, GL_RG32F, xx texture.width, xx texture.height, xx texture.depth, 0, GL_RG, GL_FLOAT, texture.data);
        }
    } else if texture.format == .RGB {
        if texture.storage == .U8 {
            glTexImage3D(GL_TEXTURE_3D, 0, GL_RGB8, xx texture.width, xx texture.height, xx texture.depth, 0, GL_RGB, GL_UNSIGNED_BYTE, texture.data);
        } else {
            glTexImage3D(GL_TEXTURE_3D, 0, GL_RGB32F, xx texture.width, xx texture.height, xx texture.depth, 0, GL_RGB, GL_FLOAT, texture.data);
        }
    } else if texture.format == .RGBA {
        if texture.storage == .U8 {
            glTexImage3D(GL_TEXTURE_3D, 0, GL_RGBA8, xx texture.width, xx texture.height, xx texture.depth, 0, GL_RGBA, GL_UNSIGNED_BYTE, texture.data);
        } else {
            glTexImage3D(GL_TEXTURE_3D, 0, GL_RGBA32F, xx texture.width, xx texture.height, xx texture.depth, 0, GL_RGBA, GL_FLOAT, texture.data);
        }
    }
    
    if #complete texture.interp == {
        case .Linear;
        case .LinearMipmap;
            glGenerateMipmap(GL_TEXTURE_3D);
        case .Nearest;
    }
}

unload :: (texture: *Texture3) {
    if texture.buffer {
        glDeleteTextures(1, *texture.buffer);
        texture.buffer = 0;
    }
}

// TODO add method to remove data if you'll never unload

destroy :: (texture: Texture3) {
    stbi_image_free(texture.data);
    // delete data?
    glDeleteTextures(1, *texture.buffer);
}

update_texture :: (texture: *Texture3, image: Image3) {
    assert(texture.width == image.width && texture.height == image.height && texture.depth == image.depth, "Dimensions must match.");
    assert(texture.format == image.format, "Formats must match.");
    
    update_texture(texture, image.data);
}

update_texture :: (texture: *Texture3, bytes: [] u8) {
    // TODO can upload this in parallel of it helps
    stride := get_stride(texture.format) * get_stride(texture.storage);
    depth := bytes.count / stride / (texture.width * texture.height);

    if texture.storage == .U8 {
        glTextureSubImage3D(texture.buffer, 0, 0, 0, 0, xx texture.width, xx texture.height, xx depth, get_gl_format(texture.format), GL_UNSIGNED_BYTE, bytes.data);
    } else {
        glTextureSubImage3D(texture.buffer, 0, 0, 0, 0, xx texture.width, xx texture.height, xx depth, get_gl_format(texture.format), GL_FLOAT, bytes.data);
    }
}

#scope_file

load_data :: (data: [] u8) -> Texture3 {
    texture_data: Texture3;
    comp: s32;
    texture_data.data = stbi_load_from_memory(data.data, xx data.count, *texture_data.width, *texture_data.height, *comp, 0);
    if !texture_data.data {
        print("Could not parse texture data.\n");
        assert(false, "Could not parse texture data.");
        return .{};
    }

    // assert(texture_data.width == texture_data.height * texture_data.height, "Texture3 data loaded from a file can only be a cube.");
    // assert(texture_data.width % texture_data.height == 0, "The texture width must be a multiple of the texture height.");
    assert(texture_data.height % texture_data.width == 0, "The texture height must be a multiple of the texture width.");

    texture_data.depth = texture_data.height / texture_data.width;
    texture_data.height = texture_data.width;
    
    if comp == 1 {
        texture_data.format = .Gray;
    } else if comp == 2 {
        texture_data.format = .RG;
    } else if comp == 3 {
        texture_data.format = .RGB;
    } else if comp == 4 {
        texture_data.format = .RGBA;
    }

    return texture_data;
}

#import "Basic";
#import "File";
