PanoramicMap :: struct {
    geometry: *Geometry;
    uniforms: ShaderUniforms;
}

create_panoramic_map :: (texture: Texture, should_upload: bool = true) -> *PanoramicMap {
    panoramic := New(PanoramicMap);
    panoramic.geometry = create_uv_sphere(100, 32, with_texcoords = true);
    panoramic.uniforms[xx "uTexture0"] = create_uniform("uTexture0", texture);

    if should_upload {
        upload(panoramic);
    }

    return panoramic;
}

load_panoramic_map :: (path: string, should_upload: bool = true) -> *PanoramicMap {
    panoramic := New(PanoramicMap);
    panoramic.geometry = create_uv_sphere(100, 32, with_texcoords = true);
    panoramic.uniforms[xx "uTexture0"] = create_uniform("uTexture0", load_texture(path));

    if should_upload {
        upload(panoramic);
    }
    
    return panoramic;
}

upload :: (panoramic: *PanoramicMap) {
    upload(panoramic.geometry);

    for *uniform: panoramic.uniforms.uniforms {
        if uniform.type == .Texture {
            upload(*uniform.texture);
        } else if uniform.type == .Texture3 {
            upload(*uniform.texture3);
        }
    }
}

unload :: (panoramic: *PanoramicMap) {
    unload(panoramic.geometry);

    for *uniform: panoramic.uniforms.uniforms {
        if uniform.type == .Texture {
            unload(*uniform.texture);
        } else if uniform.type == .Texture3 {
            unload(*uniform.texture3);
        }
    }
}

draw :: (panoramic: *PanoramicMap) {
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
    uniforms[xx "projection"] = create_uniform("projection", get_perspective_matrix());
    uniforms[xx "model"] = create_uniform("model", Matrix4Identity);
    uniforms[xx "view"] = create_uniform("view", view);
    
    apply_uniforms(*texture_shader3, uniforms);
    apply_uniforms(*texture_shader3, panoramic.uniforms);

    glBindVertexArray(panoramic.geometry.vao_);
    glDrawElements(GL_TRIANGLES, xx panoramic.geometry.indices.count, GL_UNSIGNED_INT, xx 0);
    glBindVertexArray(0);
}
