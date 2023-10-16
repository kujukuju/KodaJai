PixelFormat :: enum {
    Gray;
    RG;
    RGB;
    RGBA;
    Depth;
    // DepthStencil;
};

get_stride :: (format: PixelFormat) -> int {
    if #complete format == {
        case .Gray;
            return 1;
        case .RG;
            return 2;
        case .RGB;
            return 3;
        case .RGBA;
            return 4;
        case .Depth;
            return 4;
        // case .DepthStencil;
        //     assert(false, "Idk man. 8?");
        //     return 8;
    }
}

get_gl_format :: (format: PixelFormat) -> u32 {
    if #complete format == {
        case .Gray;
            return GL_RED;
        case .RG;
            return GL_RG;
        case .RGB;
            return GL_RGB;
        case .RGBA;
            return GL_RGBA;
        case .Depth;
            return GL_DEPTH_COMPONENT32F;
    }
}
