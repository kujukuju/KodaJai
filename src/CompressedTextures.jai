
// you have to have downloaded nvidia texture tools
// and the root directory must be in your system path

CompressedImage :: struct {
    image: Image;
    mipmaps: [] Image;
    compression: CompressionType;
    wrap: TextureWrap;
    interp: TextureInterp;
}

CompressionType :: enum {
    .BC7;
}

DDSPixelFormat :: struct {
    dwSize: u32 #align 1;
    dwFlags: u32 #align 1;
    dwFourCC: u32 #align 1;
    dwRGBBitCount: u32 #align 1;
    dwRBitMask: u32 #align 1;
    dwGBitMask: u32 #align 1;
    dwBBitMask: u32 #align 1;
    dwABitMask: u32 #align 1;
} #no_padding

DDSPixelFormatFlags :: enum_flags u32 {
    ALPHAPIXELS :: 0x1;
    ALPHA :: 0x2;
    FOURCC :: 0x4;
    RGB :: 0x40;
    YUV :: 0x200;
    LUMINANCE :: 0x20000;
}

DDSHeader :: struct {
    dwMagic: u32 #align 1;
    
    dwSize: u32 #align 1;
    dwFlags: u32 #align 1;
    dwHeight: u32 #align 1;
    dwWidth: u32 #align 1;
    dwPitchOrLinearSize: u32 #align 1;
    dwDepth: u32 #align 1; // Only if DDS_HEADER_FLAGS_VOLUME is set in dwFlags
    dwMipMapCount: u32 #align 1;
    dwReserved1: [11] u32 #align 1;

    ddspf: DDSPixelFormat #align 1;

    dwCaps: u32 #align 1;
    dwCaps2: u32 #align 1;
    dwCaps3: u32 #align 1;
    dwCaps4: u32 #align 1;
    dwReserved2: u32 #align 1;
} #no_padding

DDSFlags :: enum_flags u32 {
    CAPS :: 0x1;
    HEIGHT :: 0x2;
    WIDTH :: 0x4;
    PITCH :: 0x8;
    PIXELFORMAT :: 0x1000;
    MIPMAPCOUNT :: 0x20000;
    LINEARSIZE :: 0x80000;
    DEPTH :: 0x800000;
}

load_compressed_image :: (path: string) -> CompressedImage {
    file, success := read_entire_file(path);
    assert(success, "Could not read compressed image. %\n", path);

    bytes: [] u8;
    bytes.data = file.data;
    bytes.count = file.count;

    return create_compressed_image(bytes);
}

create_compressed_image :: (bytes: [] u8) -> CompressedImage {
    if bytes.count < size_of(DDSHeader) {
        assert(false, "Invalid DDS file.\n");
        return .{};
    }

    // technically the magic number isn't in the header I think, but oh well
    header := cast(*DDSHeader) bytes.data;
    if header.dwMagic != 0x20534444 {
        assert(false, "Invalid DDS file. Invalid magic number.\n");
        return .{};
    }

    if header.dwSize != 124 {
        assert(false, "Unsupported DDS file. Invalid header size. Maybe it has extensions?\n");
        return .{};
    }

    if header.ddspf.dwSize != 32 {
        assert(false, "Unsupported DDS pixel format. Invalid pixel format size.\n");
        return .{};
    }

    uncompressed_pitch_provided := header.dwFlags & DDSFlags.PITCH;
    compressed_pitch_provided := header.dwFlags & DDSFlags.LINEARSIZE;
    has_mipmaps := header.dwFlags & DDSFlags.MIPMAPCOUNT;
    has_depth := header.dwFlags & DDSFlags.DEPTH;

    compressed: CompressedImage;
    compressed.width = header.dwWidth;
    compressed.height = header.dwHeight;

    has_alpha := header.ddspf.dwFlags & DDSPixelFormatFlags.ALPHAPIXELS;
    if header.ddspf.dwFlags & DDSPixelFormatFlags.ALPHA {
        assert(false, "DDS file has legacy ALPHA information which I'm not yet supporting.\n");
        return .{};
    }

    is_compressed_rgb := header.ddspf.dwFlags & .DDSPixelFormatFlags.FOURCC;
    is_uncompressed_rgb := header.ddspf.dwFlags & .DDSPixelFormatFlags.RGB;
    
    if header.ddspf.dwFlags & DDSPixelFormatFlags.YUV {
        assert(false, "DDS file has legacy YUV uncompressed information which I'm not yet supporting.\n");
        return .{};
    }
    
    if header.ddspf.dwFlags & DDSPixelFormatFlags.LUMINANCE {
        assert(false, "DDS file has LUMINANCE information which I'm not yet supporting.\n");
        return .{};
    }

    if has_mipmaps {
        compressed.mipmaps = NewArray(header.dwMipMapCount, Image);
    }
}

create_compressed_image :: (image: Image, wrap: TextureWrap = .Clamp, interp: TextureInterp = .Linear, normals: bool = false) -> CompressedImage {
    valid_format := image.format == .R8 || image.format == .RG8 || image.format == .RGB8 || image.format == .RGBA8;
    assert(valid_format, "Invalid texture format. %\n", image.format);
    if !valid_format {
        return;
    }

    save_image(image, "image_compress_interm_bc7.png");
    defer file_delete("image_compress_interm_bc7.png");

    parts: [..] string;
    parts.allocator = temp;

    array_add(*parts, "nvcompress.exe", "-bc7", "-production");

    if normals {
        array_add(*parts, "-normal");
    } else {
        array_add(*parts, "-color");
    }

    if image.format == .RGBA8 {
        array_add(*parts, "-alpha");
    } else {
        array_add(*parts, "-noalpha");
    }

    if wrap == .Clamp {
        array_add(*parts, "-clamp");
    } else if wrap == .Repeat || wrap == .MirroredRepeat {
        array_add(*parts, "-repeat");
    }

    if get_mipmap(interp) {
        array_add(*parts, "-mipfilter", "kaiser");
    } else {
        array_add(*parts, "-nomip");
    }

    array_add(*parts, "image_compress_interm_bc7.png", "image_compress_interm_bc7.dds");

    run_command(..parts);

    compressed_image: CompressedImage;

    

    = string.[
        "nvcompress.exe",
        "-bc7",
        "-production",
        "-nomips",
        "-mipfilter", "kaiser",
        "image_compress_interm_bc7.png",
    ];
    parts := fixed_parts;

    run_command("nvcompress.exe", "-bc7", "-production", "image_compress_interm_bc7.png");
}

#scope_file

#import "Process";
