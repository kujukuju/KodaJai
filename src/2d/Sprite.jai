Sprite :: struct {
    using #as renderable: Renderable;
    renderable.type = .Sprite;
    texture: Texture;
    position: Vector2;
    rotation: float;
    width: float;
    height: float;
    anchor: Vector2;
    tint: Color = .{1, 1, 1, 1};
    alpha: float = 1;
    texture_frame: Vector4 = .{0, 0, 1, 1};
    vbo_: GLuint;
    vao_: GLuint;
    ebo_: GLuint;
}

create_sprite :: (texture: Texture) -> Sprite {
    return create_sprite(texture, xx texture.width, xx texture.height);
}

create_sprite :: (texture: Texture, width: float, height: float, anchor: Vector2 = .{0, 0}, tint: Color = .{1, 1, 1, 1}) -> Sprite {
    sprite: Sprite;
    sprite.texture = texture;
    sprite.position = .{0, 0};
    sprite.width = width;
    sprite.height = height;
    sprite.anchor = anchor;
    sprite.tint = tint;

    vertices :: float.[
        // top left
        0.0, 0.0,
        0.0, 0.0,
        // bottom left
        0.0, 1.0,
        0.0, 1.0,
        // bottom right
        1.0, 1.0,
        1.0, 1.0,
        // top right
        1.0, 0.0,
        1.0, 0.0,
    ];
    indices :: u32.[
        0, 1, 2,
        0, 2, 3,
    ];

    // TODO I can probably reuse all this right?
    glGenVertexArrays(1, *sprite.vao_);
    glGenBuffers(1, *sprite.vbo_);
    glGenBuffers(1, *sprite.ebo_);

    glBindVertexArray(sprite.vao_);
    defer glBindVertexArray(0);

    glBindBuffer(GL_ARRAY_BUFFER, sprite.vbo_);
    glBufferData(GL_ARRAY_BUFFER, size_of(type_of(vertices)), vertices.data, GL_STATIC_DRAW);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, sprite.ebo_);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, size_of(type_of(indices)), indices.data, GL_STATIC_DRAW);

    // position attribute
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * size_of(float), cast(*void) 0);
    glEnableVertexAttribArray(0);

    // texture coord attribute
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * size_of(float), cast(*void) (2 * size_of(float)));
    glEnableVertexAttribArray(1);

    return sprite;
}

// TODO I dont think this needs to be a pointer because the ebo, vbo, vao don't actually use pointers its for arrays right?
destroy :: (sprite: Sprite) {
    glDeleteBuffers(1, *sprite.ebo_);
    glDeleteBuffers(1, *sprite.vbo_);
    glDeleteVertexArrays(1, *sprite.vao_);
}

get_scale :: (sprite: Sprite) -> Vector2 {
    return xy(sprite.width / sprite.texture.width, sprite.height / sprite.texture.height);
}

set_scale :: (sprite: *Sprite, scale: Vector2) {
    sprite.width = sprite.texture.width * scale.x;
    sprite.height = sprite.texture.height * scale.y;
}

draw :: (sprite: Sprite, position: Vector2) {
    // TODO don't do it this way?
    new := sprite;
    new.position = position;

    draw(new);
}

draw :: (sprite: Sprite, transform: Matrix4) {

}

draw :: (sprite: Sprite) {
    use_shader(*default_shader);

    quaternion: Quaternion;
    set_from_axis_and_angle(*quaternion, .{0, 0, 1}, sprite.rotation);
    real_position := sprite.position + rotate(-sprite.anchor * xy(sprite.width, sprite.height), -sprite.rotation);

    // TODO do this matrix math more efficiently than using quaternions... in fact... shouldnt it be using a matrix3 for 2d?
    // TODO probably just need my own entire matrix2/3/4 library
    projection := orthographic_projection_matrix(0.0, xx koda.width, xx koda.height, 0.0, -1.0, 1.0);
    model := Matrix4_Identity;
    model = translate(model, xyz(real_position.x, real_position.y, 0));
    model = rotate(model, quaternion);
    model = scale(model, xyz(sprite.width, sprite.height, 1.0));
    view := koda.view;

    uniforms: ShaderUniforms;
    defer free(uniforms);

    uniforms["uTexture"] = create_uniform("uTexture", sprite.texture);
    
    uniforms["projection"] = create_uniform("projection", projection);
    uniforms["model"] = create_uniform("model", model);
    uniforms["view"] = create_uniform("view", view);
    
    uniforms["uTint"] = create_uniform("uTint", sprite.tint * sprite.alpha);
    uniforms["uFrame"] = create_uniform("uFrame", sprite.texture_frame);

    apply_uniforms(*default_shader, uniforms);

    glBindVertexArray(sprite.vao_);
    defer glBindVertexArray(0);

    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, null);
}

#scope_file

// sprite_ids: CircleAllocator(u8);

#import "Math";
#import "JaiMath";
// #import "KodaPhysics";
// Render :: #import "Render";