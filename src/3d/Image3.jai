
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

create_image3 :: (images: [] Image) -> Image3 {
    if images.count == 0 {
        return .{};
    }

    width := images[0].width;
    height := images[0].height;
    format := images[0].format;

    for i: 1..images.count - 1 {
        assert(images[i].width == width, "Provided images to image3 without consistent widths. % % %\n", i, images[i].width, width);
        assert(images[i].height == height, "Provided images to image3 without consistent heights. % % %\n", i, images[i].height, height);
        assert(images[i].format == format, "Provided images to image3 without consistent formats. % % %\n", i, images[i].format, format);
    }

    image := create_image3(width, height, images.count, format);
    image_stride := width * height * get_stride(format);
    for i: 0..images.count - 1 {
        memcpy(image.pixels.data + image_stride * i, images[i].pixels.data, image_stride);
    }

    return image;
}

create_image3 :: (image: Image3) -> Image3 {
    copy := image;
    copy.pixels = array_copy(image.pixels);

    return copy;
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

draw_pixel :: (image: *Image3, point: Point3, color: Color) {
    if !image.pixels.data || point.x < 0 || point.y < 0 || point.z < 0 || point.x >= image.width || point.y >= image.height || point.z >= image.depth {
        return;
    }

    stride := get_stride(image.format);
    index := (point.x + point.y * image.width + point.z * image.width * image.height) * stride;

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

convert_format :: (image: *$T, desired_format: PixelFormat, $channels: ColorChannels) {
    assert(
        image.format == .R8 ||
        image.format == .R32F ||
        image.format == .RG8 ||
        image.format == .RG32F ||
        image.format == .RGB8 ||
        image.format == .RGB32F ||
        image.format == .RGBA8 ||
        image.format == .RGBA32F, "Cannot convert from format of %.\n", image.format);
    assert(
        desired_format == .R8 ||
        desired_format == .R32F ||
        desired_format == .RG8 ||
        desired_format == .RG32F ||
        desired_format == .RGB8 ||
        desired_format == .RGB32F ||
        desired_format == .RGBA8 ||
        desired_format == .RGBA32F, "Cannot convert to format of %.\n", desired_format);

    if image.format == desired_format {
        return;
    }

    image_stride := get_stride(image.format);
    desired_stride := get_stride(desired_format);

    channel_count := 0;
    ifx channels & .R then channel_count += 1;
    ifx channels & .G then channel_count += 1;
    ifx channels & .B then channel_count += 1;
    ifx channels & .A then channel_count += 1;
    maximum_channel := 0;
    ifx channels & .R then maximum_channel = 1;
    ifx channels & .G then maximum_channel = 2;
    ifx channels & .B then maximum_channel = 3;
    ifx channels & .A then maximum_channel = 4;

    convert_pixels :: (new_pixels: [] u8, new_stride: int, new_component_count: int, old_pixels: [] u8, old_stride: int, old_component_count: int, $convert: #type (write: *u8, read: *u8)) {
        pixel_count := old_pixels.count / old_stride;
        new_component_stride := new_stride / new_component_count;
        old_component_stride := old_stride / old_component_count;
        for i: 0..pixel_count - 1 {
            #if #complete channels == {
                case .R;
                    convert(new_pixels.data + i * new_stride + 0 * new_component_stride, old_pixels.data + i * old_stride + 0 * old_component_stride);
                case .G;
                    convert(new_pixels.data + i * new_stride + 0 * new_component_stride, old_pixels.data + i * old_stride + 1 * old_component_stride);
                case .B;
                    convert(new_pixels.data + i * new_stride + 0 * new_component_stride, old_pixels.data + i * old_stride + 2 * old_component_stride);
                case .A;
                    convert(new_pixels.data + i * new_stride + 0 * new_component_stride, old_pixels.data + i * old_stride + 3 * old_component_stride);
                case .RG;
                    convert(new_pixels.data + i * new_stride + 0 * new_component_stride, old_pixels.data + i * old_stride + 0 * old_component_stride);
                    convert(new_pixels.data + i * new_stride + 1 * new_component_stride, old_pixels.data + i * old_stride + 1 * old_component_stride);
                case .RB;
                    convert(new_pixels.data + i * new_stride + 0 * new_component_stride, old_pixels.data + i * old_stride + 0 * old_component_stride);
                    convert(new_pixels.data + i * new_stride + 1 * new_component_stride, old_pixels.data + i * old_stride + 2 * old_component_stride);
                case .RA;
                    convert(new_pixels.data + i * new_stride + 0 * new_component_stride, old_pixels.data + i * old_stride + 0 * old_component_stride);
                    convert(new_pixels.data + i * new_stride + 1 * new_component_stride, old_pixels.data + i * old_stride + 3 * old_component_stride);
                case .GB;
                    convert(new_pixels.data + i * new_stride + 0 * new_component_stride, old_pixels.data + i * old_stride + 1 * old_component_stride);
                    convert(new_pixels.data + i * new_stride + 1 * new_component_stride, old_pixels.data + i * old_stride + 2 * old_component_stride);
                case .GA;
                    convert(new_pixels.data + i * new_stride + 0 * new_component_stride, old_pixels.data + i * old_stride + 1 * old_component_stride);
                    convert(new_pixels.data + i * new_stride + 1 * new_component_stride, old_pixels.data + i * old_stride + 3 * old_component_stride);
                case .BA;
                    convert(new_pixels.data + i * new_stride + 0 * new_component_stride, old_pixels.data + i * old_stride + 2 * old_component_stride);
                    convert(new_pixels.data + i * new_stride + 1 * new_component_stride, old_pixels.data + i * old_stride + 3 * old_component_stride);
                case .RGB;
                    convert(new_pixels.data + i * new_stride + 0 * new_component_stride, old_pixels.data + i * old_stride + 0 * old_component_stride);
                    convert(new_pixels.data + i * new_stride + 1 * new_component_stride, old_pixels.data + i * old_stride + 1 * old_component_stride);
                    convert(new_pixels.data + i * new_stride + 2 * new_component_stride, old_pixels.data + i * old_stride + 2 * old_component_stride);
                case .RGA;
                    convert(new_pixels.data + i * new_stride + 0 * new_component_stride, old_pixels.data + i * old_stride + 0 * old_component_stride);
                    convert(new_pixels.data + i * new_stride + 1 * new_component_stride, old_pixels.data + i * old_stride + 1 * old_component_stride);
                    convert(new_pixels.data + i * new_stride + 2 * new_component_stride, old_pixels.data + i * old_stride + 3 * old_component_stride);
                case .RBA;
                    convert(new_pixels.data + i * new_stride + 0 * new_component_stride, old_pixels.data + i * old_stride + 0 * old_component_stride);
                    convert(new_pixels.data + i * new_stride + 1 * new_component_stride, old_pixels.data + i * old_stride + 2 * old_component_stride);
                    convert(new_pixels.data + i * new_stride + 2 * new_component_stride, old_pixels.data + i * old_stride + 3 * old_component_stride);
                case .GBA;
                    convert(new_pixels.data + i * new_stride + 0 * new_component_stride, old_pixels.data + i * old_stride + 1 * old_component_stride);
                    convert(new_pixels.data + i * new_stride + 1 * new_component_stride, old_pixels.data + i * old_stride + 2 * old_component_stride);
                    convert(new_pixels.data + i * new_stride + 2 * new_component_stride, old_pixels.data + i * old_stride + 3 * old_component_stride);
                case .RGBA;
                    convert(new_pixels.data + i * new_stride + 0 * new_component_stride, old_pixels.data + i * old_stride + 0 * old_component_stride);
                    convert(new_pixels.data + i * new_stride + 1 * new_component_stride, old_pixels.data + i * old_stride + 1 * old_component_stride);
                    convert(new_pixels.data + i * new_stride + 2 * new_component_stride, old_pixels.data + i * old_stride + 2 * old_component_stride);
                    convert(new_pixels.data + i * new_stride + 3 * new_component_stride, old_pixels.data + i * old_stride + 3 * old_component_stride);
            }
        }
    }

    // TODO this could be optimized by looking for contiguous color channel conversions and memcpying instead of doing it this way

    pixel_count := image.pixels.count / image_stride;
    desired_component_count := get_component_count(desired_format);
    image_component_count := get_component_count(image.format);

    if desired_stride < image_stride {
        assert(desired_stride == channel_count, "Converting format to fewer channels but didn't provide the correct channel info. % %\n", channels, desired_stride);
        assert(maximum_channel <= image_stride, "The conversion channels is out of bounds for the provided source image. % %\n", channels, image_stride);

        if get_gl_type(image.format) == GL_UNSIGNED_BYTE && get_gl_type(desired_format) == GL_UNSIGNED_BYTE {
            convert_pixels(image.pixels, desired_stride, desired_component_count, image.pixels, image_stride, image_component_count, (write: *u8, read: *u8) {
                write.* = read.*;
            });
        } else if get_gl_type(image.format) == GL_FLOAT && get_gl_type(desired_format) == GL_FLOAT {
            convert_pixels(image.pixels, desired_stride, desired_component_count, image.pixels, image_stride, image_component_count, (write: *u8, read: *u8) {
                (cast(*float) write).* = (cast(*float) read).*;
            });
        } else if get_gl_type(image.format) == GL_UNSIGNED_BYTE && get_gl_type(desired_format) == GL_FLOAT {
            convert_pixels(image.pixels, desired_stride, desired_component_count, image.pixels, image_stride, image_component_count, (write: *u8, read: *u8) {
                // is this * 256, floor, and clamp to 255...?
                write.* = cast(u8) clamp(round(((cast(*float) read).*) * 255), 0, 255);
            });
        } else if get_gl_type(image.format) == GL_FLOAT && get_gl_type(desired_format) == GL_UNSIGNED_BYTE {
            convert_pixels(image.pixels, desired_stride, desired_component_count, image.pixels, image_stride, image_component_count, (write: *u8, read: *u8) {
                (cast(*float) write).* = read.* / 255.0;
            });
        } else {
            assert(false, "Unknown conversion types. % %\n", image.format, desired_format);
        }

        image.pixels.count = pixel_count * desired_stride;
    } else if desired_stride > image_stride {
        assert(image_stride == channel_count, "Converting format to more channels but didn't provide the correct channel info. % %\n", channels, image_stride);
        assert(maximum_channel <= desired_stride, "The conversion channels is out of bounds for the provided destination image. % %\n", channels, desired_stride);

        old_pixels := image.pixels;
        defer array_free(old_pixels);

        image.pixels = NewArray(pixel_count * desired_stride, u8);

        if get_gl_type(image.format) == GL_UNSIGNED_BYTE && get_gl_type(desired_format) == GL_UNSIGNED_BYTE {
            convert_pixels(image.pixels, desired_stride, desired_component_count, old_pixels, image_stride, image_component_count, (write: *u8, read: *u8) {
                write.* = read.*;
            });
        } else if get_gl_type(image.format) == GL_FLOAT && get_gl_type(desired_format) == GL_FLOAT {
            convert_pixels(image.pixels, desired_stride, desired_component_count, old_pixels, image_stride, image_component_count, (write: *u8, read: *u8) {
                write.* = read.*;
            });
        } else if get_gl_type(image.format) == GL_UNSIGNED_BYTE && get_gl_type(desired_format) == GL_FLOAT {
            convert_pixels(image.pixels, desired_stride, desired_component_count, old_pixels, image_stride, image_component_count, (write: *u8, read: *u8) {
                // is this * 256, floor, and clamp to 255...?
                write.* = cast(u8) clamp(round(((cast(*float) read).*) * 255), 0, 255);
            });
        } else if get_gl_type(image.format) == GL_FLOAT && get_gl_type(desired_format) == GL_UNSIGNED_BYTE {
            convert_pixels(image.pixels, desired_stride, desired_component_count, old_pixels, image_stride, image_component_count, (write: *u8, read: *u8) {
                // is this * 256, floor, and clamp to 255...?
                (cast(*float) write).* = read.* / 255.0;
            });
        } else {
            assert(false, "Unknown conversion types. % %\n", image.format, desired_format);
        }

        image.pixels.count = pixel_count * desired_stride;
    } else {
        assert(false, "Don't understand what's happening with the channel conversion... % %\n", image.format, desired_format);
    }

    image.format = desired_format;
}

make_opaque :: (image: *$T) {
    assert(image.format == .RGBA8);

    bytes: [] u8;
    bytes.data = xx image.pixels.data;
    bytes.count = image.pixels.count;

    for i: 0..bytes.count / 4 - 1 {
        bytes[i * 4 + 3] = 255;
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

normalize :: (image: Image3) {
    assert(
        image.format == .R8 ||
        image.format == .R32F ||
        image.format == .RG8 ||
        image.format == .RG32F ||
        image.format == .RGB8 ||
        image.format == .RGB32F ||
        image.format == .RGBA8 ||
        image.format == .RGBA32F);

    min_value := FLOAT32_MAX;
    max_value := 0.0;

    if get_gl_type(image.format) == GL_UNSIGNED_BYTE {
        bytes: [] u8;
        bytes.data = xx image.pixels.data;
        bytes.count = image.pixels.count;

        for byte: bytes {
            min_value = min(min_value, cast(float) byte);
            max_value = max(max_value, cast(float) byte);
        }

        for *byte: bytes {
            value := (byte.* - min_value) / (max_value - min_value);
            byte.* = cast(u8) clamp(floor(value / 256.0), 0, 255);
        }
    } else if get_gl_type(image.format) == GL_FLOAT {
        floats: [] float;
        floats.data = xx image.pixels.data;
        floats.count = image.pixels.count / size_of(float);

        for f: floats {
            min_value = min(min_value, f);
            max_value = max(max_value, f);
        }

        for *f: floats {
            f.* = (f.* - min_value) / (max_value - min_value);
        }
    } else {
        assert(false, "Unknown normalize type. %\n", image.format);
    }
}

get_pixel :: (image: Image3, point: Point3) -> Color {
    x := clamp(point.x, 0, image.width - 1);
    y := clamp(point.y, 0, image.height - 1);
    z := clamp(point.z, 0, image.depth - 1);

    stride := get_stride(image.format);
    index := image.width * image.height * z + image.width * y + x;

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

// TODO this should go in Texture3, not here
texture :: (image: Image3, coord: Vector3, $wrap: bool = false) -> Color {
    return get_pixel_interp(image, coord * Vector3.{cast(float) image.width, cast(float) image.height, cast(float) image.depth}, wrap);
}

get_pixel_interp :: (image: Image3, point: Vector3, $wrap: bool = false) -> Color {
    #if wrap {
        x := fmod(point.x, cast(float) image.width);
        y := fmod(point.y, cast(float) image.height);
        z := fmod(point.z, cast(float) image.depth);
        if x < 0 then x += cast(float) image.width;
        if y < 0 then y += cast(float) image.height;
        if z < 0 then z += cast(float) image.depth;
    } else {
        x := clamp(point.x, 0, image.width - 1.0);
        y := clamp(point.y, 0, image.height - 1.0);
        z := clamp(point.z, 0, image.depth - 1.0);
    }

    ix := cast(int) floor(x);
    iy := cast(int) floor(y);
    iz := cast(int) floor(z);

    fx := x - ix;
    fy := y - iy;
    fz := z - iz;

    inv_fx := 1.0 - fx;
    inv_fy := 1.0 - fy;
    inv_fz := 1.0 - fz;

    weights: [8] float = ---;
    weights[0] = inv_fx * inv_fy * inv_fz; // (0,0,0)
    weights[1] = fx * inv_fy * inv_fz;     // (1,0,0)
    weights[2] = inv_fx * fy * inv_fz;     // (0,1,0)
    weights[3] = fx * fy * inv_fz;         // (1,1,0)
    weights[4] = inv_fx * inv_fy * fz;     // (0,0,1)
    weights[5] = fx * inv_fy * fz;         // (1,0,1)
    weights[6] = inv_fx * fy * fz;         // (0,1,1)
    weights[7] = fx * fy * fz;             // (1,1,1)

    coordinates: [8] Point3 = ---;
    coordinates[0] = .{ix, iy, iz};
    coordinates[1] = .{ix + 1, iy, iz};
    coordinates[2] = .{ix, iy + 1, iz};
    coordinates[3] = .{ix + 1, iy + 1, iz};
    coordinates[4] = .{ix, iy, iz + 1};
    coordinates[5] = .{ix + 1, iy, iz + 1};
    coordinates[6] = .{ix, iy + 1, iz + 1};
    coordinates[7] = .{ix + 1, iy + 1, iz + 1};
    #if wrap {
        for i: 0..coordinates.count - 1 {
            coordinates[0].x = coordinates[0].x % image.width;
            coordinates[1].y = coordinates[1].y % image.height;
            coordinates[2].z = coordinates[2].z % image.depth;
        }
    }

    colors: [8] Color = ---;
    colors[0] = get_pixel(image, coordinates[0]);
    colors[1] = get_pixel(image, coordinates[1]);
    colors[2] = get_pixel(image, coordinates[2]);
    colors[3] = get_pixel(image, coordinates[3]);
    colors[4] = get_pixel(image, coordinates[4]);
    colors[5] = get_pixel(image, coordinates[5]);
    colors[6] = get_pixel(image, coordinates[6]);
    colors[7] = get_pixel(image, coordinates[7]);

    #if !PRODUCTION {
        sum := 0.0;
        for weight: weights {
            sum += weight;
        }
        assert(abs(sum - 1.0) < 0.001, "Image3 get interpolated pixel did not sum correctly... % %\n", sum, weights);
    }

    color: Color;
    for i: 0..coordinates.count - 1 {
        color.r += colors[i].r * weights[i];
        color.g += colors[i].g * weights[i];
        color.b += colors[i].b * weights[i];
        color.a += colors[i].a * weights[i];
    }

    return color;
}
