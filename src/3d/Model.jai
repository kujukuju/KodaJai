Model :: struct {
    using #as renderable: Renderable;
    renderable.type = .Model;
    geometry: [..] *Geometry;
    uniforms: ShaderUniforms;
    position: Vector3;
    rotation: Quaternion;
    scale: Vector3 = .{1, 1, 1};
    cull_face: bool = true;
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

load_model :: (path: string) -> [..] *Model, bool {
    file, success := read_entire_file(path);
    defer free(file);
    if !success {
        empty: [..] *Model;
        return empty, false;
    }

    if ends_with(path, ".obj") {
        models, success := load_model_obj(file);
        if !success {
            empty: [..] *Model;
            return empty, false;
        }

        return models, true;
    } else if ends_with(path, ".glb") {
        models, success := load_model_glb(file);
        if !success {
            empty: [..] *Model;
            return empty, false;
        }

        return models, true;
    } else if ends_with(path, ".gltf") {
        models, success := load_model_gltf(file, path);
        if !success {
            empty: [..] *Model;
            return empty, false;
        }

        return models, true;
    } else {
        print("Unknown file type. %\n", path);
        empty: [..] *Model;
        return empty, false;
    }
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
    matrix = scale(matrix, model.scale);
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

draw :: (model: Model, transform: Matrix4 = Matrix4Identity, shader: *Shader = null) {
    if !shader {
        shader = *default_shader3;
    }

    draw(model, transform, get_perspective_matrix(), shader);
}

draw :: (model: Model, transform: Matrix4 = Matrix4Identity, projection: Matrix4, shader: *Shader) {
    // TODO this is temporary to get vert colors working
    if model.geometry.count > 0 && model.geometry[0].has_normal && model.geometry[0].has_texcoord && model.geometry[0].has_color {
        shader = *default_color_shader3;
    }

    cull_face := koda.cull_face;
    if cull_face != model.cull_face {
        set_cull_face(model.cull_face);
    }

    use_shader(shader);

    model_mat := transform * get_transform(model);
    view := koda.view;

    apply_uniforms(shader, model.uniforms);

    uniforms: ShaderUniforms;
    defer destroy(uniforms);
    
    uniforms["projection"] = create_uniform("projection", projection);
    uniforms["model"] = create_uniform("model", model_mat);
    uniforms["view"] = create_uniform("view", view);
    
    apply_uniforms(shader, uniforms);

    for geometry: model.geometry {
        glBindVertexArray(geometry.vao_);
        glDrawElements(GL_TRIANGLES, xx geometry.indices.count, GL_UNSIGNED_INT, xx 0);
        glBindVertexArray(0);
    }

    // TODO if we could avoid calling this gain that would be best
    // TODO but theres no guarantee right now throught all of the koda code that this will be checked
    if cull_face != model.cull_face {
        set_cull_face(cull_face);
    }
}

#scope_module

load_model_obj :: (file: string) -> [..] *Model, bool {
    geometries, success := load_geometry_obj(file);
    defer array_free(geometries);
    if !success {
        empty: [..] *Model;
        return empty, false;
    }

    models: [..] *Model;

    array_reserve(*models, geometries.count);
    for geometry: geometries {
        model := create_model(geometry, get_white_texture());
        array_add(*models, model);
    }

    return models, true;
}

load_model_glb :: (file: string) -> [..] *Model, bool {
    json, binary, json_memory, valid := load_glb(file);
    defer free(json_memory);
    if !valid {
        empty: [..] *Model;
        return empty, false;
    }

    models, data_success := load_model_gltf_data(json, binary);
    return models, data_success;
}

load_model_gltf :: (file: string, path: string) -> [..] *Model, bool {
    json, binary, json_memory, valid := load_gltf(file, path);
    defer free(json_memory);
    if !valid {
        empty: [..] *Model;
        return empty, false;
    }

    models, data_success := load_model_gltf_data(json, binary);
    return models, data_success;
}

load_model_gltf_data :: (json: GltfJson, binary: [] u8) -> [..] *Model, bool {
    models: [..] *Model;

    geometries, geometry_success := load_geometry_gltf_data(json, binary);
    defer array_free(geometries);
    if !geometry_success {
        empty: [..] *Model;
        return empty, false;
    }

    array_reserve(*models, geometries.count);
    for geometry: geometries {
        model := create_model(geometry);
        array_add(*models, model);
    }

    buffers: [..] [] u8;
    defer array_free(buffers);
    offset := 0;
    for buffer: json.buffers {
        current := array_add(*buffers);
        current.data = binary.data + offset;
        current.count = buffer.byteLength;

        offset += buffer.byteLength;
    }

    bufferviews: [..] [] u8;
    defer array_free(bufferviews);
    for bufferview: json.bufferViews {
        buffer_index := bufferview.buffer;

        current := array_add(*bufferviews);
        current.data = buffers[buffer_index].data + bufferview.byteOffset;
        current.count = bufferview.byteLength;
    }

    index := 0;
    for mesh: json.meshes {
        for primitive: mesh.primitives {
            if !is_valid_primitive(primitive) {
                continue;
            }

            model := models[index];
            index += 1;

            has_texture := true;
            has_texture = has_texture && primitive.material;
            has_texture = has_texture && json.materials[<< primitive.material].pbrMetallicRoughness;
            has_texture = has_texture && json.materials[<< primitive.material].pbrMetallicRoughness.baseColorTexture;
            has_texture = has_texture && json.textures[json.materials[<< primitive.material].pbrMetallicRoughness.baseColorTexture.index].source;
            if !has_texture {
                model.uniforms["uTexture0"] = create_uniform("uTexture0", get_white_texture());
                continue;
            }

            material := json.materials[<< primitive.material];
            print("material %\n", material);
            model.cull_face = !material.doubleSided;

            texture_name := material.name;
            assert(!!texture_name, "I thought materials always had to have a name...");

            // TODO try to get the texture here

            texture_index := material.pbrMetallicRoughness.baseColorTexture.index;
            texture_number := material.pbrMetallicRoughness.baseColorTexture.texCoord;
            json_texture := json.textures[texture_index];

            // this has to do with repeat/clamp/etc
            sampler := json_texture.sampler;
            source := json_texture.source;

            json_image := json.images[<< source];

            texture: Texture;
            if json_image.uri {
                texture = load_texture(<< json_image.uri);
            } else if json_image.bufferView {
                view_index := << json_image.bufferView;
                buffer_view := bufferviews[view_index];
                texture = create_texture(buffer_view);
            } else {
                assert(false, "I think you have to have either an image uri or buffer.");
            }

            if texture_number == {
                case 0;
                    model.uniforms["uTexture0"] = create_uniform("uTexture0", texture);
                // case 1;
                //     model.uniforms["uTexture1"] = create_uniform("uTexture1", get_white_texture());
                case;
                    print("Texcoord % not supported.", texture_number);
                    assert(false, "Texcoord not supported.");
            }
        }
    }

    for node: json.nodes {
        if node.mesh {
            mesh_index := << node.mesh;
            model: *Model;
            
            current_mesh_index := 0;
            current_model_index := 0;
            for mesh: json.meshes {
                for primitive: mesh.primitives {
                    if !is_valid_primitive(primitive) {
                        continue;
                    }

                    if current_mesh_index == mesh_index {
                        model = models[current_model_index];
                        break mesh;
                    }

                    current_model_index += 1;
                }

                current_mesh_index += 1;
            }

            assert(!!model, "The loop must have found the model by this point.");
            model.position.component = node.translation;
            model.rotation.component = node.rotation;
            model.scale.component = node.scale;
        } else {
            assert(equal(node.matrix, float.[1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]), "A non mesh transform must be identity because I don't know what this implies.");
        }
    }

    return models, true;
}

#scope_file

equal :: (a: [] float, b: [] float) -> bool {
    if a.count != b.count {
        return false;
    }

    for i: 0..a.count - 1 {
        if a[i] != b[i] {
            return false;
        }
    }

    return true;
}
