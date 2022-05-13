Mesh :: struct {
    geometry: Geometry;
    materials: [..] Material;
}

free :: (mesh: Mesh) {

}

add_material :: (mesh: *Mesh, texture: Texture) -> *Material {
    material: Material;
    material.texture = texture;

    array_add(*mesh.materials, material);

    return *mesh.materials[mesh.materials.count - 1];
}

add_material :: (mesh: *Mesh, material: Material) {
    array_add(*mesh.materials, material);
}

draw_mesh :: (mesh: Mesh, position: Vector3, rotation: Quaternion) {
    use_shader(*default_shader3);

    projection := make_frustum_matrix(-1.92, 1.92, -1.08, 1.08, 1.4, -1.4);
    model := Matrix4_Identity;
    view := koda.transform;

    set_uniform(*default_shader3, "projection", projection);
    set_uniform(*default_shader3, "model", model);
    set_uniform(*default_shader3, "view", view);

    for i: 0..mesh.materials.count - 1 {
        glActiveTexture(xx (GL_TEXTURE0 + i));
        glBindTexture(GL_TEXTURE_2D, mesh.materials[i].texture.texture);

        set_uniform(*default_shader, tprint("uTexture%", i), i);
    }
    glActiveTexture(GL_TEXTURE0);

    apply_shader_uniforms();

    glBindVertexArray(mesh.geometry.vao_);
    glDrawElements(GL_TRIANGLES, xx mesh.geometry.vertex_indices.count, GL_UNSIGNED_INT, xx 0);
    glBindVertexArray(0);
}