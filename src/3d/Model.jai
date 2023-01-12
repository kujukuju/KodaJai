Model :: struct {
    using #as renderable: Renderable;
    renderable.type = .Model;
    geometry: [..] *Geometry;
    uniforms: ShaderUniforms;
    position: Vector3;
    rotation: Quaternion;
}

create_model :: (geometry: *Geometry) -> *Model {
    model := New(Model);
    array_resize(*model.geometry, 1);
    model.geometry[0] = geometry;
    return model;
}

create_model :: (geometry: [] *Geometry) -> *Model {
    model := New(Model);
    array_copy(*model.geometry, geometry);
    return model;
}

create_model :: (geometry: *Geometry, texture: Texture) -> *Model {
    model := New(Model);
    array_resize(*model.geometry, 1);
    model.geometry[0] = geometry;
    model.uniforms["uTexture0"] = create_uniform("uTexture0", texture);
    return model;
}

create_model :: (geometry: [] *Geometry, texture: Texture) -> *Model {
    model := New(Model);
    array_copy(*model.geometry, geometry);
    model.uniforms["uTexture0"] = create_uniform("uTexture0", texture);
    return model;
}

upload_model :: (model: *Model) {

}

unload_model :: (model: *Model) {

}

destroy :: (model: *Model) {
    
}

draw :: (model: Model, transform: Matrix4 = Matrix4Identity) {
    draw(model, transform, get_perspective_matrix());
}

draw :: (model: Model, transform: Matrix4 = Matrix4Identity, projection: Matrix4) {
    use_shader(*default_shader3);

    model_mat := transform * make_translation_matrix4(model.position);
    view := koda.view;

    apply_uniforms(*default_shader3, model.uniforms);

    uniforms: ShaderUniforms;
    defer free(uniforms);
    
    uniforms["projection"] = create_uniform("projection", projection);
    uniforms["model"] = create_uniform("model", model_mat);
    uniforms["view"] = create_uniform("view", view);
    
    apply_uniforms(*default_shader3, uniforms);

    for geometry: model.geometry {
        glBindVertexArray(geometry.vao_);
        glDrawElements(GL_TRIANGLES, xx geometry.indices.count, GL_UNSIGNED_INT, xx 0);
        glBindVertexArray(0);
    }
}