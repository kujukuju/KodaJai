
// TODO the pixel format should be compile time so I can modify the methods for float vs bytef
Image :: struct {
    pixels: [] u8;
    width: int;
    height: int;
    format: PixelFormat;
}

load_image :: (path: string) -> Image {
    data, success := read_entire_file(path, false);
    defer free(data);

    if !success {
        print("Could not load image data. %\n", path);
        return .{};
    }

    bytes: [] u8;
    bytes.data = data.data;
    bytes.count = data.count;
    return create_image(bytes);
}

create_image :: (width: int, height: int, format: PixelFormat) -> Image {
    image: Image;
    image.width = width;
    image.height = height;
    image.format = format;
    
    stride := get_stride(format);
    image.pixels = NewArray(width * height * stride, u8);

    return image;
}

create_image :: (bytes: [] u8, width: int, height: int, format: PixelFormat, reuse_memory: bool = false) -> Image {
    image: Image;
    image.width = width;
    image.height = height;
    image.format = format;

    assert(bytes.count == width * height * get_stride(format), "Incorrect image data.\n");
    if bytes.count != width * height * get_stride(format) {
        return .{};
    }
    
    if reuse_memory {
        image.pixels = bytes;
    } else {
        image.pixels = array_copy(bytes);
    }
    
    return image;
}

create_image :: (bytes: [] u8) -> Image {
    image: Image;
    comp: s32;
    width: s32;
    height: s32;

    // stupid fucking not default allocator shit
    stbi_data := stbi_load_from_memory(bytes.data, xx bytes.count, *width, *height, *comp, 0);
    defer stbi_image_free(stbi_data);

    assert(!!stbi_data, "Could not parse image data.\n");
    if !stbi_data {
        return .{};
    }

    image.pixels = NewArray(width * height * comp, u8);
    memcpy(image.pixels.data, stbi_data, image.pixels.count);
    
    image.width = width;
    image.height = height;
    
    if comp == 1 {
        image.format = .R8;
    } else if comp == 2 {
        image.format = .RG8;
    } else if comp == 3 {
        image.format = .RGB8;
    } else if comp == 4 {
        image.format = .RGBA8;
    }

    return image;
}

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

    return new;
}

create_image :: (texture: Texture) -> Image {
    new: Image;
    new.width = texture.width;
    new.height = texture.height;
    new.format = texture.format;

    gl_format := get_gl_format(texture.format);
    gl_type := get_gl_type(texture.format);
    stride := get_stride(texture.format);
    new.pixels = NewArray(new.width * new.height * stride, u8, false);

    glBindTextureTemporary(GL_TEXTURE_2D, texture.buffer);
    glGetTextureImage(texture.buffer, 0, gl_format, gl_type, xx new.pixels.count, new.pixels.data);

    return new;
}

copy_image :: (image: Image) -> Image {
    new := image;
    new.pixels = array_copy(image.pixels);

    return new;
}

destroy :: (image: Image) {
    array_free(image.pixels);
}

get_png_bytes :: (image: Image) -> [] u8 {
    comp := get_stride(image.format);

    written: [] u8;

    write_func :: (cont: *void, data: *void, size: s32) #c_call {
        empty: Context;
        push_context empty {
            print("%\n", size);
            written := cast(*[] u8) cont;

            allocated := NewArray(size, u8);
            memcpy(allocated.data, data, size);

            << written = allocated;
        }
    }

    print("writing % %\n", image.width, image.height);

    stbi_write_png_to_func(write_func, *written, xx image.width, xx image.height, xx comp, image.pixels.data, xx (image.width * comp));

    return written;
}

save_image :: (image: Image, path: string) {
    // assert(ends_with(path, ".png"), "Your image file must be a png for now.");

    cpath := create_fixed_string(path, 1024);
    comp := get_stride(image.format);

    if ends_with(path, ".png") {
        stbi_write_png(cpath.buffer.data, xx image.width, xx image.height, xx comp, image.pixels.data, xx (image.width * comp));
    } else if ends_with(path, ".tga") {
        stbi_write_tga(cpath.buffer.data, xx image.width, xx image.height, xx comp, image.pixels.data);
    } else {
        assert(false, "Your image file format is not supported.");
    }
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
    if !image.pixels.data || point.x < 0 || point.y < 0 || point.x >= image.width || point.y >= image.height {
        return;
    }

    stride := get_stride(image.format);
    index := (point.y * image.width + point.x) * stride;
    
    if is_float(image.format) {
        assert(image.format == .R32F || image.format == .RG32F || image.format == .RGB32F || image.format == .RGBA32F);

        memcpy(image.pixels.data + index, *color, stride);
    } else {
        assert(image.format == .R8 || image.format == .RG8 || image.format == .RGB8 || image.format == .RGBA8);

        bytes: [4] u8 = ---;
        bytes.data[0] = cast(u8) round(color.r * 255);
        bytes.data[1] = cast(u8) round(color.g * 255);
        bytes.data[2] = cast(u8) round(color.b * 255);
        bytes.data[3] = cast(u8) round(color.a * 255);

        memcpy(image.pixels.data + index, bytes.data, stride);
    }
}

draw_rectangle :: (image: *Image, point: Vector2, size: Vector2, color: Color) {
    draw_rectangle(image, point2(cast(int) point.x, cast(int) point.y), point2(cast(int) size.x, cast(int) size.y), color);
}

draw_rectangle :: (image: *Image, point: Point2, size: Point2, color: Color) {
    if !image.pixels.data {
        return;
    }

    stride := get_stride(image.format);

    start := max(point, .{0, 0});
    end := min(point + size, point2(image.width, image.height));
    for y: start.y..end.y - 1 {
        for x: start.x..end.x - 1 {
            index := (y * image.width + x) * stride;

            bytes: [4] u8;
            bytes.data[0] = cast(u8) round(color.r * 255);
            bytes.data[1] = cast(u8) round(color.g * 255);
            bytes.data[2] = cast(u8) round(color.b * 255);
            bytes.data[3] = cast(u8) round(color.a * 255);

            memcpy(image.pixels.data + index, bytes.data, stride);
        }
    }
}

draw_line :: (image: *Image, p1: Vector2, p2: Vector2, width: float, color: Color) {
    assert(false);
}

draw_line :: (image: *Image, p1: Point2, p2: Point2, width: int, color: Color) {
    assert(false);
}

draw_circle :: (image: *Image, center: Vector2, radius: float, color: Color) {
    assert(false);
}

draw_circle :: (image: *Image, center: Point2, radius: int, color: Color) {
    assert(false);
}

draw_ellipse :: (image: *Image, center: Vector2, size: Vector2, color: Color) {
    assert(false);
}

draw_ellipse :: (image: *Image, center: Point2, size: Point2, color: Color) {
    assert(false);
}

draw_polygon :: (image: *Image, polygon: [] Vector2, color: Color) {
    assert(false);
}

draw_polygon :: (image: *Image, polygon: [] Point2, color: Color) {
    assert(false);
}

get_pixel_raw :: (image: Image, point: Point2) -> Color {
    stride := get_stride(image.format);
    index := image.width * point.y + point.x;

    rgba := image.pixels.data + index * stride;
    return color(rgba[0], rgba[1], rgba[2], rgba[3]);
}

get_pixel :: (image: Image, point: Point2) -> Color {
    x := clamp(point.x, 0, image.width - 1);
    y := clamp(point.y, 0, image.height - 1);

    stride := get_stride(image.format);
    index := image.width * y + x;

    if stride == {
        case 1;
            return color(image.pixels[index * stride], 0, 0, 0);
        case 2;
            return color(image.pixels[index * stride], image.pixels[index * stride + 1], 0, 0);
        case 3;
            return color(image.pixels[index * stride], image.pixels[index * stride + 1], image.pixels[index * stride + 2], 0);
        case 4;
            return color(image.pixels[index * stride], image.pixels[index * stride + 1], image.pixels[index * stride + 2], image.pixels[index * stride + 3]);
        case;
            assert(false, "This stride isn't supported.");
            return .{};
    }
}

get_pixel_interp :: (image: Image, point: Vector2, $wrap: bool = false) -> Color {
    #if wrap {
        x := clamp(point.x % image.width, 0, image.width - 1.0);
        y := clamp(point.y % image.height, 0, image.height - 1.0);
    } else {
        x := clamp(point.x, 0, image.width - 1.0);
        y := clamp(point.y, 0, image.height - 1.0);
    }

    stride := get_stride(image.format);
    index := image.width * y + x;

    left: Color = ---;
    right: Color = ---;
    right_weight: float = ---;
    remaining_x := fmod(point.x, 1.0);
    if remaining_x < 0.5 {
        #if wrap {
            left_point := point2(point);
            left_point.x = (left_point.x + image.width - 1) % image.width;
            left = get_pixel(image, left_point);
        } else {
            left = get_pixel(image, point2(point) - .{1, 0});
        }
        right = get_pixel(image, point2(point));
        right_weight = remaining_x + 0.5;
    } else {
        left = get_pixel(image, point2(point));
        #if wrap {
            right_point := point2(point);
            right_point.x = (right_point.x + 1) % image.width;
            right = get_pixel(image, right_point);
        } else {
            right = get_pixel(image, point2(point) + .{1, 0});
        }
        right_weight = remaining_x - 0.5;
    }

    top: Color = ---;
    bottom: Color = ---;
    bottom_weight: float = ---;
    remaining_y := fmod(point.y, 1.0);
    if remaining_y < 0.5 {
        #if wrap {
            top_point := point2(point);
            top_point.y = (top_point.y + image.height - 1) % image.height;
            top = get_pixel(image, top_point);
        } else {
            top = get_pixel(image, point2(point) - .{0, 1});
        }
        bottom = get_pixel(image, point2(point));
        bottom_weight = remaining_y + 0.5;
    } else {
        top = get_pixel(image, point2(point));
        #if wrap {
            bottom_point := point2(point);
            bottom_point.y = (bottom_point.y + 1) % image.height;
            bottom = get_pixel(image, bottom_point);
        } else {
            bottom = get_pixel(image, point2(point) + .{0, 1});
        }
        bottom_weight = remaining_y - 0.5;
    }

    return left * (1.0 - right_weight) * 0.5 + right * right_weight * 0.5 + top * (1 - bottom_weight) * 0.5 + bottom * bottom_weight * 0.5;
}

draw :: (destination: *Image, source: Image) {
    draw(destination, source, .{0, 0});
    assert(false);
}

draw :: (destination: *Image, source: Image, position: Point2) {
    start := max(position, .{0, 0});
    end := min(point2(destination.width, destination.height), position + point2(source.width, source.height));
    dimensions := end - start;
    source_start := -min(position, .{0, 0});

    if destination.format == source.format {
        stride := get_stride(destination.format);

        for y: 0..dimensions.y - 1 {
            destination_point := point2(start.x, start.y + y);
            source_point := point2(source_start.x, source_start.y + y);

            destination_data := destination.pixels.data + (destination_point.y * destination.width + destination_point.x) * stride;
            source_data := source.pixels.data + (source_point.y * source.width + source_point.x) * stride;

            memcpy(destination_data, source_data, dimensions.x * stride);
        }
    } else {
        assert(destination.format == source.format, "I haven't decided yet how I want to handle this.");
    }




    // dest_color_bytes: [] u8;
    // dest_color_bytes.count = stride;
    // source_color_bytes: [] u8;
    // source_color_bytes.count = stride;

    // for y: 0..dimensions.y - 1 {
    //     for x: 0..dimensions.x - 1 {
    //         point := point2(x, y);
    //         dest_point := start + point;
    //         source_point := source_offset + point;

    //         dest_index := (dest_point.y * destination.width + dest_point.x) * stride;
    //         source_index := (source_point.y * source.width + source_point.x) * stride;

    //         dest_color_bytes.data = destination.pixels.data + dest_index;
    //         source_color_bytes.data = source.pixels.data + source_index;

    //         dest_color := color(dest_color_bytes[0], dest_color_bytes[1], dest_color_bytes[2], dest_color_bytes[3]);
    //         source_color := color(source_color_bytes[0], source_color_bytes[1], source_color_bytes[2], source_color_bytes[3]);
            
    //         // TODO premultiply for easy math I guess
    //         // dest_percent := dest_color.a / (dest_color.a + source_color.a);
    //         // source_percent := source_color.a / (dest_color.a + source_color.a);

    //         dest_color = source_color.a * color(source_color.r, source_color.g, source_color.b, 1.0) + (1.0 - source_color.a) * dest_color; //color(dest_color.r, dest_color.g, dest_color.b, 1.0);
    //         dest_bytes := get_bytes(dest_color);

    //         memcpy(destination.pixels.data + dest_index, dest_bytes.data, stride);
    //     }
    // }
}

draw :: (destination: *Image, source: Image, dest_position: Point2, dest_size: Point2, source_position: Point2, source_size: Point2) {
    assert(false);
}
