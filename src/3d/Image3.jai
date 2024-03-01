Image3 :: struct {
    pixels: [] u8;
    width: int;
    height: int;
    depth: int;
    format: PixelFormat;
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
