SwapBuffer :: struct {
    buffer: GLuint;
    size: int;
}

create_swap_buffer :: (size: int) -> SwapBuffer {
    buffer: SwapBuffer;
    buffer.size = size;
    
    glGenBuffers(1, *buffer.buffer);
    glBindBuffer(GL_TEXTURE_BUFFER, buffer.buffer);
    glNamedBufferData(buffer.buffer, size, null, DYNAMIC_DRAW);

    return buffer;
}

set_swap_buffer_data :: (buffer: *SwapBuffer, data: [] u8) {
    assert(buffer.size == data.size, "Buffer size must be the same.");

    glNamedBufferData(buffer.buffer, buffer.size, null, DYNAMIC_DRAW);
    glNamedBufferSubData(buffer.buffer, 0, buffer.size, data.data);
}