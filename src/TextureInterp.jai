
TextureInterp :: enum {
    LinearMipmap;
    LinearMipmapNearest;
    Linear;
    NearestMipmap;
    NearestMipmapNearest;
    Nearest;
    // I don't think nearest mipmap makes sense
}

get_gl_min_format :: (interp: TextureInterp) -> s32 {
    if #complete interp == {
        case .LinearMipmap;
            return GL_LINEAR_MIPMAP_LINEAR;
        case .LinearMipmapNearest;
            return GL_LINEAR_MIPMAP_NEAREST;
        case .Linear;
            return GL_LINEAR;
        case .NearestMipmap;
            return GL_NEAREST_MIPMAP_LINEAR;
        case .NearestMipmapNearest;
            return GL_NEAREST_MIPMAP_NEAREST;
        case .Nearest;
            return GL_NEAREST;
    }
}

get_gl_mag_format :: (interp: TextureInterp) -> s32 {
    if #complete interp == {
        case .LinearMipmap;
            return GL_LINEAR;
        case .LinearMipmapNearest;
            return GL_LINEAR;
        case .Linear;
            return GL_LINEAR;
        case .NearestMipmap;
            return GL_NEAREST;
        case .NearestMipmapNearest;
            return GL_NEAREST;
        case .Nearest;
            return GL_NEAREST;
    }
}

get_mipmap :: (interp: TextureInterp) -> bool {
    if #complete interp == {
        case .LinearMipmap;
            return true;
        case .LinearMipmapNearest;
            return true;
        case .Linear;
            return false;
        case .NearestMipmap;
            return true;
        case .NearestMipmapNearest;
            return true;
        case .Nearest;
            return false;
    }
}
