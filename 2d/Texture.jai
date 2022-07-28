Texture :: struct {
    texture: GLuint;
    width: s32;
    height: s32;
    // mipmaps: s32;
    format: PixelFormat;
}

TextureData :: struct {
    data: *u8;
    width: s32;
    height: s32;
    format: PixelFormat;
}

// not sure how to use this if its defined here because I import this library into a namespace
// operator == :: (a: Texture, b: Texture) -> bool {
//     return a.texture == b.texture && a.width == b.width && a.height == b.height && a.format == b.format;
// }

load_texture :: (path: string) -> Texture, bool {
    file, success := read_entire_file(path, false);
    defer free(file);

    bytes: [] u8;
    bytes.data = file.data;
    bytes.count = file.count;

    texture, loaded := load_texture(bytes);
    return texture, loaded;
}

load_texture :: (bytes: [] u8) -> Texture, bool {
    texture_data := load_data(bytes);
    defer stbi_image_free(texture_data.data);

    if texture_data.data == null {
        print("Could not load texture.\n");
        return .{}, false;
    }

    return gen_texture(texture_data), true;
}

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

    glGenTextures(1, *texture.texture);
    glBindTexture(GL_TEXTURE_2D, texture.texture);
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
    glDeleteTextures(1, *texture.texture);
}

draw_texture :: (texture: Texture, position: Vector2, rotation: float = 0, scale: Vector2 = .{1, 1}) {
    koda.static_sprite_.texture = texture;
    koda.static_sprite_.width = texture.width * scale.x;
    koda.static_sprite_.height = texture.height * scale.y;
    koda.static_sprite_.position = position;
    koda.static_sprite_.rotation = rotation;

    draw_sprite(koda.static_sprite_);
}

#scope_file

#import "Basic";
#import "File";
#import "stb_image";
#import "GL";
