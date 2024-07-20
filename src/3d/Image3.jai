
Image3 :: struct {
    pixels: [] u8;
    width: int;
    height: int;
    depth: int;
    format: PixelFormat;
}

load_image3 :: (path: string) -> Image3 {
    data, success := read_entire_file(path, false);
    defer free(data);

    if !success {
        print("Could not load image data. %\n", path);
        return .{};
    }

    bytes: [] u8;
    bytes.data = data.data;
    bytes.count = data.count;
    return create_image3(bytes);
}

create_image3 :: (width: int, height: int, depth: int, format: PixelFormat) -> Image3 {
    image: Image3;
    image.width = width;
    image.height = height;
    image.depth = depth;
    image.format = format;
    
    stride := get_stride(format);
    image.pixels = NewArray(width * height * depth * stride, u8);

    return image;
}

create_image3 :: (bytes: [] u8, width: int, height: int, depth: int, format: PixelFormat) -> Image3 {
    image: Image3;
    image.width = width;
    image.height = height;
    image.depth = depth;
    image.format = format;

    assert(bytes.count == width * height * depth * get_stride(format), "Incorrect image data.\n");
    image.pixels = array_copy(bytes);
    
    return image;


    image: Image3;
    image.width = width;
    image.height = height;
    image.depth = depth;
    image.format = format;
    
    stride := get_stride(format);
    image.pixels = NewArray(width * height * depth * stride, u8);

    return image;
}

create_image3 :: (bytes: [] u8, width: int, height: int, depth: int, format: PixelFormat, reuse_memory: bool = false) -> Image3 {
    image: Image3;
    image.width = width;
    image.height = height;
    image.depth = depth;
    image.format = format;

    assert(bytes.count == width * height * depth * get_stride(format), "Incorrect image data.\n");
    if bytes.count != width * height * depth * get_stride(format) {
        return .{};
    }

    if reuse_memory {
        image.pixels = bytes;
    } else {
        image.pixels = array_copy(bytes);
    }
    
    return image;
}

create_image3 :: (bytes: [] u8) -> Image3 {
    image := create_image(bytes);

    assert(image.height % image.width == 0, "Image3 height must be a multiple of the width.");
    if image.height % image.width != 0 {
        destroy(image);
        return .{};
    }
    
    image3: Image3;
    image3.width = image.width;
    image3.height = image.width;
    image3.depth = image.height / image.width;
    image3.format = image.format;
    image3.pixels = image.pixels;

    return image3;
}

destroy :: (image: Image3) {
    array_free(image.pixels);
}

save_image :: (image: Image3, path: string) {
    assert(ends_with(path, ".png"), "Your image file must be a png for now.");

    cpath := create_fixed_string(path, 1024);
    comp := get_stride(image.format);

    print("Saving image as stride %.\n", comp);

    stbi_write_png(cpath.buffer.data, xx image.width, xx (image.height * image.depth), xx comp, image.pixels.data, xx (image.width * comp));
}

clear_image :: (image: *Image3) {
    memset(image.pixels.data, 0, image.pixels.count);
}

clear_image :: (image: *Image3, color: Color) {
    // if I want to optimize I could make this 8 bytes, and memcpy 8 at a time or something
    bytes: [4] u8;
    bytes.data[0] = cast(u8) round(color.r * 255);
    bytes.data[1] = cast(u8) round(color.g * 255);
    bytes.data[2] = cast(u8) round(color.b * 255);
    bytes.data[3] = cast(u8) round(color.a * 255);

    stride := get_stride(image.format);
    pixels := image.width * image.height * image.depth;
    
    // TODO test speed of memcpy vs writing 4 bytes
    for index: 0..pixels - 1 {
        memcpy(image.pixels.data + index * stride, bytes.data, stride);
    }
}

convert_format :: (image: *Image3, desired_format: PixelFormat) {
    assert(image.format == .R8 || image.format == .RG8 || image.format == .RGB8 || image.format == .RGBA8, tprint("Cannot convert from format of %.\n", image.format));
    assert(desired_format == .R8 || desired_format == .RG8 || desired_format == .RGB8 || desired_format == .RGBA8, tprint("Cannot convert to format of %.\n", desired_format));

    if image.format == desired_format {
        return;
    }

    image_stride := get_stride(image.format);
    desired_stride := get_stride(desired_format);

    image.format = desired_format;

    total_pixels := image.width * image.height * image.depth;

    if desired_stride < image_stride {
        for i: 0..total_pixels - 1 {
            image_index := i * image_stride;
            desired_index := i * desired_stride;

            memcpy(image.pixels.data + desired_index, image.pixels.data + image_index, desired_stride);
        }

        image.pixels.count = total_pixels * desired_stride;
    } else {
        // untested
        old_pixels := image.pixels;
        defer array_free(old_pixels);

        image.pixels = NewArray(total_pixels * desired_stride, u8);

        for i: 0..total_pixels - 1 {
            image_index := i * image_stride;
            desired_index := i * desired_stride;

            memcpy(image.pixels.data + desired_index, old_pixels.data + image_index, image_stride);
        }
    }
}

blur :: (image: *Image3, radius: float) {
    assert(image.format == .R8);

    copied := array_copy(image.pixels);
    defer array_free(copied);

    radius_ceil := cast(int) ceil(radius);

    parallel_for(0, image.depth, (z: int, thread: int, using data: struct {
            image: *Image3;
            copied: [] u8;
            radius_ceil: int;
            radius: float;}) {

        for y: 0..image.height - 1 {
            for x: 0..image.width - 1 {
                image_index := x + y * image.width + z * image.width * image.height;

                accumulated_value := 0.0;
                accumulated_weight := 0.0;

                for z_off: -radius_ceil..radius_ceil {
                    for y_off: -radius_ceil..radius_ceil {
                        for x_off: -radius_ceil..radius_ceil {
                            sample_index := ((x + x_off + image.width) % image.width) + ((y + y_off + image.height) % image.height) * image.width + ((z + z_off + image.depth) % image.depth) * image.width * image.height;

                            distance := sqrt(cast(float) x_off * x_off + cast(float) y_off * y_off + cast(float) z_off * z_off);
                            distance_progress := min(distance / radius, 1);

                            weight := (exp(-distance_progress * 2.0) - exp(-2.0)) / (1.0 - exp(-2.0));

                            sampled_value := copied[sample_index];
                            accumulated_value += sampled_value * weight;
                            accumulated_weight += weight;
                        }
                    }
                }

                image.pixels[image_index] = cast(u8) clamp(round(accumulated_value / accumulated_weight), 0, 255);
            }
        }
    }, .{image, copied, radius_ceil, radius});
}

normalize :: (image: *Image3) {
    assert(image.format == .R8);

    min_value := 255.0;
    max_value := 0.0;

    for z: 0..image.depth - 1 {
        for y: 0..image.height - 1 {
            for x: 0..image.width - 1 {
                index := x + y * image.width + z * image.width * image.height;

                value := image.pixels[index];
                min_value = min(min_value, cast(float) value);
                max_value = max(max_value, cast(float) value);
            }
        }
    }

    for z: 0..image.depth - 1 {
        for y: 0..image.height - 1 {
            for x: 0..image.width - 1 {
                index := x + y * image.width + z * image.width * image.height;

                value := cast(float) image.pixels[index];
                value = (value - min_value) / (max_value - min_value);
                value = min(clamp(value, 0, 1) * 256, 255);

                image.pixels[index] = cast(u8) value;
            }
        }
    }
}
