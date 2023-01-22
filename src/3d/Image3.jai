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

    stbi_write_png(cpath.buffer.data, xx (image.width * image.depth), xx (image.height * image.depth), xx comp, image.pixels.data, xx (image.width * image.depth * comp));
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
