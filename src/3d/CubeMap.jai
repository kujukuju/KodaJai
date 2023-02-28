CubeMap :: struct {
    geometry: *Geometry;
    uniforms: ShaderUniforms;
}

create_cube_map :: (texture: Texture) -> *CubeMap {
    cube := New(CubeMap);
    cube.geometry = create_cube(.{1.0, 1.0, 1.0}, with_unwrapped_texcoords = true);
    cube.uniforms["uTexture0"] = create_uniform("uTexture0", texture);
    return cube;
}

load_cube_map :: (path: string) -> *CubeMap {
    cube := New(CubeMap);
    cube.geometry = create_cube(.{1.0, 1.0, 1.0}, with_unwrapped_texcoords = true);
    cube.uniforms["uTexture0"] = create_uniform("uTexture0", load_texture(path));
    return cube;
}

draw :: (cube: *CubeMap) {
    depth_test := get_depth_test();
    defer set_depth_test(depth_test);
    set_depth_test(false);

    cull_face := get_cull_face();
    defer set_cull_face(cull_face);
    set_cull_face(false);

    use_shader(*texture_shader3);

    rotation := get_rotation(koda.view);
    view := rotation_matrix(Matrix4, rotation);

    uniforms: ShaderUniforms;
    defer destroy(uniforms);
    uniforms["projection"] = create_uniform("projection", get_perspective_matrix());
    uniforms["model"] = create_uniform("model", Matrix4Identity);
    uniforms["view"] = create_uniform("view", view);
    
    apply_uniforms(*texture_shader3, uniforms);
    apply_uniforms(*texture_shader3, cube.uniforms);

    glBindVertexArray(cube.geometry.vao_);
    glDrawElements(GL_TRIANGLES, xx cube.geometry.indices.count, GL_UNSIGNED_INT, xx 0);
    glBindVertexArray(0);
}
