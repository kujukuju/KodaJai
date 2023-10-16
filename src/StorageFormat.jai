
StorageFormat :: enum {
    U8;
    F32;
}

get_stride :: (format: StorageFormat) -> int {
    if #complete format == {
        case .U8;
            return 1;
        case .F32;
            return 4;
    }
}

get_gl_format :: (format: StorageFormat) -> u32 {
    if #complete format == {
        case .U8;
            return GL_UNSIGNED_BYTE;
        case .F32;
            return GL_FLOAT;
    }
}