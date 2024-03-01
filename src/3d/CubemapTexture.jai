CubemapTexture :: struct {
    buffer: u32;
    width: s32;
    height: s32;
    format: PixelFormat;
    wrap: TextureWrap;
    data: *u8;
}

// create_cubemap_texture :: (bytes: [] [] u8, wrap: TextureWrap = .Clamp, should_upload: bool = true) -> CubemapTexture {

// }

create_cubemap_texture :: (bytes: [] u8, wrap: TextureWrap = .Clamp, should_upload: bool = true) -> CubemapTexture {
    texture := load_data(bytes);
    texture.wrap = wrap;

    if texture.data == null {
        print("Could not load texture.\n");
        return .{};
    }

    if should_upload {
        upload(*texture);
    }

    return texture;
}

// create_cubemap_texture :: (image: Image, wrap: TextureWrap = .Clamp, should_upload: bool = true) -> CubemapTexture {
//     if !image.pixels.data {
//         print("Could not create cubemap texture.\n");
//         return .{};
//     }

//     assert(image.width % 4 == 0, "The width must be divisible by 4 for a cubemap if providing a single image.");
//     assert(image.height % 3 == 0, "The height must be divisible by 3 for a cubemap if providing a single image.");

//     texture: CubemapTexture;
//     texture.data = image.pixels.data;
//     its not this simple
//     texture.width = xx image.width / 4;
//     texture.height = xx image.height / 3;
//     texture.format = image.format;
//     texture.wrap = wrap;

//     if should_upload {
//         upload(*texture);
//     }

//     return texture;
// }

load_cubemap_texture :: (path: string, wrap: TextureWrap = .Clamp, should_upload: bool = true) -> CubemapTexture {
    file, success := read_entire_file(path, false);
    defer free(file);

    bytes: [] u8;
    bytes.data = file.data;
    bytes.count = file.count;

    return create_cubemap_texture(bytes, wrap, should_upload);
}

upload :: (texture: *CubemapTexture) {
    if texture.buffer {
        print("Warning: Trying to upload a cubemap texture that's already uploaded.\n", true);
        return;
    }
    
    assert(!!texture.data, "Cannot generate cubemap texture with no data.");

    wrap_format := get_gl_format(texture.wrap);

    glGenTextures(1, *texture.buffer);
    glBindTexture(GL_TEXTURE_CUBE_MAP, texture.buffer);
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
        glDeleteTextures(1, texture.buffer);
        texture.buffer = 0;
    }
}

destroy :: (texture: CubemapTexture) {
    if texture.data {
        free(texture.data);
    }

    if texture.buffer {
        glDeleteTextures(1, *texture.buffer);
    }
}

#scope_file

load_data :: (data: [] u8) -> CubemapTexture {
    texture: CubemapTexture;
    comp: s32;
    image_data: *u8 = stbi_load_from_memory(data.data, xx data.count, *texture.width, *texture.height, *comp, 0);
    defer stbi_image_free(image_data);
    if !image_data {
        print("Could not parse texture data.\n");
        assert(false, "Could not parse texture data.");
        return .{};
    }
    
    if comp == 1 {
        texture.format = .R8;
    } else if comp == 2 {
        texture.format = .RG8;
    } else if comp == 3 {
        texture.format = .RGB8;
    } else if comp == 4 {
        texture.format = .RGBA8;
    }

    // if this texture is the cross shape thing we'll fix it
    if texture.width / 4 == texture.height / 3 {
        face_width := texture.width / 4;
        face_height := texture.height / 3;
        stride := get_stride(texture.format);

        image_width := texture.width;

        texture.data = alloc(face_width * face_height * stride * 6);
        texture.width = texture.width / 4;
        texture.height = texture.height / 3;

        texture_data_offset := 0;

        faces :: int.[1, 4, 5, 6, 7, 9];

        for face: faces {
            face_index_x := face % 4;
            face_index_y := face / 4;

            for y: 0..face_height - 1 {
                image_pixel_x := face_index_x * face_width;
                image_pixel_y := face_index_y * face_height + y;

                image_row_pointer := image_data + (image_pixel_y * image_width + image_pixel_x) * stride;

                copy_bytes := face_width * stride;
                memcpy(texture.data + texture_data_offset, image_row_pointer, copy_bytes);
                texture_data_offset += copy_bytes;
            }
        }
    } else if texture.width / 6 == texture.height {
        face_width := texture.width / 6;
        face_height := texture.height;
        stride := get_stride(texture.format);

        texture.data = alloc(face_width * face_height * stride * 6);
        texture.width = texture.width / 6;

        // have to alloc and memcpy unfortunately because stbi uses the c allocator and this uses the normal allocator womp womp very stupid
        memcpy(texture.data, image_data, face_width * face_height * stride * 6);
    } else {
        assert(false, "Unknown texture image dimensions. Must either be the cross shape or a strided consecutive memory shape.");
    }

    return texture;
}

#import "Basic";
#import "File";
