
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
    glBufferData(GL_ARRAY_BUFFER, size_of(type_of(vertices)), vertices.data, GL_DYNAMIC_DRAW);

    glEnableVertexAttribArray(0);
    defer glDisableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Vector3), null);

    use_shader(*default_shape_shader3);

    model := Matrix4Identity;
    projection := get_perspective_matrix();
    view := koda.view;

    uniforms: ShaderUniforms;
    defer destroy(uniforms);

    set(*uniforms, "model", model);
    set(*uniforms, "projection", projection);
    set(*uniforms, "view", view);
    set(*uniforms, "uTint", color);

    apply_uniforms(*default_shape_shader3, uniforms);

    glLineWidth(width);
    glDrawArrays(GL_LINES, 0, xx vertices.count);
}

draw_square :: (center: Vector3, up: Vector3, half_dimensions: Vector2, color: Color = .{1, 1, 1, 1}, border_width: float = 1.0, border_color: Color = .{0, 0, 0, 0}) {
    if !square_loaded {
        load_square();
    }

    up_pitch_angle := PI / 2.0 - atan2(up.y, length(Vector2.{up.x, up.z}));
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
    
    set(*uniforms, "projection", projection);
    set(*uniforms, "model", model);
    set(*uniforms, "view", view);

    set(*uniforms, "uTint", color);
    
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

    up_pitch_angle := PI / 2.0 - atan2(up.y, length(Vector2.{up.x, up.z}));
    up_yaw_angle := PI / 2 - atan2(up.z, up.x);

    pitch_rotation := make_rotation_quaternion(.{1, 0, 0}, up_pitch_angle);
    yaw_rotation := make_rotation_quaternion(.{0, 1, 0}, up_yaw_angle);

    rotation := yaw_rotation * pitch_rotation;

    use_shader(*torus_shader3);

    model := Matrix4Identity;
    model = translate(model, center);
    model = rotate(model, rotation);
    projection := get_perspective_matrix();
    view := koda.view;

    uniforms: ShaderUniforms;
    defer destroy(uniforms);
    
    set(*uniforms, "projection", projection);
    set(*uniforms, "model", model);
    set(*uniforms, "view", view);

    set(*uniforms, "uMajorRadius", major_radius);
    set(*uniforms, "uMinorRadius", minor_radius);
    set(*uniforms, "uTint", color);
    
    apply_uniforms(*torus_shader3, uniforms);

    glBindVertexArray(torus.vao_);
    glDrawElements(GL_TRIANGLES, xx torus.indices.count, GL_UNSIGNED_INT, xx 0);
    glBindVertexArray(0);
}

draw_flat_grid :: (center: Vector3 = .{0, 0, 0}, fade_center: Vector3 = .{0, 0, 0}, radius: float = 40.0, draw_center_lines: bool = true, color: Color = .{1, 1, 1, 1}) {
    if !grid_loaded {
        load_grid();
    }

    use_shader(*flat_grid_shader3);

    model := Matrix4Identity;
    model = translate(model, center);
    projection := get_perspective_matrix();
    view := koda.view;

    uniforms: ShaderUniforms;
    defer destroy(uniforms);
    
    set(*uniforms, "projection", projection);
    set(*uniforms, "model", model);
    set(*uniforms, "view", view);

    set(*uniforms, "uTint", color);
    set(*uniforms, "uRadius", radius);
    set(*uniforms, "uFadeCenter", fade_center);
    
    apply_uniforms(*flat_grid_shader3, uniforms);

    glBindVertexArray(grid.vao_);
    glLineWidth(1.0);
    glDrawArrays(GL_LINES, 0, xx (grid.vertices.count / 3));

    if draw_center_lines {
        glBindVertexArray(center_grid.vao_);
        // TODO glLineWidth(2.0);
        glLineWidth(4.0);
        glDrawArrays(GL_LINES, 0, xx (center_grid.vertices.count / 3));
    }

    glBindVertexArray(0);
}

draw_triangle :: (p1: Vector3, p2: Vector3, p3: Vector3, color: Color = .{1, 1, 1, 1}) {
    vertices: [3] Vector3;
    vertices[0] = p1;
    vertices[1] = p2;
    vertices[2] = p3;

    vao: GLuint;
    glGenVertexArrays(1, *vao);
    defer glDeleteVertexArrays(1, *vao);
    glBindVertexArray(vao);
    defer glBindVertexArray(0);

    buffer_id: GLuint;
    glGenBuffers(1, *buffer_id);
    defer glDeleteBuffers(1, *buffer_id);

    glBindBuffer(GL_ARRAY_BUFFER, buffer_id);
    glBufferData(GL_ARRAY_BUFFER, size_of(type_of(vertices)), vertices.data, GL_DYNAMIC_DRAW);

    glEnableVertexAttribArray(0);
    defer glDisableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Vector3), null);

    use_shader(*default_shape_shader3);

    model := Matrix4Identity;
    projection := get_perspective_matrix();
    view := koda.view;

    uniforms: ShaderUniforms;
    defer destroy(uniforms);

    set(*uniforms, "model", model);
    set(*uniforms, "projection", projection);
    set(*uniforms, "view", view);
    set(*uniforms, "uTint", color);

    apply_uniforms(*default_shape_shader3, uniforms);

    glDrawArrays(GL_TRIANGLES, 0, xx vertices.count);
}

draw_triangles :: (vertices: [] Vector3, color: Color = .{1, 1, 1, 1}) {
    vao: GLuint;
    glGenVertexArrays(1, *vao);
    defer glDeleteVertexArrays(1, *vao);
    glBindVertexArray(vao);
    defer glBindVertexArray(0);

    buffer_id: GLuint;
    glGenBuffers(1, *buffer_id);
    defer glDeleteBuffers(1, *buffer_id);

    glBindBuffer(GL_ARRAY_BUFFER, buffer_id);
    glBufferData(GL_ARRAY_BUFFER, size_of(Vector3) * vertices.count, vertices.data, GL_DYNAMIC_DRAW);

    glEnableVertexAttribArray(0);
    defer glDisableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Vector3), null);

    use_shader(*default_shape_shader3);

    model := Matrix4Identity;
    projection := get_perspective_matrix();
    view := koda.view;

    uniforms: ShaderUniforms;
    defer destroy(uniforms);

    set(*uniforms, "model", model);
    set(*uniforms, "projection", projection);
    set(*uniforms, "view", view);
    set(*uniforms, "uTint", color);

    apply_uniforms(*default_shape_shader3, uniforms);

    glDrawArrays(GL_TRIANGLES, 0, xx vertices.count);
}

draw_cube :: (lower: Vector3, upper: Vector3, color: Color = .{1, 1, 1, 1}, border: Color = .{0, 0, 0, 0}) {
    if !cube_loaded {
        load_cube();
    }

    position := (lower + upper) / 2.0;
    scale_vec := (upper - lower) / 2.0;

    use_shader(*default_shape_shader3);

    projection := get_perspective_matrix();
    model := Matrix4Identity;
    model = translate(model, position);
    model = scale(model, scale_vec);
    view := koda.view;

    uniforms: ShaderUniforms;
    defer destroy(uniforms);
    
    set(*uniforms, "projection", projection);
    set(*uniforms, "model", model);
    set(*uniforms, "view", view);
    
    set(*uniforms, "uTint", color);
    
    apply_uniforms(*default_shape_shader3, uniforms);

    glBindVertexArray(cube.vao_);
    glDrawElements(GL_TRIANGLES, xx cube.indices.count, GL_UNSIGNED_INT, xx 0);
    glBindVertexArray(0);

    if border.a > 0 {
        // not entirely sure if its 1, 1, 1, or 0.5, 0.5, 0.5 but w/e, havent tested it
        draw_cube_border(.{-1, -1, -1}, .{1, 1, 1}, model, 1.0, border);
    }
}

draw_cube_border :: (lower: Vector3, upper: Vector3, transform: Matrix4 = Matrix4Identity, width: float = 1.0, color: Color = .{1, 1, 1, 1}) {
    corners: [8] Vector3 = ---;
    corners[0] = .{lower.x, lower.y, lower.z};
    corners[1] = .{upper.x, lower.y, lower.z};
    corners[2] = .{upper.x, upper.y, lower.z};
    corners[3] = .{lower.x, upper.y, lower.z};
    corners[4] = .{lower.x, lower.y, upper.z};
    corners[5] = .{upper.x, lower.y, upper.z};
    corners[6] = .{upper.x, upper.y, upper.z};
    corners[7] = .{lower.x, upper.y, upper.z};

    vertices: [24] Vector3 = ---;
    // bottom
    vertices[0] = corners[0];
    vertices[1] = corners[1];
    vertices[2] = corners[1];
    vertices[3] = corners[2];
    vertices[4] = corners[2];
    vertices[5] = corners[3];
    vertices[6] = corners[3];
    vertices[7] = corners[0];
    // top
    vertices[8] = corners[4];
    vertices[9] = corners[5];
    vertices[10] = corners[5];
    vertices[11] = corners[6];
    vertices[12] = corners[6];
    vertices[13] = corners[7];
    vertices[14] = corners[7];
    vertices[15] = corners[4];
    // edges
    vertices[16] = corners[0];
    vertices[17] = corners[4];
    vertices[18] = corners[1];
    vertices[19] = corners[5];
    vertices[20] = corners[2];
    vertices[21] = corners[6];
    vertices[22] = corners[3];
    vertices[23] = corners[7];

    vao: GLuint;
    glGenVertexArrays(1, *vao);
    defer glDeleteVertexArrays(1, *vao);
    glBindVertexArray(vao);
    defer glBindVertexArray(0);

    buffer_id: GLuint;
    glGenBuffers(1, *buffer_id);
    defer glDeleteBuffers(1, *buffer_id);

    glBindBuffer(GL_ARRAY_BUFFER, buffer_id);
    glBufferData(GL_ARRAY_BUFFER, size_of(type_of(vertices)), vertices.data, GL_DYNAMIC_DRAW);

    glEnableVertexAttribArray(0);
    defer glDisableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Vector3), null);

    use_shader(*default_shape_shader3);

    projection := get_perspective_matrix();
    view := koda.view;

    uniforms: ShaderUniforms;
    defer destroy(uniforms);

    set(*uniforms, "model", transform);
    set(*uniforms, "projection", projection);
    set(*uniforms, "view", view);
    set(*uniforms, "uTint", color);

    apply_uniforms(*default_shape_shader3, uniforms);

    glLineWidth(width);
    glDrawArrays(GL_LINES, 0, xx vertices.count);
}

draw_sphere :: (position: Vector3, dimensions: Vector3 = .{1, 1, 1}, color: Color = .{1, 1, 1, 1}) {
    // no radius control yet
    if !sphere_loaded {
        load_sphere();
    }

    use_shader(*default_shape_shader3);

    projection := get_perspective_matrix();
    model := Matrix4Identity;
    model = translate(model, position);
    model = scale(model, dimensions * 0.5);
    view := koda.view;

    white_texture := get_white_texture();

    uniforms: ShaderUniforms;
    defer destroy(uniforms);
    
    set(*uniforms, "projection", projection);
    set(*uniforms, "model", model);
    set(*uniforms, "view", view);
    
    set(*uniforms, "uTint", color);
    
    apply_uniforms(*default_shape_shader3, uniforms);

    glBindVertexArray(sphere.vao_);
    glDrawElements(GL_TRIANGLES, xx sphere.indices.count, GL_UNSIGNED_INT, xx 0);
    glBindVertexArray(0);
}

draw_spheres :: (positions: [] Vector3, scalev: Vector3, color: Color = .{1, 1, 1, 1}) {
    // no radius control yet
    if !sphere_loaded {
        load_sphere();
    }
    
    // bad duplicate code from draw_mesh :(

    use_shader(*instanced_shader3);

    projection := get_perspective_matrix();
    model := Matrix4Identity;
    model = scale(model, scalev);
    view := koda.view;

    white_texture := get_white_texture();

    uniforms: ShaderUniforms;
    defer destroy(uniforms);
    
    set(*uniforms, "projection", projection);
    set(*uniforms, "model", model);
    set(*uniforms, "view", view);
    
    set(*uniforms, "uTint", color);
    set(*uniforms, "uFrame", Vector4.{0, 0, 1, 1});

    set(*uniforms, "uTexture0", white_texture);

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

        loop_uniforms[xx "offsets"] = create_uniform("offsets", offsets);

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
    sphere = create_icosphere(1.0, 1);
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

load_grid :: () {
    if grid_loaded {
        return;
    }

    grid_loaded = true;
    // grid = create_grid(161, 161, 1.0);
    // grid = create_grid(81, 81, 2.0);
    grid = create_grid(81, 81, 1.0);
    // center_grid = create_grid(3, 3, 80.0);
    center_grid = create_grid(3, 3, 40.0);
}

load_cube :: () {
    if cube_loaded {
        return;
    }

    cube_loaded = true;
    cube = create_cube(.{1, 1, 1});
}

sphere: *Geometry;
sphere_loaded: bool;
torus: *Geometry;
torus_loaded: bool;
square: *Geometry;
square_loaded: bool;
grid: *Geometry;
center_grid: *Geometry;
grid_loaded: bool;
cube: *Geometry;
cube_loaded: bool;
