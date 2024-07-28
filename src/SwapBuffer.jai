SwapBuffer :: struct {
    buffer: GLuint;
    texture: GLuint;
    size: int;
}

swap_buffer_create :: (size: int) -> SwapBuffer {
    return swap_buffer_create(size, GL_R8);
}

swap_buffer_create :: (size: int, format: GLenum) -> SwapBuffer {
    buffer: SwapBuffer;
    buffer.size = size;
    
    // should I update to glCreateBuffers?
    glGenBuffers(1, *buffer.buffer);
	glGenTextures(1, *buffer.texture);
    glBindBuffer(GL_TEXTURE_BUFFER, buffer.buffer);
    glBindTextureTemporary(GL_TEXTURE_BUFFER, buffer.texture);
    glTexBuffer(GL_TEXTURE_BUFFER, format, buffer.buffer);
    glBufferData(GL_TEXTURE_BUFFER, size, null, GL_DYNAMIC_DRAW);

    return buffer;
}

swap_buffer_destroy :: (buffer: *SwapBuffer) {
    // TODO probably dont need buffer pointer above
    glDeleteBuffers(1, *buffer.buffer);
}

swap_buffer_set_data :: (buffer: *SwapBuffer, data: [] u8) {
    assert(buffer.size == data.count, tprint("Buffer size must be the same. % %\n", buffer.size, data.count));

    glBindBuffer(GL_TEXTURE_BUFFER, buffer.buffer);
    glBindTextureTemporary(GL_TEXTURE_BUFFER, buffer.texture);
    // glTexBuffer(GL_TEXTURE_BUFFER, format, buffer.buffer);
    glBufferData(GL_TEXTURE_BUFFER, buffer.size, null, GL_DYNAMIC_DRAW);
    glBufferSubData(GL_TEXTURE_BUFFER, 0, buffer.size, data.data);

    // glNamedBufferData(buffer.buffer, buffer.size, null, GL_DYNAMIC_DRAW);
    // glNamedBufferSubData(buffer.buffer, 0, buffer.size, data.data);
}