draw_line :: (p1: Vector3, p2: Vector3, width: float = 1.0, color: Color = .{1, 1, 1, 1}) {
    vertices: [2] Vector3;
    vertices[0] = p1;
    vertices[1] = p2;

    vao: GLuint;
    glGenVertexArrays(1, *vao);
    defer glDeleteVertexArrays(1, *vao);
    glBindVertexArray(vao);
    defer glBindVertexArray(0);

    buffer_id: GLuint;
    glGenBuffers(1, *buffer_id);
    defer glDeleteBuffers(1, *buffer_id);

    glBindBuffer(GL_ARRAY_BUFFER, buffer_id);
    glBufferData(GL_ARRAY_BUFFER, size_of(type_of(vertices)), *vertices, GL_DYNAMIC_DRAW);

    glEnableVertexAttribArray(0);
    defer glDisableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Vector3), null);

    use_shader(*default_shape_shader3);

    model := Matrix4Identity;
    projection := get_perspective_matrix();
    view := koda.view;

    uniforms: ShaderUniforms;
    defer destroy(uniforms);

    uniforms["model"] = create_uniform("model", model);
    uniforms["projection"] = create_uniform("projection", projection);
    uniforms["view"] = create_uniform("view", view);
    uniforms["uTint"] = create_uniform("uTint", color);

    apply_uniforms(*default_shape_shader3, uniforms);

    // depth_test := get_depth_test();
    // set_depth_test(false);
    // defer set_depth_test(depth_test);

    // cull_face := get_cull_face();
    // set_cull_face(false);
    // defer set_cull_face(cull_face);

    glLineWidth(width);
    glDrawArrays(GL_LINES, 0, xx vertices.count);
}

draw_square :: (center: Vector3, up: Vector3, half_dimensions: Vector2, color: Color = .{1, 1, 1, 1}, border_width: float = 1.0, border_color: Color = .{0, 0, 0, 0}) {
    if !square_loaded {
        load_square();
    }

    up_pitch_angle := PI / 2.0 - atan2(up.y, length(.{up.x, up.z}));
    up_yaw_angle := PI / 2 - atan2(up.z, up.x);

    pitch_rotation := make_rotation_quaternion(.{1, 0, 0}, up_pitch_angle);
    yaw_rotation := make_rotation_quaternion(.{0, 1, 0}, up_yaw_angle);

    rotation := yaw_rotation * pitch_rotation;

    use_shader(*default_shape_shader3);

    model := Matrix4Identity;
    model = translate(model, center);
    model = rotate(model, rotation);
    model = scale(model, Vector3.{half_dimensions.x, 0.0, half_dimensions.y});
    // TODO scale dimensions
    projection := get_perspective_matrix();
    view := koda.view;

    uniforms: ShaderUniforms;
    defer destroy(uniforms);
    
    uniforms["projection"] = create_uniform("projection", projection);
    uniforms["model"] = create_uniform("model", model);
    uniforms["view"] = create_uniform("view", view);

    uniforms["uTint"] = create_uniform("uTint", color);
    
    apply_uniforms(*default_shape_shader3, uniforms);

    glBindVertexArray(square.vao_);
    glDrawElements(GL_TRIANGLES, xx square.indices.count, GL_UNSIGNED_INT, xx 0);
    glBindVertexArray(0);

    if border_color.a > 0 && border_width > 0 {
        corners: [4] Vector3;
        corners[0] = (model * Vector4.{-1.0, 0.0, -1.0, 1.0}).xyz;
        corners[1] = (model * Vector4.{-1.0, 0.0, 1.0, 1.0}).xyz;
        corners[2] = (model * Vector4.{1.0, 0.0, 1.0, 1.0}).xyz;
        corners[3] = (model * Vector4.{1.0, 0.0, -1.0, 1.0}).xyz;

        draw_line(corners[0], corners[1], border_width, border_color);
        draw_line(corners[1], corners[2], border_width, border_color);
        draw_line(corners[2], corners[3], border_width, border_color);
        draw_line(corners[3], corners[0], border_width, border_color);
    }
}

draw_torus :: (center: Vector3, up: Vector3, major_radius: float, minor_radius: float, color: Color = .{1, 1, 1, 1}) {
    if !torus_loaded {
        load_torus();
    }

    up_pitch_angle := PI / 2.0 - atan2(up.y, length(.{up.x, up.z}));
    up_yaw_angle := PI / 2 - atan2(up.z, up.x);

    pitch_rotation := make_rotation_quaternion(.{1, 0, 0}, up_pitch_angle);
    yaw_rotation := make_rotation_quaternion(.{0, 1, 0}, up_yaw_angle);

    rotation := yaw_rotation * pitch_rotation;

    use_shader(*torus_shader);

    model := Matrix4Identity;
    model = translate(model, center);
    model = rotate(model, rotation);
    projection := get_perspective_matrix();
    view := koda.view;

    uniforms: ShaderUniforms;
    defer destroy(uniforms);
    
    uniforms["projection"] = create_uniform("projection", projection);
    uniforms["model"] = create_uniform("model", model);
    uniforms["view"] = create_uniform("view", view);

    uniforms["uMajorRadius"] = create_uniform("uMajorRadius", major_radius);
    uniforms["uMinorRadius"] = create_uniform("uMinorRadius", minor_radius);
    uniforms["uTint"] = create_uniform("uTint", color);
    
    apply_uniforms(*torus_shader, uniforms);

    glBindVertexArray(torus.vao_);
    glDrawElements(GL_TRIANGLES, xx torus.indices.count, GL_UNSIGNED_INT, xx 0);
    glBindVertexArray(0);
}

draw_infinite_grid :: (center: Vector3 = .{0, 0, 0}, normal: Vector3 = .{0, 1, 0}, forward: Vector3 = .{1, 0, 0}, radius: float = 0.0, spacing: float = 1.0, color: Color = .{1, 1, 1, 1}) {
    vertices: [6] Vector2;
    vertices[0] = .{-1, -1};
    vertices[1] = .{-1, 1};
    vertices[2] = .{1, 1};
    vertices[3] = .{-1, -1};
    vertices[4] = .{1, 1};
    vertices[5] = .{1, -1};

    vao: GLuint;
    glGenVertexArrays(1, *vao);
    defer glDeleteVertexArrays(1, *vao);
    glBindVertexArray(vao);
    defer glBindVertexArray(0);

    buffer_id: GLuint;
    glGenBuffers(1, *buffer_id);
    defer glDeleteBuffers(1, *buffer_id);

    glBindBuffer(GL_ARRAY_BUFFER, buffer_id);
    glBufferData(GL_ARRAY_BUFFER, size_of(type_of(vertices)), *vertices, GL_DYNAMIC_DRAW);

    glEnableVertexAttribArray(0);
    defer glDisableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, size_of(Vector2), null);

    use_shader(*infinite_grid_shader);

    projection := get_perspective_matrix();
    view := koda.view;

    uniforms: ShaderUniforms;
    defer destroy(uniforms);

    uniforms["projection"] = create_uniform("projection", projection);
    uniforms["view"] = create_uniform("view", view);
    uniforms["uTint"] = create_uniform("uTint", color);
    uniforms["uPosition"] = create_uniform("uPosition", center);
    uniforms["uNormal"] = create_uniform("uNormal", normal);
    uniforms["uForward"] = create_uniform("uForward", forward);
    uniforms["uRadius"] = create_uniform("uRadius", radius);
    uniforms["uSpacing"] = create_uniform("uSpacing", spacing);

    apply_uniforms(*infinite_grid_shader, uniforms);

    // depth_test := get_depth_test();
    // set_depth_test(false);
    // defer set_depth_test(depth_test);

    cull_face := get_cull_face();
    set_cull_face(false);
    defer set_cull_face(cull_face);

    glDepthMask(GL_TRUE);

    glDrawArrays(GL_TRIANGLES, 0, xx vertices.count);
}

draw_cube :: (lower: Vector3, upper: Vector3, color: Color = .{1, 1, 1, 1}, border: Color = .{0, 0, 0, 0}) {

}

draw_sphere :: (position: Vector3, color: Color = .{1, 1, 1, 1}) {
    // no radius control yet
    if !sphere_loaded {
        load_sphere();
    }

    use_shader(*default_shader3);

    projection := get_perspective_matrix();
    model := Matrix4Identity;
    model = translate(model, position);
    view := koda.view;

    white_texture := get_white_texture();

    uniforms: ShaderUniforms;
    defer destroy(uniforms);
    
    uniforms["projection"] = create_uniform("projection", projection);
    uniforms["model"] = create_uniform("model", model);
    uniforms["view"] = create_uniform("view", view);
    
    uniforms["uTint"] = create_uniform("uTint", color);
    uniforms["uFrame"] = create_uniform("uFrame", Vector4.{0, 0, 1, 1});

    uniforms["uTexture0"] = create_uniform("uTexture0", white_texture.buffer);
    
    apply_uniforms(*default_shader3, uniforms);

    glBindVertexArray(sphere.vao_);
    glDrawElements(GL_TRIANGLES, xx sphere.indices.count, GL_UNSIGNED_INT, xx 0);
    glBindVertexArray(0);
}

draw_spheres :: (positions: [] Vector3, color: Color = .{1, 1, 1, 1}) {
    // no radius control yet
    if !sphere_loaded {
        load_sphere();
    }
    
    // bad duplicate code from draw_mesh :(

    use_shader(*instanced_shader3);

    projection := get_perspective_matrix();
    model := Matrix4Identity;
    view := koda.view;

    white_texture := get_white_texture();

    uniforms: ShaderUniforms;
    defer destroy(uniforms);
    
    uniforms["projection"] = create_uniform("projection", projection);
    uniforms["model"] = create_uniform("model", model);
    uniforms["view"] = create_uniform("view", view);
    
    uniforms["uTint"] = create_uniform("uTint", color);
    uniforms["uFrame"] = create_uniform("uFrame", Vector4.{0, 0, 1, 1});

    uniforms["uTexture0"] = create_uniform("uTexture0", white_texture.buffer);

    apply_uniforms(*instanced_shader3, uniforms);
    // TODO use attributes or whatever instead of looping this shader 1000 times
    index: int;
    while index < positions.count {
        defer index += 1000;

        remaining_count := min(1000, positions.count - index);

        offsets: [] Vector3;
        offsets.data = positions.data + index;
        offsets.count = remaining_count;

        loop_uniforms: ShaderUniforms;
        defer destroy(loop_uniforms);

        loop_uniforms["offsets"] = create_uniform("offsets", offsets);

        apply_uniforms(*instanced_shader3, loop_uniforms);

        glBindVertexArray(sphere.vao_);
        glDrawElementsInstanced(GL_TRIANGLES, xx sphere.indices.count, GL_UNSIGNED_INT, xx 0, xx remaining_count);
    }

    glBindVertexArray(0);
    glBindTexture(GL_TEXTURE_2D, 0);
}

#scope_file

load_sphere :: () {
    if sphere_loaded {
        return;
    }

    sphere_loaded = true;
    sphere = create_icosphere(0.1, 1);
}

load_torus :: () {
    if torus_loaded {
        return;
    }

    torus_loaded = true;
    torus = create_torus(2, 0.5, 64, 32, false, false);
}

load_square :: () {
    if square_loaded {
        return;
    }

    square_loaded = true;
    square = create_plane(1.0, 1.0, true, false, false);
}

sphere: Geometry;
sphere_loaded: bool;
torus: Geometry;
torus_loaded: bool;
square: Geometry;
square_loaded: bool;

infinite_grid_shader: InfiniteGridShader3;