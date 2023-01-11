Model :: struct {
    using #as renderable: Renderable;
    renderable.type = .Model;
    geometry: [..] *Geometry;
    uniforms: ShaderUniforms;
    position: Vector3;
    rotation: Quaternion;
}

create_model :: (geometry: *Geometry) -> Model {
    model: Model;
    array_resize(*model.geometry, 1);
    model.geometry[0] = geometry;
    return model;
}

create_model :: (geometry: [] *Geometry) -> Model {
    model: Model;
    array_copy(*model.geometry, geometry);
    return model;
}

create_model :: (geometry: *Geometry, texture: Texture) -> Model {
    model: Model;
    array_resize(*model.geometry, 1);
    model.geometry[0] = geometry;
    model.uniforms["uTexture0"] = create_uniform("uTexture0", texture);
    return model;
}

create_model :: (geometry: [] *Geometry, texture: Texture) -> Model {
    model: Model;
    array_copy(*model.geometry, geometry);
    model.uniforms["uTexture0"] = create_uniform("uTexture0", texture);
    return model;
}

upload_model :: (model: *Model) {

}

unload_model :: (model: *Model) {

}

destroy_model :: (model: Model) {
    
}

draw :: (model: Model) {
    use_shader(*default_shader3);

    projection := make_frustum_matrix(-1.92, 1.92, -1.08, 1.08, 1.4, -1.4);
    model_mat := make_translation_matrix4(model.position); // Matrix4_Identity;
    view := koda.transform;

    apply_uniforms(*default_shader3, model.uniforms);

    uniforms: ShaderUniforms;
    defer free(uniforms);
    
    uniforms["projection"] = create_uniform("projection", projection);
    uniforms["model"] = create_uniform("model", model_mat);
    uniforms["view"] = create_uniform("view", view);

    print("Model %\nView %\nProjection %\n", model_mat.floats, view.floats, projection.floats);
    
    apply_uniforms(*default_shader3, uniforms);

    for geometry: model.geometry {
        glBindVertexArray(geometry.vao_);
        glDrawElements(GL_TRIANGLES, xx geometry.indices.count, GL_UNSIGNED_INT, xx 0);
        glBindVertexArray(0);
        glBindTexture(GL_TEXTURE_2D, 0);
    }
}

// free :: (mesh: Mesh) {

// }

// add_material :: (mesh: *Mesh, texture: Texture) -> *Material {
//     material: Material;
//     material.texture = texture;

//     array_add(*mesh.materials, material);

//     return *mesh.materials[mesh.materials.count - 1];
// }

// add_material :: (mesh: *Mesh, material: Material) {
//     array_add(*mesh.materials, material);
// }

// draw :: (mesh: Mesh, position: Vector3 = .{}, rotation: Quaternion = .{}) {
//     use_shader(*default_shader3);

//     projection := make_frustum_matrix(-1.92, 1.92, -1.08, 1.08, 1.4, -1.4);
//     model := make_translation_matrix4(position); // Matrix4_Identity;
//     view := koda.transform;

//     set_uniform(*default_shader3, "projection", projection);
//     set_uniform(*default_shader3, "model", model);
//     set_uniform(*default_shader3, "view", view);

//     for i: 0..mesh.materials.count - 1 {
//         glActiveTexture(xx (GL_TEXTURE0 + i));
//         glBindTexture(GL_TEXTURE_2D, mesh.materials[i].texture.texture);

//         set_uniform(*default_shader, tprint("uTexture%", i), i);
//     }
//     glActiveTexture(GL_TEXTURE0);

//     glBindVertexArray(mesh.geometry.vao_);
//     glDrawElements(GL_TRIANGLES, xx mesh.geometry.vertex_indices.count, GL_UNSIGNED_INT, xx 0);
//     glBindVertexArray(0);
//     glBindTexture(GL_TEXTURE_2D, 0);
// }
