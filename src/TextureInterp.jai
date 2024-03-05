
TextureInterp :: enum {
    LinearMipmap;
    Linear;
    NearestMipmap;
    Nearest;
    // I don't think nearest mipmap makes sense
}

get_gl_min_format :: (interp: TextureInterp) -> s32 {
    if #complete interp == {
        case .LinearMipmap;
            return GL_LINEAR_MIPMAP_LINEAR;
        case .Linear;
            return GL_LINEAR;
        case .NearestMipmap;
            return GL_NEAREST_MIPMAP_LINEAR;
        case .Nearest;
            return GL_NEAREST;
    }
}

get_gl_mag_format :: (interp: TextureInterp) -> s32 {
    if #complete interp == {
        case .LinearMipmap;
            return GL_LINEAR;
        case .Linear;
            return GL_LINEAR;
        case .NearestMipmap;
            return GL_NEAREST;
        case .Nearest;
            return GL_NEAREST;
    }
}

get_mipmap :: (interp: TextureInterp) -> bool {
    if #complete interp == {
        case .LinearMipmap;
            return true;
        case .Linear;
            return false;
        case .NearestMipmap;
            return true;
        case .Nearest;
            return false;
    }
}
