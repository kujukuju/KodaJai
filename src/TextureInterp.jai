
TextureInterp :: enum {
    Linear;
    LinearMipmap;
    Nearest;
    // I don't think nearest mipmap makes sense
}

get_gl_min_format :: (interp: TextureInterp) -> s32 {
    if #complete interp == {
        case .Linear;
            return GL_LINEAR;
        case .LinearMipmap;
            return GL_LINEAR_MIPMAP_LINEAR;
        case .Nearest;
            return GL_NEAREST;
    }
}

get_gl_mag_format :: (interp: TextureInterp) -> s32 {
    if #complete interp == {
        case .Linear;
            return GL_LINEAR;
        case .LinearMipmap;
            return GL_LINEAR;
        case .Nearest;
            return GL_NEAREST;
    }
}
