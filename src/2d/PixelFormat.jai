PixelFormat :: enum {
    Gray;
    GrayAlpha;
    RGB;
    RGBA;
};

get_stride :: (format: PixelFormat) -> int {
    if #complete format == {
        case .Gray;
            return 1;
        case .GrayAlpha;
            return 2;
        case .RGB;
            return 3;
        case .RGBA;
            return 4;
    }
}

get_gl_format :: (format: PixelFormat) -> GLenum {
    if #complete format == {
        case .Gray;
            return GL_RED;
        case .GrayAlpha;
            return GL_RG;
        case .RGB;
            return GL_RGB;
        case .RGBA;
            return GL_RGBA;
    }
}
