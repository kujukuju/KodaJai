Texture3 :: struct {
    buffer: u32;
    width: s32;
    height: s32;
    depth: s32;
    format: PixelFormat;
}

load_texture3 :: (path: string) -> Texture3 {
    file, success := read_entire_file(path, false);
    defer free(file);

    bytes: [] u8;
    bytes.data = file.data;
    bytes.count = file.count;

    return create_texture3(bytes);
}

create_texture3 :: (bytes: [] u8) -> Texture3 {
    texture_data := load_data(bytes);
    defer stbi_image_free(texture_data.data);

    if texture_data.data == null {
        print("Could not load texture.\n");
        return .{};
    }

    return gen_texture(texture_data);
}

create_texture3 :: (image: Image3) -> Texture3 {
    if !image.pixels.data {
        print("Could not create texture.\n");
        return .{};
    }

    texture_data: TextureData3;
    texture_data.data = image.pixels.data;
    texture_data.width = xx image.width;
    texture_data.height = xx image.height;
    texture_data.depth = xx image.depth;
    texture_data.format = image.format;

    return gen_texture(texture_data);
}

destroy :: (texture: Texture3) {
    glDeleteTextures(1, *texture.buffer);
}

gen_texture :: (data: TextureData3) -> Texture3 {
    // TODO mipmaps fuck up this code with non power of 2s
    texture: Texture3;
    texture.width = data.width;
    texture.height = data.height;
    texture.depth = data.depth;
    // texture.mipmaps = 1;
    texture.format = data.format;

    glGenTextures(1, *texture.buffer);
    glBindTexture(GL_TEXTURE_3D, texture.buffer);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_R, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    // glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_NEAREST_MIPMAP_LINEAR);
    // glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    eight_divible := (texture.width * texture.height * texture.depth) % 8 == 0;
    four_divisible := (texture.width * texture.height * texture.depth) % 4 == 0;
    two_divisible := (texture.width * texture.height * texture.depth) % 2 == 0;
    pixel_store: s32;
    if eight_divible then pixel_store = 8;
    else if four_divisible then pixel_store = 4;
    else if two_divisible then pixel_store = 2;
    else pixel_store = 1;

    glPixelStorei(GL_PACK_ALIGNMENT, pixel_store);
    if texture.format == .Gray {
        glTexImage3D(GL_TEXTURE_3D, 0, GL_R8, xx texture.width, xx texture.height, xx texture.depth, 0, GL_RED, GL_UNSIGNED_BYTE, data.data);
    } else if texture.format == .RG {
        glTexImage3D(GL_TEXTURE_3D, 0, GL_RG8, xx texture.width, xx texture.height, xx texture.depth, 0, GL_RG, GL_UNSIGNED_BYTE, data.data);
    } else if texture.format == .RGB {
        glTexImage3D(GL_TEXTURE_3D, 0, GL_RGB8, xx texture.width, xx texture.height, xx texture.depth, 0, GL_RGB, GL_UNSIGNED_BYTE, data.data);
    } else if texture.format == .RGBA {
        glTexImage3D(GL_TEXTURE_3D, 0, GL_RGBA8, xx texture.width, xx texture.height, xx texture.depth, 0, GL_RGBA, GL_UNSIGNED_BYTE, data.data);
    }
    
    glGenerateMipmap(GL_TEXTURE_3D);

    return texture;
}

update_texture :: (texture: *Texture3, image: Image3) {
    assert(false, "Not yet supported. Who even uses texture3...");
    // assert(texture.width == image.width && texture.height == image.height, "Dimensions must match.");
    // assert(texture.format == image.format, "Formats must match.");
    
    // glTextureSubImage2D(texture.buffer, 0, 0, 0, xx texture.width, xx texture.height, get_gl_format(texture.format), GL_UNSIGNED_BYTE, image.pixels.data);
}

#scope_file

TextureData3 :: struct {
    data: *u8;
    width: s32;
    height: s32;
    depth: s32;
    format: PixelFormat;
}

load_data :: (data: [] u8) -> TextureData3 {
    texture_data: TextureData3;
    comp: s32;
    texture_data.data = stbi_load_from_memory(data.data, xx data.count, *texture_data.width, *texture_data.height, *comp, 0);
    if !texture_data.data {
        print("Could not parse texture data.\n");
        assert(false, "Could not parse texture data.");
        return .{};
    }

    assert(texture_data.width == texture_data.height * texture_data.height, "Texture3 data loaded from a file can only be a cube.");

    texture_data.width = texture_data.height;
    texture_data.depth = texture_data.height;
    
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
#import "stb_image";
