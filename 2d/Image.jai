Image :: struct {
    pixels: [] u8;
    width: int;
    height: int;
    format: PixelFormat;
}

load_image :: (path: string) -> Image {
    data: string;
    success: bool;
    data, success = read_entire_file(path, false);
    defer free(data);

    if !success {
        print("Could not load image data. %\n", path);
        return .{};
    }

    image: Image;
    comp: s32;
    width: s32;
    height: s32;
    image.pixels.data = stbi_load_from_memory(data.data, xx data.count, *width, *height, *comp, 0);
    image.pixels.count = width * height * comp;
    image.width = width;
    image.height = height;
    if !image.pixels.data {
        print("Could not parse image data. %\n", path);
        return .{};
    }
    
    if comp == 1 {
        image.format = .Gray;
    } else if comp == 2 {
        image.format = .GrayAlpha;
    } else if comp == 3 {
        image.format = .RGB;
    } else if comp == 4 {
        image.format = .RGBA;
    }

    return image;
}

// untested
create_image :: (image: Image, position: Point2, size: Point2) -> Image {
    new: Image;
    new.width = size.x;
    new.height = size.y;
    new.format = image.format;

    stride := get_stride(image.format);
    new.pixels = NewArray(new.width * new.height * stride, u8, false);
    
    copy_width := min(new.width, image.width - position.x);
    copy_height := min(new.height, image.height - position.y);
    extra_row_pixels := new.width - copy_width;
    extra_column_pixels := new.height - copy_height;
    copy_bytes := copy_width * stride;

    // if there are extra pixels in the new image we need to initialize the array
    if new.width > copy_width || new.height > copy_height {
        memset(new.pixels.data, 0, new.pixels.count);
    }

    for new_y: 0..size.y - extra_column_pixels - 1 {
        old_y := position.y + new_y;
        old_pointer := image.pixels.data + (old_y * image.width + position.x) * stride;
        new_pointer := new.pixels.data + (new_y * new.width) * stride;

        memcpy(new_pointer, old_pointer, copy_bytes);
    }
}

create_image :: (texture: Texture) -> Image {
    new: Image;
    new.width = texture.width;
    new.height = texture.height;
    new.format = texture.format;

    gl_format := get_gl_format(texture.format);
    stride := get_stride(texture.format);
    new.pixels = NewArray(new.width * new.height * stride, u8, false);

    glGetTextureImage(texture.buffer, 0, gl_format, GL_UNSIGNED_BYTE, new.pixels.count, new.pixels.data);

    return new;
}

destroy_image :: (image: Image) {
    array_free(image.pixels);
}

resize_image :: (image: *Image, size: Point2) {
    old_pixels := image.pixels;
    defer array_free(old_pixels);

    old_width := image.width;
    old_height := image.height;

    image.width = size.x;
    image.height = size.y;
    
    stride := get_stride(image.format);
    image.pixels = NewArray(image.height * image.width * stride, u8, false);

    scale_x := cast(float) old_width / image.width;
    scale_y := cast(float) old_height / image.height;

    for index: 0..image.pixels.count - 1 {
        y := index / image.width;
        x := index % image.width;

        old_x := cast(int) ((x + 0.5) * scale_x);
        old_y := cast(int) ((y + 0.5) * scale_y);
        old_index = old_y * old_width + old_x;

        // memcpy for stride is probably slower right?
        memcpy(image.pixels.data + index, old_pixels.data + old_index, stride);
    }
}

// not tested
resize_image_lock_ratio :: (image: *Image, size: Point2) {
    old_pixels := image.pixels;
    defer array_free(old_pixels);

    old_width := image.width;
    old_height := image.height;

    image.width = size.x;
    image.height = size.y;
    
    stride := get_stride(image.format);
    image.pixels = NewArray(image.height * image.width * stride, u8, false);

    // the number of pixels that are padding for the left, and top
    padding_left: int;
    padding_top: int;
    padded_width: int;
    padded_height: int;

    scale := min(cast(float) width / old_width, cast(float) height / data.height);
    padded_width = cast(int) round(old_width * scale);
    padded_height = cast(int) round(old_height * scale);

    padding_left = (image.width - padded_width) / 2;
    padding_top = (image.height - padded_height) / 2;

    // if there is padding clear the image
    if padding_left > 0 || padding_top > 0 {
        memset(image.pixels.data, 0, image.pixels.count);
    }

    assert(padding_left + padded_width <= image.width && padding_top + padded_height <= image.height, "Resize lock ratio math casting is incorrect.");

    write_count := padded_width * padded_height;
    for index: 0..write_count - 1 {
        y := index / padded_width;
        x := index % padded_width;

        dest_pixel_index := (y + padding_top) * image.width + x + padding_left;
        dest_address := image.pixels.data + dest_pixel_index * stride;
        // TODO remove
        assert(dest_pixel_index * stride + stride <= image.width * image.height * stride, "Resize lock ratio pixel destination is out of bounds.");

        src_x := cast(int) (cast(float) (x + 0.5) / padded_width * old_width);
        src_y := cast(int) (cast(float) (y + 0.5) / padded_height * old_height);
        src_pixel_index := src_y * old_width + src_x;
        src_address := old_pixels.data + src_pixel_index * stride;
        // TODO remove
        assert(src_pixel_index * stride + stride <= old_width * old_height * stride && "Resize lock ratio pixel source is out of bounds.");

        memcpy(dest_address, src_address, stride);
    }
}

crop_image :: (image: *Image, position: Point2, size: Point2) {

}

clear_image :: (image: *Image) {
    memset(image.pixels.data, 0, image.pixels.count);
}

clear_image :: (image: *Image, color: Color) {
    // if I want to optimize I could make this 8 bytes, and memcpy 8 at a time or something
    bytes: [4] u8;
    bytes.data[0] = cast(u8) round(color.r * 255);
    bytes.data[1] = cast(u8) round(color.g * 255);
    bytes.data[2] = cast(u8) round(color.b * 255);
    bytes.data[3] = cast(u8) round(color.a * 255);

    stride := get_stride(image.format);
    pixels := image.width * image.height;
    
    // TODO test speed of memcpy vs writing 4 bytes
    for index: 0..pixels - 1 {
        memcpy(image.pixels.data + index * stride, bytes.data, stride);
    }
}

draw_pixel :: (image: *Image, point: Point2, color: Color) {
    if !image.data || point.x < 0 || point.x >= image.width || point.y < 0 || point.y >= image.height {
        return;
    }

    stride := get_stride(image.format);
    index := (point.y * image.width + point.x) * stride;
    
    bytes: [4] u8;
    bytes.data[0] = cast(u8) round(color.r * 255);
    bytes.data[1] = cast(u8) round(color.g * 255);
    bytes.data[2] = cast(u8) round(color.b * 255);
    bytes.data[3] = cast(u8) round(color.a * 255);

    memcpy(image.pixels.data + index, bytes.data, stride);
}

draw_rectangle :: (image: *Image, point: Vector2, size: Vector2, color: Color) {
    
}

draw_rectangle :: (image: *Image, point: Point2, size: Point2, color: Color) {

}

draw_line :: (image: *Image, p1: Vector2, p2: Vector2, width: float, color: Color) {

}

draw_line :: (image: *Image, p1: Point2, p2: Point2, width: int, color: Color) {

}

draw_circle :: (image: *Image, center: Vector2, radius: float, color: Color) {

}

draw_circle :: (image: *Image, center: Point2, radius: int, color: Color) {

}

draw_ellipse :: (image: *Image, center: Vector2, size: Vector2, color: Color) {

}

draw_ellipse :: (image: *Image, center: Point2, size: Point2, color: Color) {

}

draw_polygon :: (image: *Image, polygon: [] Vector2, color: Color) {

}

draw_polygon :: (image: *Image, polygon: [] Point2, color: Color) {

}

get_pixel :: (image: Image, point: Point2) -> Color {

}

draw :: (destination: *Image, source: Image) {

}

draw :: (destination: *Image, source: Image, position: Point2) {

}

draw :: (destination: *Image, source: Image, dest_position: Point2, dest_size: Point2, source_position: Point2, source_size: Point2) {

}
