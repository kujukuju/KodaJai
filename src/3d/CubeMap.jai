CubeMap :: struct {
    geometry: *Geometry;
    uniforms: ShaderUniforms;
    transform: Matrix4 = Matrix4Identity;
}

create_cube_map :: (texture: CubemapTexture, should_upload: bool = true) -> *CubeMap {
    cube := New(CubeMap);
    cube.geometry = create_cube(.{1.0, 1.0, 1.0});
    cube.uniforms["uTexture0"] = create_uniform("uTexture0", texture);

    if should_upload {
        upload(cube);
    }

    return cube;
}

load_cube_map :: (path: string, should_upload: bool = true) -> *CubeMap {
    cube := New(CubeMap);
    cube.geometry = create_cube(.{1.0, 1.0, 1.0});
    cube.uniforms["uTexture0"] = create_uniform("uTexture0", load_cubemap_texture(path));

    if should_upload {
        upload(cube);
    }

    return cube;
}

upload :: (cube: *CubeMap) {
    upload(cube.geometry);

    for *uniform: cube.uniforms.uniforms {
        if uniform.type == .Texture {
            upload(*uniform.texture);
        } else if uniform.type == .Texture3 {
            upload(*uniform.texture3);
        } else if uniform.type == .CubemapTexture {
            upload(*uniform.cubemap_texture);
        }
    }
}

unload :: (cube: *CubeMap) {
    unload(cube.geometry);

    for *uniform: cube.uniforms.uniforms {
        if uniform.type == .Texture {
            unload(*uniform.texture);
        } else if uniform.type == .Texture3 {
            unload(*uniform.texture3);
        } else if uniform.type == .CubemapTexture {
            unload(*uniform.cubemap_texture);
        }
    }
}

draw :: (cube: *CubeMap) {
    depth_test := get_depth_test();
    defer set_depth_test(depth_test);
    set_depth_test(false);

    cull_face := get_cull_face();
    defer set_cull_face(cull_face);
    set_cull_face(false);

    use_shader(*cubemap_shader);

    rotation := get_rotation(koda.view);
    view := rotation_matrix(Matrix4, rotation);

    uniforms: ShaderUniforms;
    defer destroy(uniforms);
    uniforms["projection"] = create_uniform("projection", get_perspective_matrix());
    uniforms["model"] = create_uniform("model", cube.transform);
    uniforms["view"] = create_uniform("view", view);
    
    apply_uniforms(*cubemap_shader, uniforms);
    apply_uniforms(*cubemap_shader, cube.uniforms);

    glBindVertexArray(cube.geometry.vao_);
    glDrawElements(GL_TRIANGLES, xx cube.geometry.indices.count, GL_UNSIGNED_INT, xx 0);
    glBindVertexArray(0);
}
