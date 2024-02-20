PixelFormat :: enum {
    Gray8;
    Gray16;
    Gray16F;
    Gray32F;
    R8 :: Gray8;
    R16 :: Gray16;
    R16F :: Gray16F;
    R32F :: Gray32F;
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
    Depth32F;
    // DepthStencil;
};

get_stride :: (format: PixelFormat) -> int {
    if #complete format == {
        case .Gray8;
            return 1;
        case .Gray16;
            return 2;
        case .Gray16F;
            return 2;
        case .Gray32F;
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
        case .Depth32F;
            return 4;
    }
}

get_gl_format :: (format: PixelFormat) -> u32 {
    if #complete format == {
        case .Gray8;
            return GL_RED;
        case .Gray16;
            return GL_RED;
        case .Gray16F;
            return GL_RED;
        case .Gray32F;
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
        case .Depth32F;
            return GL_DEPTH_COMPONENT;
    }
}

get_gl_internal_format :: (format: PixelFormat) -> s32 {
    if #complete format == {
        case .Gray8;
            return GL_R8;
        case .Gray16;
            return GL_R16;
        case .Gray16F;
            return GL_R16F;
        case .Gray32F;
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
        case .Depth32F;
            return GL_DEPTH_COMPONENT32F;
    }
}

get_gl_type :: (format: PixelFormat) -> u32 {
    if #complete format == {
        case .Gray8;
            return GL_UNSIGNED_BYTE;
        case .Gray16;
            return GL_UNSIGNED_SHORT;
        case .Gray16F;
            return GL_HALF_FLOAT;
        case .Gray32F;
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
        case .Depth32F;
            return GL_FLOAT;
    }
}

is_float :: (format: PixelFormat) -> bool {
    if #complete format == {
        case .Gray8;
            return false;
        case .Gray16;
            return false;
        case .Gray16F;
            return true;
        case .Gray32F;
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
        case .Depth32F;
            return true;
    }
}
