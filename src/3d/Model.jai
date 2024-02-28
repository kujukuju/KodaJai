Model :: struct {
    using #as renderable: Renderable;
    renderable.type = .Model;
    geometry: [..] *Geometry;
    uniforms: ShaderUniforms;
    position: Vector3;
    rotation: Quaternion;
    scale: Vector3 = .{1, 1, 1};
    cull_face: bool = true;
    shader: *Shader;
    name: string;
    visible: bool = true;
}

SerializedModelHash :: struct {
    hash: u32;
    size: s64;
}

SerializedModel :: struct {
    validity_hash: SerializedModelHash;
    models: [..] *Model;
}

operator == :: (a: Model, b: Model) -> bool {
    return a.geometry.data == b.geometry.data && a.uniforms == b.uniforms;
}

// this is temporary I guess
should_bake_material_color_textures := false;

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
    model.uniforms[xx "uTexture0"] = create_uniform("uTexture0", texture);

    if should_upload {
        upload(model);
    }
    
    return model;
}

create_model :: (geometry: [] *Geometry, texture: Texture, should_upload: bool = true) -> *Model {
    model := New(Model);
    array_copy(*model.geometry, geometry);
    model.uniforms[xx "uTexture0"] = create_uniform("uTexture0", texture);

    if should_upload {
        upload(model);
    }

    return model;
}

load_model :: (path: string, should_upload: bool = true) -> *Model, bool {
    models, success := load_models(path, should_upload);
    defer array_free(models);
    if !success {
        return null, false;
    }

    assert(models.count == 1, "You cannot load more than 1 model with the load_model function. Memory leak!");

    return models[0], true;
}

load_models :: (path: string, should_upload: bool = true) -> [..] *Model, bool {
    file, success := read_entire_file(path);
    defer free(file);
    if !success {
        empty: [..] *Model;
        return empty, false;
    }

    if ends_with(path, ".obj") {
        models, success := load_model_obj(file, should_upload);
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
        models, success := load_model_glb(file, should_upload);
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
        models, success := load_model_gltf(file, path, should_upload);
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

    // TODO This is bad bc it doesnt force me to expand the list per uniform
    for *uniform: model.uniforms.uniforms {
        if uniform.type == .Texture {
            unload(*uniform.texture);
        } else if uniform.type == .Texture3 {
            unload(*uniform.texture3);
        }
    }
}

destroy :: (model: *Model, children: bool = true) {
    if children {
        for geometry: model.geometry {
            destroy(geometry);
        }
    }
    // TODO should destroy textures here unless I move ownership later
    array_free(model.geometry);
    free(model.name);
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

    return transform_aabb(get_transform(model), aabb);
}

draw :: (model: Model, transform: Matrix4 = Matrix4Identity, shader: *Shader = null) {
    draw(model, transform, get_perspective_matrix(), shader);
}

draw :: (model: Model, transform: Matrix4 = Matrix4Identity, projection: Matrix4, shader: *Shader = null) {
    assert(koda.can_render, "Cannot currently make any draw calls.\n");
    
    if !model.visible {
        return;
    }

    // // TODO this is temporary to get vert colors working
    // if model.geometry.count > 0 && matches_attributes(model.geometry[0], .Position, .Normal, .Texcoord, .Color) {
    //     shader = *default_color_shader3;
    // } else if model.geometry.count > 0 && matches_attributes(model.geometry[0], .Position, .Normal, .Texcoord, .Texcoord) {
    //     shader = *occlusion_shader3;
    // } else if model.geometry.count > 0 && matches_attributes(model.geometry[0], .Position, .Normal, .Texcoord, .JointIndices, .JointWeights) {
    //     // TODO skinned joint shader
    //     assert(false, "Skinned joints not yet supported.");
    // } else if model.geometry.count > 0 && !matches_attributes(model.geometry[0], .Position, .Normal, .Texcoord) {
    //     print("Found invalid attribute combination. %\n", model.geometry[0].attributes);
    //     assert(false, "Found invalid attribute combination.");
    // }

    if model.geometry.count == 0 {
        return;
    }

    if shader == null {
        if model.shader {
            shader = model.shader;
        } else {
            shader = get_default_shader(model.geometry[0].attributes);
        }
    }

    if !shader {
        print("Could not find appropriate shader for model attributes. %\n", model.geometry[0].attributes);
    }
    assert(!!shader, "Could not find appropriate shader for model attributes.");

    // TODO shouldn't I leave it as it is?
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
    
    uniforms[xx "projection"] = create_uniform("projection", projection);
    uniforms[xx "model"] = create_uniform("model", model_mat);
    uniforms[xx "view"] = create_uniform("view", view);
    
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

load_model_obj :: (file: string, should_upload: bool) -> [..] *Model, bool {
    geometries, success := load_geometry_obj(file);
    defer array_free(geometries);
    if !success {
        empty: [..] *Model;
        return empty, false;
    }

    models: [..] *Model;
    array_reserve(*models, geometries.count);
    for geometry: geometries {
        model := create_model(geometry, get_white_texture(), should_upload);
        array_add(*models, model);
    }

    return models, true;
}

load_model_glb :: (file: string, should_upload: bool) -> [..] *Model, bool {
    json, binary, json_memory, valid := load_glb(file);
    defer free(json_memory);
    if !valid {
        empty: [..] *Model;
        return empty, false;
    }

    models, data_success := load_model_gltf_data(json, binary, should_upload);
    return models, data_success;
}

load_model_gltf :: (file: string, path: string, should_upload: bool) -> [..] *Model, bool {
    json, binary, json_memory, valid := load_gltf(file, path);
    defer free(json_memory);
    if !valid {
        empty: [..] *Model;
        return empty, false;
    }

    models, data_success := load_model_gltf_data(json, binary, should_upload);
    return models, data_success;
}

load_model_gltf_data :: (json: GltfJson, binary: [] u8, should_upload: bool) -> [..] *Model, bool {
    models: [..] *Model;

    geometries, geometry_success := load_geometry_gltf_data(json, binary);
    defer array_free(geometries);
    if !geometry_success {
        empty: [..] *Model;
        return empty, false;
    }

    array_reserve(*models, geometries.count);
    for geometry: geometries {
        model := create_model(geometry, should_upload);
        array_add(*models, model);
    }

    buffers := get_buffers(json, binary);
    defer array_free(buffers);

    bufferviews := get_bufferviews(json, buffers);
    defer array_free(bufferviews);

    model_index := 0;
    for node: json.nodes {
        if !node.mesh {
            continue;
        }

        mesh := json.meshes[<< node.mesh];
        
        for primitive: mesh.primitives {
            if !is_valid_primitive(primitive) {
                continue;
            }

            model := models[model_index];
            model_index += 1;

            if primitive.material {
                material := json.materials[<< primitive.material];

                model.cull_face = !material.doubleSided;
            }

            has_diffuse_texture := true;
            has_diffuse_texture = has_diffuse_texture && primitive.material;
            has_diffuse_texture = has_diffuse_texture && json.materials[primitive.material.*].pbrMetallicRoughness;
            has_diffuse_texture = has_diffuse_texture && json.materials[primitive.material.*].pbrMetallicRoughness.baseColorTexture;
            has_diffuse_texture = has_diffuse_texture && json.textures[json.materials[primitive.material.*].pbrMetallicRoughness.baseColorTexture.index].source;
            if has_diffuse_texture {
                material := json.materials[primitive.material.*];

                texture_name := material.name;
                assert(!!texture_name, "I thought materials always had to have a name...");
                
                texture_index := material.pbrMetallicRoughness.baseColorTexture.index;
                texture := get_texture(json, bufferviews, texture_index);

                assert(!has_uniform(model.uniforms, "uTexture0"), "Cannot already have a diffuse texture.");
                model.uniforms[xx "uTexture0"] = create_uniform("uTexture0", texture);
            } else if should_bake_material_color_textures {
                has_diffuse_color := !!primitive.material;
                has_diffuse_color = has_diffuse_color && json.materials[primitive.material.*].pbrMetallicRoughness;
                if has_diffuse_color {
                    material := json.materials[primitive.material.*];

                    texture_name := material.name;
                    assert(!!texture_name, "I thought materials always had to have a name...");

                    diffuse_color_values := material.pbrMetallicRoughness.baseColorFactor;
                    print("Could not find texture image for %. Baking a new texture from the diffuse color. %\n", texture_name.*, diffuse_color_values);

                    diffuse_color := color(diffuse_color_values[0], diffuse_color_values[1], diffuse_color_values[2], diffuse_color_values[3]);

                    texture_image := create_image(1, 1, .RGBA8);
                    draw_pixel(*texture_image, .{0, 0}, diffuse_color);

                    texture := create_texture(texture_image, interp = .Nearest);
                    assert(!has_uniform(model.uniforms, "uTexture0"), "Cannot already have a diffuse texture.");
                    model.uniforms[xx "uTexture0"] = create_uniform("uTexture0", texture);
                }
            }

            has_normal_texture := true;
            has_normal_texture = has_normal_texture && primitive.material;
            has_normal_texture = has_normal_texture && json.materials[primitive.material.*].normalTexture;
            has_normal_texture = has_normal_texture && json.textures[json.materials[primitive.material.*].normalTexture.index].source;
            if has_normal_texture {
                material := json.materials[primitive.material.*];
                model.cull_face = !material.doubleSided;

                texture_name := material.name;
                assert(!!texture_name, "I thought materials always had to have a name...");
                
                texture_index := material.normalTexture.index;
                texture := get_texture(json, bufferviews, texture_index);

                assert(!has_uniform(model.uniforms, "uNormal0"), "Cannot already have a normal texture.");
                model.uniforms[xx "uNormal0"] = create_uniform("uNormal0", texture);
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
            if node.name {
                model.name = copy_string(<< node.name);
            }
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
