SwapBuffer :: struct {
    buffer: GLuint;
    size: int;
}

create_swap_buffer :: (size: int) -> SwapBuffer {
    buffer: SwapBuffer;
    buffer.size = size;
    
    // should I update to glCreateBuffers?
    glGenBuffers(1, *buffer.buffer);
    glBindBuffer(GL_TEXTURE_BUFFER, buffer.buffer);
    glNamedBufferData(buffer.buffer, size, null, DYNAMIC_DRAW);

    return buffer;
}

destroy_swap_buffer :: (buffer: *SwapBuffer) {
    // TODO probably dont need buffer pointer above
    glDeleteBuffers(1, *buffer.buffer);
}

set_swap_buffer_data :: (buffer: SwapBuffer, data: [] u8) {
    assert(buffer.size == data.size, "Buffer size must be the same.");

    glNamedBufferData(buffer.buffer, buffer.size, null, DYNAMIC_DRAW);
    glNamedBufferSubData(buffer.buffer, 0, buffer.size, data.data);
}