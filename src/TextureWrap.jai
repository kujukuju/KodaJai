
TextureWrap :: enum {
    Clamp;
    Repeat;
    MirroredRepeat;
    Border;
}

get_gl_format :: (wrap: TextureWrap) -> s32 {
    if #complete wrap == {
        case .Clamp;
            return GL_CLAMP_TO_EDGE;
        case .Repeat;
            return GL_REPEAT;
        case .MirroredRepeat;
            return GL_MIRRORED_REPEAT;
        case .Border;
            return GL_CLAMP_TO_BORDER;
    }
}
