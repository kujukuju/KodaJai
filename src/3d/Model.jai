Model :: struct {
    using #as renderable: Renderable;
    renderable.type = .Model;
    geometry: [..] *Geometry;
    uniforms: ShaderUniforms;
    position: Vector3;
    rotation: Quaternion;
}

operator == :: (a: Model, b: Model) -> bool {
    return a.geometry.data == b.geometry.data && a.uniforms == b.uniforms;
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
    for geometry: model.geometry {
        destroy(geometry);
    }
    array_free(model.geometry);
    free(model);
}

get_transform :: (model: Model) -> Matrix4 {
    matrix := Matrix4Identity;
    matrix = translate(matrix, model.position);
    matrix = rotate(matrix, model.rotation);
    return matrix;
}

get_aabb :: (model: Model) -> AABB3 {
    if model.geometry.count == 0 {
        return .{};
    }

    aabb: AABB3 = model.geometry[0].aabb;
    for i: 1..model.geometry.count - 1 {
        aabb = merge(aabb, model.geometry[i].aabb);
    }

    return aabb;
}

draw :: (model: Model, transform: Matrix4 = Matrix4Identity) {
    draw(model, transform, get_perspective_matrix());
}

draw :: (model: Model, transform: Matrix4 = Matrix4Identity, projection: Matrix4) {
    use_shader(*default_shader3);

    model_mat := transform * get_transform(model);
    view := koda.view;

    apply_uniforms(*default_shader3, model.uniforms);

    uniforms: ShaderUniforms;
    defer destroy(uniforms);
    
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