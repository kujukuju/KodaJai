
PixelFormat :: enum {
    R8;
    R16;
    R16F;
    R32F;
    RG8;
    RG16;
    RG16F;
    RG32F;
    RGB8;
    RGB16;
    RGB16F;
    RGB32F;
    RGBA8;
    RGBA16;
    RGBA16F;
    RGBA32F;
    Depth16;
    Depth24;
    Depth32;
    Depth32F;
    Depth24Stencil8;
    // CompressedBC7;
};

ColorChannels :: enum_flags {
    R :: 1;
    G :: 2;
    B :: 4;
    A :: 8;
    RG :: R | G;
    RB :: R | B;
    RA :: R | A;
    GB :: G | B;
    GA :: G | A;
    BA :: B | A;
    RGB :: R | G | B;
    RGA :: R | G | A;
    RBA :: R | B | A;
    GBA :: G | B | A;
    RGBA :: R | G | B | A;
}

get_component_info :: (format: PixelFormat) -> stride: int, component_count: int {
    return get_stride(format), get_component_count(format);
}

get_gl_info :: (format: PixelFormat) -> gl_format: u32, gl_internal_format: s32, gl_type: u32 {
    return get_gl_format(format), get_gl_internal_format(format), get_gl_type(format);
}

get_type_info :: (format: PixelFormat) -> is_float: bool, is_depth: bool {
    return is_float(format), is_depth(format);
}

get_stride :: (format: PixelFormat) -> int {
    if #complete format == {
        case .R8;
            return 1;
        case .R16;
            return 2;
        case .R16F;
            return 2;
        case .R32F;
            return 4;
        case .RG8;
            return 2;
        case .RG16;
            return 4;
        case .RG16F;
            return 4;
        case .RG32F;
            return 8;
        case .RGB8;
            return 3;
        case .RGB16;
            return 6;
        case .RGB16F;
            return 6;
        case .RGB32F;
            return 12;
        case .RGBA8;
            return 4;
        case .RGBA16;
            return 8;
        case .RGBA16F;
            return 8;
        case .RGBA32F;
            return 16;
        case .Depth16;
            return 2;
        case .Depth24;
            return 3;
        case .Depth32;
            return 4;
        case .Depth32F;
            return 4;
        case .Depth24Stencil8;
            return 4;
    }
}

get_component_count :: (format: PixelFormat) -> int {
    if #complete format == {
        case .R8;
            return 1;
        case .R16;
            return 1;
        case .R16F;
            return 1;
        case .R32F;
            return 1;
        case .RG8;
            return 2;
        case .RG16;
            return 2;
        case .RG16F;
            return 2;
        case .RG32F;
            return 2;
        case .RGB8;
            return 3;
        case .RGB16;
            return 3;
        case .RGB16F;
            return 3;
        case .RGB32F;
            return 3;
        case .RGBA8;
            return 4;
        case .RGBA16;
            return 4;
        case .RGBA16F;
            return 4;
        case .RGBA32F;
            return 4;
        case .Depth16;
            return 1;
        case .Depth24;
            return 1;
        case .Depth32;
            return 1;
        case .Depth32F;
            return 1;
        case .Depth24Stencil8;
            return 1;
    }
}

get_gl_format :: (format: PixelFormat) -> u32 {
    if #complete format == {
        case .R8;
            return GL_RED;
        case .R16;
            return GL_RED;
        case .R16F;
            return GL_RED;
        case .R32F;
            return GL_RED;
        case .RG8;
            return GL_RG;
        case .RG16;
            return GL_RG;
        case .RG16F;
            return GL_RG;
        case .RG32F;
            return GL_RG;
        case .RGB8;
            return GL_RGB;
        case .RGB16;
            return GL_RGB;
        case .RGB16F;
            return GL_RGB;
        case .RGB32F;
            return GL_RGB;
        case .RGBA8;
            return GL_RGBA;
        case .RGBA16;
            return GL_RGBA;
        case .RGBA16F;
            return GL_RGBA;
        case .RGBA32F;
            return GL_RGBA;
        case .Depth16;
            return GL_DEPTH_COMPONENT;
        case .Depth24;
            return GL_DEPTH_COMPONENT;
        case .Depth32;
            return GL_DEPTH_COMPONENT;
        case .Depth32F;
            return GL_DEPTH_COMPONENT;
        case .Depth24Stencil8;
            return GL_DEPTH_STENCIL;
    }
}

get_gl_internal_format :: (format: PixelFormat) -> s32 {
    if #complete format == {
        case .R8;
            return GL_R8;
        case .R16;
            return GL_R16;
        case .R16F;
            return GL_R16F;
        case .R32F;
            return GL_R32F;
        case .RG8;
            return GL_RG8;
        case .RG16;
            return GL_RG16;
        case .RG16F;
            return GL_RG16F;
        case .RG32F;
            return GL_RG32F;
        case .RGB8;
            return GL_RGB8;
        case .RGB16;
            return GL_RGB16;
        case .RGB16F;
            return GL_RGB16F;
        case .RGB32F;
            return GL_RGB32F;
        case .RGBA8;
            return GL_RGBA8;
        case .RGBA16;
            return GL_RGBA16;
        case .RGBA16F;
            return GL_RGBA16F;
        case .RGBA32F;
            return GL_RGBA32F;
        case .Depth16;
            return GL_DEPTH_COMPONENT16;
        case .Depth24;
            return GL_DEPTH_COMPONENT24;
        case .Depth32;
            return GL_DEPTH_COMPONENT32;
        case .Depth32F;
            return GL_DEPTH_COMPONENT32F;
        case .Depth24Stencil8;
            return GL_DEPTH24_STENCIL8;
    }
}

get_gl_type :: (format: PixelFormat) -> u32 {
    if #complete format == {
        case .R8;
            return GL_UNSIGNED_BYTE;
        case .R16;
            return GL_UNSIGNED_SHORT;
        case .R16F;
            return GL_HALF_FLOAT;
        case .R32F;
            return GL_FLOAT;
        case .RG8;
            return GL_UNSIGNED_BYTE;
        case .RG16;
            return GL_UNSIGNED_SHORT;
        case .RG16F;
            return GL_HALF_FLOAT;
        case .RG32F;
            return GL_FLOAT;
        case .RGB8;
            return GL_UNSIGNED_BYTE;
        case .RGB16;
            return GL_UNSIGNED_SHORT;
        case .RGB16F;
            return GL_HALF_FLOAT;
        case .RGB32F;
            return GL_FLOAT;
        case .RGBA8;
            return GL_UNSIGNED_BYTE;
        case .RGBA16;
            return GL_UNSIGNED_SHORT;
        case .RGBA16F;
            return GL_HALF_FLOAT;
        case .RGBA32F;
            return GL_FLOAT;
        case .Depth16;
            return GL_UNSIGNED_SHORT;
        case .Depth24;
            // the way I'm handling this is inherently flawed and the pixel format shouldn't correspond to the gl type so there's no good answer here
            return GL_UNSIGNED_INT ;
        case .Depth32;
            // not recommended to use depth32 integer
            return GL_UNSIGNED_INT;
        case .Depth32F;
            return GL_FLOAT;
        case .Depth24Stencil8;
            // huh
            return GL_UNSIGNED_INT_24_8;
    }
}

is_float :: (format: PixelFormat) -> bool {
    if #complete format == {
        case .R8;
            return false;
        case .R16;
            return false;
        case .R16F;
            return true;
        case .R32F;
            return true;
        case .RG8;
            return false;
        case .RG16;
            return false;
        case .RG16F;
            return true;
        case .RG32F;
            return true;
        case .RGB8;
            return false;
        case .RGB16;
            return false;
        case .RGB16F;
            return true;
        case .RGB32F;
            return true;
        case .RGBA8;
            return false;
        case .RGBA16;
            return false;
        case .RGBA16F;
            return true;
        case .RGBA32F;
            return true;
        case .Depth16;
            return false;
        case .Depth24;
            return false;
        case .Depth32;
            return false;
        case .Depth32F;
            return true;
        case .Depth24Stencil8;
            return false;
    }
}

is_depth :: (format: PixelFormat) -> bool {
    if #complete format == {
        case .R8;
            return false;
        case .R16;
            return false;
        case .R16F;
            return false;
        case .R32F;
            return false;
        case .RG8;
            return false;
        case .RG16;
            return false;
        case .RG16F;
            return false;
        case .RG32F;
            return false;
        case .RGB8;
            return false;
        case .RGB16;
            return false;
        case .RGB16F;
            return false;
        case .RGB32F;
            return false;
        case .RGBA8;
            return false;
        case .RGBA16;
            return false;
        case .RGBA16F;
            return false;
        case .RGBA32F;
            return false;
        case .Depth16;
            return true;
        case .Depth24;
            return true;
        case .Depth32;
            return true;
        case .Depth32F;
            return true;
        case .Depth24Stencil8;
            return true;
    }
}
