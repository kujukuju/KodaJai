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

create_model :: (geometry: *Geometry, should_upload: bool = true) -> *Model {
    model := New(Model);
    array_resize(*model.geometry, 1);
    model.geometry[0] = geometry;

    if should_upload {
        upload(model);
    }

    return model;
}

create_model :: (geometry: [] *Geometry, should_upload: bool = true) -> *Model {
    model := New(Model);
    array_copy(*model.geometry, geometry);

    if should_upload {
        upload(model);
    }

    return model;
}

create_model :: (geometry: *Geometry, texture: Texture, should_upload: bool = true) -> *Model {
    model := New(Model);
    array_resize(*model.geometry, 1);
    model.geometry[0] = geometry;
    model.uniforms["uTexture0"] = create_uniform("uTexture0", texture);

    if should_upload {
        upload(model);
    }
    
    return model;
}

create_model :: (geometry: [] *Geometry, texture: Texture, should_upload: bool = true) -> *Model {
    model := New(Model);
    array_copy(*model.geometry, geometry);
    model.uniforms["uTexture0"] = create_uniform("uTexture0", texture);

    if should_upload {
        upload(model);
    }

    return model;
}

load_model :: (path: string, should_upload: bool = true) -> [..] *Model, bool {
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

        if should_upload {
            for model: models {
                upload(model);
            }
        }

        return models, true;
    } else if ends_with(path, ".glb") {
        models, success := load_model_glb(file);
        if !success {
            empty: [..] *Model;
            return empty, false;
        }

        if should_upload {
            for model: models {
                upload(model);
            }
        }

        return models, true;
    } else if ends_with(path, ".gltf") {
        models, success := load_model_gltf(file, path);
        if !success {
            empty: [..] *Model;
            return empty, false;
        }

        if should_upload {
            for model: models {
                upload(model);
            }
        }

        return models, true;
    } else {
        print("Unknown file type. %\n", path);
        empty: [..] *Model;
        return empty, false;
    }
}

upload :: (model: *Model) {
    for geometry: model.geometry {
        upload(geometry);
    }

    for *uniform: model.uniforms.uniforms {
        if uniform.type == .Texture {
            upload(*uniform.texture);
        } else if uniform.type == .Texture3 {
            upload(*uniform.texture3);
        }
    }
}

unload :: (model: *Model) {
    for geometry: model.geometry {
        unload(geometry);
    }

    for *uniform: model.uniforms.uniforms {
        if uniform.type == .Texture {
            unload(*uniform.texture);
        } else if uniform.type == .Texture3 {
            unload(*uniform.texture3);
        }
    }
}

destroy :: (model: *Model) {
    for geometry: model.geometry {
        destroy(geometry);
    }
    // TODO should destroy textures here unless I move ownership later
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
    if model.geometry.count > 0 && matches_attributes(model.geometry[0], .Position, .Normal, .Texcoord, .Color) {
        shader = *default_color_shader3;
    } else if model.geometry.count > 0 && matches_attributes(model.geometry[0], .Position, .Normal, .Texcoord, .Texcoord) {
        shader = *occlusion_shader3;
    } else if model.geometry.count > 0 && matches_attributes(model.geometry[0], .Position, .Normal, .Texcoord, .JointIndices, .JointWeights) {
        // TODO skinned joint shader
        assert(false, "Skinned joints not yet supported.");
    } else if model.geometry.count > 0 && !matches_attributes(model.geometry[0], .Position, .Normal, .Texcoord) {
        print("Found invalid attribute combination. %\n", model.geometry[0].attributes);
        assert(false, "Found invalid attribute combination.");
    }

    if model.geometry.count == 0 {
        return;
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

    buffers := get_buffers(json, binary);
    defer array_free(buffers);

    bufferviews := get_bufferviews(json, buffers);
    defer array_free(bufferviews);

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

    node_parents: Table(int, int);
    node_parents.allocator = temp;

    for node, node_index: json.nodes {
        if node.children {
            for i: 0..node.children.count - 1 {
                child_index := node.children.data[i];

                assert(!table_find_pointer(*node_parents, child_index), "Attempting to double set a node parent.");
                table_set(*node_parents, child_index, node_index);
            }
        }
    }

    // node_path: [..] int;
    // node_path.allocator = temp;

    for node, node_index: json.nodes {
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

            // node_path.count = 0;

            // array_add(*node_path, node_index);
            // parent_node_pointer := table_find_pointer(*node_parents, node_index);
            // while !!parent_node_pointer {
            //     array_add(*node_path, << parent_node_pointer);
            //     parent_node_pointer = table_find_pointer(*node_parents, << parent_node_pointer);
            // }

            // world_transform := Matrix4Identity;
            // for < current_index: node_path {
            //     node := json.nodes[current_index];

            //     node_matrix := get_transform(node);
            //     world_transform = world_transform * node_matrix;
            // }

            // translation, rotation, scale := decompose_matrix4(world_transform);

            model.position.component = node.translation;
            model.rotation.component = node.rotation;
            model.scale.component = node.scale;
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
