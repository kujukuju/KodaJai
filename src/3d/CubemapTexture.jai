CubemapTexture :: struct {
    buffer: u32;
    width: s32;
    height: s32;
    format: PixelFormat;
    wrap: TextureWrap;
    data: *u8;
}

create_cubemap_image :: (image: Image) -> Image {
    cubemap: Image;

    // if this texture is the cross shape thing we'll fix it
    if image.width / 4 == image.height / 3 {
        face_width := image.width / 4;
        face_height := image.height / 3;
        stride := get_stride(image.format);

        image_width := image.width;

        cubemap.pixels = NewArray(face_width * face_height * stride * 6, u8);
        cubemap.width = face_width;
        cubemap.height = face_height * 6;
        cubemap.format = image.format;

        texture_data_offset := 0;

        faces :: int.[1, 4, 5, 6, 7, 9];

        for face: faces {
            face_index_x := face % 4;
            face_index_y := face / 4;

            for y: 0..face_height - 1 {
                image_pixel_x := face_index_x * face_width;
                image_pixel_y := face_index_y * face_height + y;

                image_row_pointer := image.pixels.data + (image_pixel_y * image_width + image_pixel_x) * stride;

                copy_bytes := face_width * stride;
                memcpy(cubemap.pixels.data + texture_data_offset, image_row_pointer, copy_bytes);
                texture_data_offset += copy_bytes;
            }
        }
    } else if image.width * 6 == image.height {
        cubemap.pixels = array_copy(image.pixels);
        cubemap.width = image.width;
        cubemap.height = image.height;
        cubemap.format = image.format;
    } else {
        assert(false, "Unknown texture image dimensions. Must either be the cross shape or a strided consecutive memory shape.");
    }

    return cubemap;
}

load_cubemap_texture :: (path: string, wrap: TextureWrap = .Clamp, should_upload: bool = true) -> CubemapTexture {
    return create_cubemap_texture(load_image(path), wrap, should_upload);
}

create_cubemap_texture :: (image: Image, wrap: TextureWrap = .Clamp, should_upload: bool = true) -> CubemapTexture {
    if !image.pixels.data {
        print("Could not create cubemap texture.\n");
        return .{};
    }

    assert(image.width * 6 == image.height, "Invalid cubemap texture dimensions. It must be contiguous memory. You should probably call create_cubemap_image first.\n");
    if image.width * 6 != image.height {
        return .{};
    }

    texture: CubemapTexture;
    texture.width = cast(s32) image.width;
    texture.height = cast(s32) image.height / 6;
    texture.data = image.pixels.data;
    texture.format = image.format;
    texture.wrap = wrap;

    if should_upload {
        upload(*texture);
    }

    return texture;
}

upload :: (texture: *CubemapTexture) {
    if texture.buffer {
        print("Warning: Trying to upload a cubemap texture that's already uploaded.\n", true);
        return;
    }
    
    assert(!!texture.data, "Cannot generate cubemap texture with no data.");

    wrap_format := get_gl_format(texture.wrap);

    glGenTextures(1, *texture.buffer);
    glBindTextureTemporary(GL_TEXTURE_CUBE_MAP, texture.buffer);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, wrap_format);	
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, wrap_format);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, wrap_format);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    eight_divible := (texture.width * texture.height) % 8 == 0;
    four_divisible := (texture.width * texture.height) % 4 == 0;
    two_divisible := (texture.width * texture.height) % 2 == 0;
    pixel_store: s32;
    if eight_divible then pixel_store = 8;
    else if four_divisible then pixel_store = 4;
    else if two_divisible then pixel_store = 2;
    else pixel_store = 1;

    face_enums :: u32.[
        GL_TEXTURE_CUBE_MAP_POSITIVE_Y,
        GL_TEXTURE_CUBE_MAP_NEGATIVE_X,
        GL_TEXTURE_CUBE_MAP_POSITIVE_Z,
        GL_TEXTURE_CUBE_MAP_POSITIVE_X,
        GL_TEXTURE_CUBE_MAP_NEGATIVE_Z,
        GL_TEXTURE_CUBE_MAP_NEGATIVE_Y,
    ];

    gl_format := get_gl_format(texture.format);
    gl_internal_format := get_gl_internal_format(texture.format);
    gl_type := get_gl_type(texture.format);

    stride := get_stride(texture.format);
    face_stride := texture.width * texture.height * stride;

    for face_enum, face_index: face_enums {
        face_pixels: [] u8;
        face_pixels.data = texture.data + face_stride * face_index;
        face_pixels.count = face_stride;

        glPixelStorei(GL_PACK_ALIGNMENT, pixel_store);
        if texture.format == .R8 {
            glTexImage2D(face_enum, 0, gl_internal_format, xx texture.width, xx texture.height, 0, gl_format, gl_type, face_pixels.data);
        } else if texture.format == .RG8 {
            glTexImage2D(face_enum, 0, gl_internal_format, xx texture.width, xx texture.height, 0, gl_format, gl_type, face_pixels.data);
        } else if texture.format == .RGB8 {
            glTexImage2D(face_enum, 0, gl_internal_format, xx texture.width, xx texture.height, 0, gl_format, gl_type, face_pixels.data);
        } else if texture.format == .RGBA8 {
            glTexImage2D(face_enum, 0, gl_internal_format, xx texture.width, xx texture.height, 0, gl_format, gl_type, face_pixels.data);
        }
    }
}

unload :: (texture: *CubemapTexture) {
    if texture.buffer {
        release_texture_slot(texture.buffer);
        glDeleteTextures(1, *texture.buffer);
        texture.buffer = 0;
    }
}

destroy :: (texture: CubemapTexture) {
    if texture.data {
        free(texture.data);
    }

    if texture.buffer {
        release_texture_slot(texture.buffer);
        glDeleteTextures(1, *texture.buffer);
    }
}

get_bytes :: (texture: CubemapTexture) -> int {
    return texture.width * texture.height * 6 * get_stride(texture.format);
}
