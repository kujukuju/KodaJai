Texture :: struct {
    buffer: GLuint;
    width: s32;
    height: s32;
    format: PixelFormat;
}

load_texture :: (path: string) -> Texture {
    file, success := read_entire_file(path, false);
    defer free(file);

    bytes: [] u8;
    bytes.data = file.data;
    bytes.count = file.count;

    return create_texture(bytes);
}

create_texture :: (bytes: [] u8) -> Texture {
    texture_data := load_data(bytes);
    defer stbi_image_free(texture_data.data);

    if texture_data.data == null {
        print("Could not load texture.\n");
        return .{};
    }

    return gen_texture(texture_data);
}

create_texture :: (image: Image) -> Texture {
    if !image.pixels.data {
        print("Could not create texture.\n");
        return .{};
    }

    texture_data: TextureData;
    texture_data.data = image.pixels.data;
    texture_data.width = xx image.width;
    texture_data.height = xx image.height;
    texture_data.format = image.format;

    return gen_texture(texture_data);
}

// TODO update texture more efficiently from image

load_thumbnail_texture :: (path: string, width: s32, height: s32, preserve_ratio: bool = true) -> Texture, bool {
    file, success := read_entire_file(path, false);
    defer free(file);

    bytes: [] u8;
    bytes.data = file.data;
    bytes.count = file.count;

    texture, loaded := load_thumbnail_texture(bytes, width, height, preserve_ratio);
    return texture, loaded;
}

load_thumbnail_texture :: (bytes: [] u8, width: s32, height: s32, preserve_ratio: bool = true) -> Texture, bool {
    texture_data := load_data(bytes);
    defer stbi_image_free(texture_data.data);

    if texture_data.data == null {
        print("Could not load texture.\n");
        return .{}, false;
    }

    thumbnail_texture_data := scale_data(texture_data, width, height, preserve_ratio);
    defer free(thumbnail_texture_data.data);

    return gen_texture(thumbnail_texture_data), true;
}

load_data :: (data: [] u8) -> TextureData {
    texture_data: TextureData;
    comp: s32;
    texture_data.data = stbi_load_from_memory(data.data, xx data.count, *texture_data.width, *texture_data.height, *comp, 0);
    if !texture_data.data {
        print("Could not parse texture data.\n");
        assert(false && "Could not parse texture data.");
        return .{};
    }
    
    if comp == 1 {
        texture_data.format = .Gray;
    } else if comp == 2 {
        texture_data.format = .GrayAlpha;
    } else if comp == 3 {
        texture_data.format = .RGB;
    } else if comp == 4 {
        texture_data.format = .RGBA;
    }

    return texture_data;
}

scale_data :: (data: TextureData, width: s32, height: s32, preserve_ratio: bool = true) -> TextureData {
    byte_count := 0;
    if data.format == {
        case .Gray;
            byte_count = 1;
        case .GrayAlpha;
            byte_count = 2;
        case .RGB;
            byte_count = 3;
        case .RGBA;
            byte_count = 4;
    }

    texture_data: TextureData;
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

gen_texture :: (data: TextureData) -> Texture {
    texture: Texture;
    texture.width = data.width;
    texture.height = data.height;
    // texture.mipmaps = 1;
    texture.format = data.format;

    glGenTextures(1, *texture.buffer);
    glBindTexture(GL_TEXTURE_2D, texture.buffer);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);	
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST_MIPMAP_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    eight_divible :=  (texture.width * texture.height) % 8 == 0;
    four_divisible := (texture.width * texture.height) % 4 == 0;
    two_divisible := (texture.width * texture.height) % 2 == 0;
    pixel_store: s32;
    if eight_divible then pixel_store = 8;
    else if four_divisible then pixel_store = 4;
    else if two_divisible then pixel_store = 2;
    else pixel_store = 1;

    glPixelStorei(GL_PACK_ALIGNMENT, pixel_store);
    if texture.format == .Gray {
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, xx texture.width, xx texture.height, 0, GL_RED, GL_UNSIGNED_BYTE, data.data);
    } else if texture.format == .GrayAlpha {
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RG, xx texture.width, xx texture.height, 0, GL_RG, GL_UNSIGNED_BYTE, data.data);
    } else if texture.format == .RGB {
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, xx texture.width, xx texture.height, 0, GL_RGB, GL_UNSIGNED_BYTE, data.data);
    } else if texture.format == .RGBA {
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, xx texture.width, xx texture.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data.data);
    }
    
    glGenerateMipmap(GL_TEXTURE_2D);

    return texture;
}

free :: (texture: Texture) {
    glDeleteTextures(1, *texture.buffer);
}

destroy_texture :: free;

update_texture :: (texture: *Texture, image: Image) {
    assert(texture.width == image.width && texture.height == image.height, "Dimensions must match.");
    assert(texture.format == image.format, "Formats must match.");
    
    glTextureSubImage2D(texture.buffer, 0, 0, 0, xx texture.width, xx texture.height, get_gl_format(texture.format), GL_UNSIGNED_BYTE, image.pixels.data);
    // glBindBuffer(GL_TEXTURE_BUFFER, texture.buffer);
    // glBindTexture(GL_TEXTURE_BUFFER, buffer.texture);
    // // glTexBuffer(GL_TEXTURE_BUFFER, format, buffer.buffer);
    // glBufferData(GL_TEXTURE_BUFFER, buffer.size, null, GL_DYNAMIC_DRAW);
    // glBufferSubData(GL_TEXTURE_BUFFER, 0, buffer.size, data.data);
}

draw :: (texture: Texture, position: Vector2) {
    static_sprite.texture = texture;
    static_sprite.width = xx texture.width;
    static_sprite.height = xx texture.height;
    static_sprite.position = position;
    static_sprite.rotation = 0;

    draw(static_sprite);
}

draw :: (texture: Texture, position: Vector2, size: Vector2) {
    static_sprite.texture = texture;
    static_sprite.width = size.x;
    static_sprite.height = size.y;
    static_sprite.position = position;
    static_sprite.rotation = 0;

    draw(static_sprite);
}

draw :: (texture: Texture, position: Vector2, rotation: float = 0, scale: Vector2 = .{1, 1}) {
    static_sprite.texture = texture;
    static_sprite.width = texture.width * scale.x;
    static_sprite.height = texture.height * scale.y;
    static_sprite.position = position;
    static_sprite.rotation = rotation;

    draw(static_sprite);
}

#scope_file

TextureData :: struct {
    data: *u8;
    width: s32;
    height: s32;
    format: PixelFormat;
}

#import "Basic";
#import "File";
#import "stb_image";
#import "GL";
