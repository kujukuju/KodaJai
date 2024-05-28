
// TODO should just be using #as model: Model;
CubeMap :: struct {
    geometry: *Geometry;
    uniforms: ShaderUniforms;
    transform: Matrix4 = Matrix4Identity;
    shader: *Shader;
}

create_cube_map :: (half_width: float = 1.0, should_upload: bool = false) -> *CubeMap {
    cube := New(CubeMap);
    cube.geometry = create_cube(.{half_width, half_width, half_width});

    if should_upload {
        upload(cube);
    }

    return cube;
}

create_cube_map :: (texture: CubemapTexture, half_width: float = 1.0, should_upload: bool = false) -> *CubeMap {
    cube := create_cubemap(half_width, should_upload);
    set(*cube.uniforms, "uTexture0", texture);

    return cube;
}

load_cube_map :: (path: string, half_width: float = 1.0, should_upload: bool = true) -> *CubeMap {
    cube := create_cubemap(half_width, should_upload);
    set(*cube.uniforms, "uTexture0", load_cubemap_texture(path));

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
    set_cull_face_scope(false);

    shader := cube.shader;
    if !shader {
        shader = *cubemap_shader;
    }

    use_shader(shader);

    rotation := get_rotation(koda.view);
    model := cube.transform;
    view := rotation_matrix(Matrix4, rotation);
    projection := get_perspective_matrix();

    uniforms: ShaderUniforms;
    defer destroy(uniforms);

    model_view_projection := projection * view * model;
    set(*uniforms, "modelViewProjection", model_view_projection);
    set(*uniforms, "projection", projection);
    set(*uniforms, "model", model);
    set(*uniforms, "view", view);
    
    apply_uniforms(shader, uniforms);
    apply_uniforms(shader, cube.uniforms);

    glBindVertexArray(cube.geometry.vao_);
    glDrawElements(GL_TRIANGLES, xx cube.geometry.indices.count, GL_UNSIGNED_INT, xx 0);
    glBindVertexArray(0);
}
