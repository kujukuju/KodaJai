draw_sphere :: (position: Vector3, color: Color = .{1, 1, 1, 1}) {
    // no radius control yet
    if !sphere_loaded {
        load_sphere();
    }

    draw_mesh(sphere, position);
}

draw_spheres :: (positions: [] Vector3, color: Color = .{1, 1, 1, 1}) {
    // no radius control yet
    if !sphere_loaded {
        load_sphere();
    }
    
    // bad duplicate code from draw_mesh :(

    use_shader(*instanced_shader3);

    projection := make_frustum_matrix(-1.92, 1.92, -1.08, 1.08, 1.4, -1.4);
    model := Matrix4_Identity;
    view := koda.transform;

    set_uniform(*instanced_shader3, "projection", projection);
    set_uniform(*instanced_shader3, "model", model);
    set_uniform(*instanced_shader3, "view", view);

    for i: 0..sphere.materials.count - 1 {
        glActiveTexture(xx (GL_TEXTURE0 + i));
        glBindTexture(GL_TEXTURE_2D, sphere.materials[i].texture.buffer);

        set_uniform(*instanced_shader3, tprint("uTexture%", i), i);
    }
    glActiveTexture(GL_TEXTURE0);

    // TODO use attributes or whatever instead of looping this shader 1000 times
    index: int;
    while index < positions.count {
        defer index += 1000;

        offsets: [1000] Vector3;
        remaining_count := min(1000, positions.count - index);
        memcpy(offsets.data, positions.data + index, remaining_count * size_of(Vector3));
        set_uniform(*instanced_shader3, "offsets", offsets);

        glBindVertexArray(sphere.geometry.vao_);
        glDrawElementsInstanced(GL_TRIANGLES, xx sphere.geometry.vertex_indices.count, GL_UNSIGNED_INT, xx 0, xx remaining_count);
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
    sphere.geometry = create_icosphere(0.1, 1);
    add_material(*sphere, get_white_texture());
}

sphere: Mesh;
sphere_loaded: bool;