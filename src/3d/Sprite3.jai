
Sprite3 :: struct {
    texture: Texture;
    uniforms: ShaderUniforms;
    position: Vector3;
    rotation: Quaternion;
    width: float;
    height: float;
    // anchor: Vector2 = .{0.5, 0.5};
    tint: Color = .{1, 1, 1, 1};
    alpha: float = 1;
    texture_frame: Vector4 = .{0, 0, 1, 1};
    local_aabb: AABB3;
    shader: *Shader;
    vao: GLuint;
    vbo: GLuint;
    ebo: GLuint;
}

create_sprite3 :: (texture: Texture) -> Sprite3 {
    return create_sprite3(texture, xx texture.width, xx texture.height);
}

create_sprite3 :: (texture: Texture, width: float, height: float, anchor: Vector2 = .{0, 0}, tint: Color = .{1, 1, 1, 1}) -> Sprite3 {
    sprite: Sprite3;
    sprite.texture = texture;
    sprite.position = .{0, 0, 0};
    sprite.width = width;
    sprite.height = height;
    // sprite.anchor = anchor;
    sprite.tint = tint;
    sprite.local_aabb = .{.{-1, -1, 0}, .{1, 1, 0}};

    vertices :: float.[
        // top left
        -1.0, 1.0, 0.0,
        0.0, 0.0,
        // bottom left
        -1.0, -1.0, 0.0,
        0.0, 1.0,
        // bottom right
        1.0, -1.0, 0.0,
        1.0, 1.0,
        // top right
        1.0, 1.0, 0.0,
        1.0, 0.0,
    ];
    indices :: u32.[
        0, 1, 2,
        0, 2, 3,
    ];

    // TODO I can probably reuse all this right?
    glGenVertexArrays(1, *sprite.vao);
    glGenBuffers(1, *sprite.vbo);
    glGenBuffers(1, *sprite.ebo);

    glBindVertexArray(sprite.vao);
    defer glBindVertexArray(0);

    glBindBuffer(GL_ARRAY_BUFFER, sprite.vbo);
    glBufferData(GL_ARRAY_BUFFER, size_of(type_of(vertices)), vertices.data, GL_STATIC_DRAW);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, sprite.ebo);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, size_of(type_of(indices)), indices.data, GL_STATIC_DRAW);

    // position attribute
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5 * size_of(float), cast(*void) 0);
    glEnableVertexAttribArray(0);

    // texture coord attribute
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5 * size_of(float), cast(*void) (3 * size_of(float)));
    glEnableVertexAttribArray(1);

    return sprite;
}

// TODO I dont think this needs to be a pointer because the ebo, vbo, vao don't actually use pointers its for arrays right?
destroy :: (sprite: Sprite3, children: bool = true) {
    if children {
        destroy(sprite.texture);
    }

    glDeleteBuffers(1, *sprite.ebo);
    glDeleteBuffers(1, *sprite.vbo);
    glDeleteVertexArrays(1, *sprite.vao);
}

get_transform :: (sprite: Sprite3) -> Matrix4 {
    scaling := get_scale(sprite);

    transform := make_translation_matrix4(sprite.position);
    transform = rotate(transform, sprite.rotation);
    transform = scale(transform, .{scaling.x, scaling.y, 1});
    return transform;
}

get_scale :: (sprite: Sprite3) -> Vector2 {
    return .{sprite.width / sprite.texture.width, sprite.height / sprite.texture.height};
}

set_scale :: (sprite: *Sprite3, scale: float) {
    set_scale(sprite, .{scale, scale});
}

set_scale :: (sprite: *Sprite3, scale: Vector2) {
    sprite.width = sprite.texture.width * scale.x;
    sprite.height = sprite.texture.height * scale.y;
}

get_aabb :: (sprite: Sprite3) -> AABB3 {
    return transform_aabb(get_transform(sprite), sprite.local_aabb);
}

draw :: (sprite: Sprite3, transform: Matrix4 = Matrix4Identity, shader: *Shader = null) {
    draw(sprite, transform, get_perspective_matrix(), shader);
}

draw :: (sprite: Sprite3, transform: Matrix4 = Matrix4Identity, projection: Matrix4, shader: *Shader = null) {
    assert(koda.can_render, "Cannot currently make any draw calls.\n");

    if !shader {
        if sprite.shader {
            shader = sprite.shader;
        } else {
            shader = get_default_shader(.[.Position, .Texcoord]);
        }

        if !shader {
            shader = *sprite_shader3;
        }
    }
    assert(!!shader, "Could not find appropriate shader for sprite3 attributes. %\n", Attribute.[.Position, .Texcoord]);

    use_shader(shader);

    apply_uniforms(shader, sprite.uniforms);

    model := transform * get_transform(sprite);
    model = scale(model, Vector3.{abs(sprite.width / sprite.height) * sign(sprite.width), sign(sprite.height), 1});
    view := koda.view;

    uniforms: ShaderUniforms;
    defer destroy(uniforms);

    set(*uniforms, "uTexture", sprite.texture);
    
    model_view := view * model;
    model_view_projection := projection * model_view;
    set(*uniforms, "modelViewProjection", model_view_projection);
    set(*uniforms, "modelView", model_view);
    set(*uniforms, "projection", projection);
    set(*uniforms, "model", model);
    set(*uniforms, "view", view);
    
    set(*uniforms, "uTint", sprite.tint * sprite.alpha);
    set(*uniforms, "uFrame", sprite.texture_frame);

    apply_uniforms(shader, uniforms);

    glBindVertexArray(sprite.vao);
    defer glBindVertexArray(0);

    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, null);
}

#scope_file

// sprite_ids: CircleAllocator(u8);

#import "Math";
#import "JaiMath";
// #import "KodaPhysics";
// Render :: #import "Render";