
Model :: struct {
    using #as renderable: Renderable;
    renderable.type = .Model;
    geometry: *Geometry;
    uniforms: ShaderUniforms;
    position: Vector3;
    rotation: Quaternion;
    scale: Vector3 = .{1, 1, 1};
    cull_face: bool = true;
    shader: *Shader;
    name: string;
    visible: bool = true;
    // this basically does nothing right now but tracks the material
    material_id: int;
    properties: [..] [2] string;
    // temporary until materials exist
    material_properties: [..] [2] string;
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
    return a.geometry == b.geometry && equals(a.uniforms, b.uniforms);
}

// this is temporary I guess
should_bake_material_color_textures := false;

create_model :: (geometry: *Geometry, should_upload: bool = true) -> *Model {
    model := New(Model);
    model.geometry = geometry;

    if should_upload {
        upload(model);
    }

    return model;
}

create_model :: (geometry: *Geometry, texture: Texture, should_upload: bool = true) -> *Model {
    model := New(Model);
    model.geometry = geometry;
    set(*model.uniforms, "uTexture0", texture);

    if should_upload {
        upload(model);
    }
    
    return model;
}

load_model :: (path: string, should_upload: bool = true) -> *Model, bool {
    models, instances, success := load_models(path, should_upload);
    defer array_free(models);
    defer array_free(instances);
    if !success {
        return null, false;
    }

    assert(models.count == 1, "You cannot load more than 1 model with the load_model function. Memory leak!");
    assert(instances.count == 0, "You cannot load instanced models with the load_model function.");

    return models[0], true;
}

load_models :: (path: string, should_upload: bool = true) -> [..] *Model, [..] *InstancedModel(ModelMatrixGpu), bool #must /* temporary #must since I added a return */ {
    file, success := read_entire_file(path);
    defer free(file);
    if !success {
        empty_models: [..] *Model;
        empty_instances: [..] *InstancedModel;
        return empty_models, empty_instances, false;
    }

    if ends_with(path, ".obj") {
        models, success := load_model_obj(file, should_upload);
        if !success {
            empty_models: [..] *Model;
            empty_instances: [..] *InstancedModel;
            return empty_models, empty_instances, false;
        }

        instances: [..] *InstancedModel;

        return models, instances, true;
    } else if ends_with(path, ".glb") {
        models, instances, success := load_model_glb(file, should_upload);
        if !success {
            empty_models: [..] *Model;
            empty_instances: [..] *InstancedModel;
            return empty_models, empty_instances, false;
        }

        return models, instances, true;
    } else if ends_with(path, ".gltf") {
        models, instances, success := load_model_gltf(file, path, should_upload);
        if !success {
            empty_models: [..] *Model;
            empty_instances: [..] *InstancedModel;
            return empty_models, empty_instances, false;
        }

        return models, instances, true;
    } else {
        print("Unknown file type. %\n", path);
        empty_models: [..] *Model;
        empty_instances: [..] *InstancedModel;
        return empty_models, empty_instances, false;
    }
}

upload :: (model: *Model) {
    upload(model.geometry);

    for *uniform: model.uniforms {
        if uniform.type == .Texture {
            upload(*uniform.texture);
        } else if uniform.type == .Texture3 {
            upload(*uniform.texture3);
        }
    }
}

unload :: (model: *Model) {
    unload(model.geometry);

    // TODO This is bad bc it doesnt force me to expand the list per uniform
    for *uniform: model.uniforms {
        if uniform.type == .Texture {
            unload(*uniform.texture);
        } else if uniform.type == .Texture3 {
            unload(*uniform.texture3);
        }
    }
}

destroy :: (model: *Model, children: bool = true) {
    if children {
        destroy(model.geometry);
    }
    for property: model.properties {
        free(property[0]);
        free(property[1]);
    }
    array_free(model.properties);
    for property: model.material_properties {
        free(property[0]);
        free(property[1]);
    }
    array_free(model.material_properties);
    destroy(model.uniforms);
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
    aabb := model.geometry.aabb;

    return transform_aabb(get_transform(model), aabb);
}

get_bounding_sphere :: (model: Model) -> Sphere {
    sphere := model.geometry.bounding_sphere;

    sphere.center = transform_point(get_transform(model), sphere.center);
    sphere.radius *= max(model.scale.x, model.scale.y, model.scale.z);

    return sphere;
}

get_local_aabb :: (model: Model) -> AABB3 {
    return model.geometry.aabb;
}

// get_bounding_sphere :: (model: Model) -> Sphere {
// }

ModelVertices :: struct {
    model: *Model;
}

get_vertices :: (model: *Model) -> ModelVertices {
    assert(model.geometry.attributes.count > 0);
    assert(model.geometry.attributes[0] == .Position);

    return ModelVertices.{model};
}

for_expansion :: (wrapper: ModelVertices, body: Code, flags: For_Flags) #expand {
    #assert(!(flags & .REVERSE));
    #assert(!(flags & .POINTER));

    stride := get_attribute_stride(wrapper.model.geometry);

    transform := get_transform(wrapper.model);
    geometry := wrapper.model.geometry;

    vertex_count := geometry.vertices.count / stride;
    for i: 0..vertex_count - 1 {
        position := Vector3.{geometry.vertices[i * stride], geometry.vertices[i * stride + 1], geometry.vertices[i * stride + 2]};
        `it := transform_point(transform, position);
        `it_index := i;

        #insert body;
    }
}

ModelTriangles :: struct {
    model: *Model;
}

get_triangles :: (model: *Model) -> ModelTriangles {
    assert(model.geometry.attributes.count > 0);
    assert(model.geometry.attributes[0] == .Position);

    return ModelTriangles.{model};
}

for_expansion :: (wrapper: ModelTriangles, body: Code, flags: For_Flags) #expand {
    #assert(!(flags & .REVERSE));
    #assert(!(flags & .POINTER));

    stride := get_attribute_stride(wrapper.model.geometry);

    transform := get_transform(wrapper.model);
    geometry := wrapper.model.geometry;

    triangle_count := geometry.indices.count / 3;
    for i: 0..triangle_count - 1 {
        index1 := geometry.indices[i * 3];
        index2 := geometry.indices[i * 3 + 1];
        index3 := geometry.indices[i * 3 + 2];

        position1 := Vector3.{geometry.vertices[index1 * stride], geometry.vertices[index1 * stride + 1], geometry.vertices[index1 * stride + 2]};
        position2 := Vector3.{geometry.vertices[index2 * stride], geometry.vertices[index2 * stride + 1], geometry.vertices[index2 * stride + 2]};
        position3 := Vector3.{geometry.vertices[index3 * stride], geometry.vertices[index3 * stride + 1], geometry.vertices[index3 * stride + 2]};

        triangle := Triangle3.{
            transform_point(transform, position1),
            transform_point(transform, position2),
            transform_point(transform, position3),
        };
        `it := triangle;
        `it_index := i;
        
        #insert body;
    }
}

merge_by_material_id :: (models: [] *Model, should_upload: bool = true) -> [..] *Model {
    material_models: Table(int, [..] *Model);
    material_models.allocator = temp;

    material_ids: [..] int;
    material_ids.allocator = temp;

    for model: models {
        material_array, created := find_or_add(*material_models, model.material_id);

        if created {
            material_array.allocator = temp;
            array_add(*material_ids, model.material_id);
        }

        array_add(material_array, model);
    }

    merged: [..] *Model;

    for material_id: material_ids {
        models, found := table_find(*material_models, material_id);
        if !found {
            continue;
        }

        if models.count == 1 {
            geometry := New(Geometry);
            array_copy(*geometry.vertices, models[0].geometry.vertices);
            array_copy(*geometry.indices, models[0].geometry.indices);
            array_copy(*geometry.attributes, models[0].geometry.attributes);
            geometry.aabb = calculate_aabb(geometry);
            geometry.bounding_sphere = calculate_bounding_sphere(get_vertices(geometry));
            created := create_model(geometry, should_upload = false);
            created.position = models[0].position;
            created.rotation = models[0].rotation;
            created.scale = models[0].scale;
            if models[0].name {
                created.name = copy_string(models[0].name);
            }
            created.uniforms = copy(models[0].uniforms);
            for property: models[0].properties {
                array_add(*created.properties, .[copy_string(property[0]), copy_string(property[1])]);
            }
            for property: models[0].material_properties {
                array_add(*created.material_properties, .[copy_string(property[0]), copy_string(property[1])]);
            }
            array_add(*merged, created);

            continue;
        }

        for i: 0..models.count - 2 {
            current := models[i];
            next := models[i + 1];

            if !matches_attributes(current.geometry.attributes, next.geometry.attributes) {
                assert(false, tprint("You cannot merge models with mismatched attributes. %: % != %: %\n", current.name, current.geometry.attributes, next.name, next.geometry.attributes));
            }
            if !equals(current.uniforms, next.uniforms) {
                print("Warning: Merging models with different uniforms. % %\n", current.name, next.name);
            }
        }

        total_vertices: int;
        total_indices: int;
        for model: models {
            total_vertices += model.geometry.vertices.count;
            total_indices += model.geometry.indices.count;
        }

        geometry := New(Geometry);
        array_reserve(*geometry.vertices, total_vertices);
        array_reserve(*geometry.indices, total_indices);
        array_copy(*geometry.attributes, models[0].geometry.attributes);

        stride := get_attribute_stride(geometry);

        for model: models {
            transform := get_transform(model);
            normal_transform := transpose(inverse(transform));

            index_offset := cast(u32) (geometry.vertices.count / stride);
            vertex_count := model.geometry.vertices.count / stride;
            
            offset := 0;
            for i: 0..vertex_count - 1 {
                for attribute: model.geometry.attributes {
                    if attribute == .Position {
                        position := (cast(*Vector3) (model.geometry.vertices.data + offset)).*;
                        position = transform_point(transform, position);
                        array_add(*geometry.vertices, position.x, position.y, position.z);

                        offset += 3;
                    } else if attribute == .Normal {
                        normal := (cast(*Vector3) (model.geometry.vertices.data + offset)).*;
                        normal = transform_vector(normal_transform, normal);
                        array_add(*geometry.vertices, normal.x, normal.y, normal.z);

                        offset += 3;
                    } else {
                        floats: [] float;
                        floats.data = model.geometry.vertices.data + offset;
                        floats.count = get_attribute_size(attribute);
                        array_add(*geometry.vertices, ..floats);

                        offset += floats.count;
                    }
                }
            }
            assert(offset == model.geometry.vertices.count, "Unexpected vertex count.\n");

            for i: 0..model.geometry.indices.count - 1 {
                (geometry.indices.data + geometry.indices.count + i).* = model.geometry.indices[i] + index_offset;
            }
            geometry.indices.count += model.geometry.indices.count;
        }

        geometry.aabb = calculate_aabb(geometry);
        geometry.bounding_sphere = calculate_bounding_sphere(get_vertices(geometry));

        created := create_model(geometry, should_upload = false);
        if models[0].name {
            created.name = copy_string(models[0].name);
        }
        created.uniforms = copy(models[0].uniforms);
        for property: models[0].properties {
            array_add(*created.properties, .[copy_string(property[0]), copy_string(property[1])]);
        }
        for property: models[0].material_properties {
            array_add(*created.material_properties, .[copy_string(property[0]), copy_string(property[1])]);
        }

        array_add(*merged, created);
    }

    if should_upload {
        for model: merged {
            upload(model);
        }
    }

    return merged;
}

draw :: (model: Model, transform: Matrix4 = Matrix4Identity, shader: *Shader = null) {
    draw(model, transform, get_perspective_matrix(), shader);
}

draw :: (model: Model, transform: Matrix4 = Matrix4Identity, projection: Matrix4, shader: *Shader = null) {
    assert(koda.can_render, "Cannot currently make any draw calls.\n");
    
    if !model.visible {
        return;
    }

    if shader == null {
        if model.shader {
            shader = model.shader;
        } else {
            shader = get_default_shader(model.geometry.attributes);
        }
    }
    assert(!!shader, "Could not find appropriate shader for model attributes. % %\n", model.name, model.geometry.attributes);

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

    model_view := view * model_mat;
    model_view_projection := projection * model_view;
    set(*uniforms, "modelViewProjection", model_view_projection);
    set(*uniforms, "modelView", model_view);
    set(*uniforms, "projection", projection);
    set(*uniforms, "model", model_mat);
    set(*uniforms, "view", view);
    
    apply_uniforms(shader, uniforms);

    glBindVertexArray(model.geometry.vao_);
    glDrawElements(GL_TRIANGLES, xx model.geometry.indices.count, GL_UNSIGNED_INT, xx 0);
    glBindVertexArray(0);

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
        model := create_model(geometry, get_white_texture(), should_upload = should_upload);
        array_add(*models, model);
    }

    return models, true;
}

load_model_glb :: (file: string, should_upload: bool) -> [..] *Model, [..] *InstancedModel(ModelMatrixGpu), bool {
    json, binary, json_memory, valid := load_glb(file);
    defer free(json_memory);
    if !valid {
        empty_models: [..] *Model;
        empty_instances: [..] *InstancedModel;
        return empty_models, empty_instances, false;
    }

    models, instanced, data_success := load_model_gltf_data(json, binary, should_upload);
    return models, instanced, data_success;
}

load_model_gltf :: (file: string, path: string, should_upload: bool) -> [..] *Model, [..] *InstancedModel(ModelMatrixGpu), bool {
    json, binary, json_memory, valid := load_gltf(file, path);
    defer free(json_memory);
    if !valid {
        empty_models: [..] *Model;
        empty_instances: [..] *InstancedModel;
        return empty_models, empty_instances, false;
    }

    models, instanced, data_success := load_model_gltf_data(json, binary, should_upload);
    return models, instanced, data_success;
}

load_model_gltf_data :: (json: GltfJson, binary: [] u8, should_upload: bool) -> [..] *Model, [..] *InstancedModel(ModelMatrixGpu), bool {
    models: [..] *Model;
    instances: [..] *InstancedModel;

    geometry_to_primitive: [..] *GltfJson.GltfJsonMesh.GltfJsonMeshPrimitive;
    geometry_to_primitive.allocator = temp;

    geometry_to_mesh: [..] int;
    geometry_to_mesh.allocator = temp;

    primitive_to_geometry: Table(*GltfJson.GltfJsonMesh.GltfJsonMeshPrimitive, int);
    primitive_to_geometry.allocator = temp;

    geometries, geometry_success := load_geometry_gltf_data(json, binary, *geometry_to_primitive, *geometry_to_mesh, *primitive_to_geometry);
    defer array_free(geometries);
    if !geometry_success {
        empty_models: [..] *Model;
        empty_instances: [..] *InstancedModel;
        return empty_models, empty_instances, false;
    }

    // get the model count and instance count here
    geometry_instance_counts := NewArray(geometries.count, int,, allocator = temp);
    for *node: json.nodes {
        if !node.mesh {
            continue;
        }

        mesh := json.meshes[node.mesh.*];
        for *primitive: mesh.primitives {
            if !is_valid_primitive(primitive) {
                continue;
            }

            geometry_index, geometry_index_found := table_find(*primitive_to_geometry, primitive);
            assert(geometry_index_found);

            geometry_instance_counts[geometry_index] += 1;
        }
    }

    model_count: int;
    model_lookup := NewArray(geometries.count, int,, allocator = temp);

    instance_count: int;
    instance_lookup := NewArray(geometries.count, int,, allocator = temp);

    for count, index: geometry_instance_counts {
        if count > 1 {
            instance_lookup[index] = instance_count;
            instance_count += 1;
        } else if count == 1 {
            model_lookup[index] = model_count;
            model_count += 1;
        } else {
            print("Found an unused geometry mesh. %\n", index);
        }
    }

    ModelInfo :: struct {
        name_reference: string;
        position: Vector3;
        rotation: Quaternion;
        scale: Vector3;
    }

    model_infos := NewArray(model_count, ModelInfo,, allocator = temp);
    for node: json.nodes {
        if !node.mesh {
            continue;
        }

        info: ModelInfo;
        if node.name {
            info.name_reference = node.name.*;
        }
        info.position.component = node.translation;
        info.rotation.component = node.rotation;
        info.scale.component = node.scale;

        mesh := json.meshes[node.mesh.*];
        for *primitive: mesh.primitives {
            if !is_valid_primitive(primitive) {
                continue;
            }

            geometry_index, geometry_index_found := table_find(*primitive_to_geometry, primitive);
            assert(geometry_index_found);

            if geometry_instance_counts[geometry_index] != 1 {
                continue;
            }

            model_index := model_lookup[geometry_index];
            model_infos[model_index] = info;
        }
    }

    instance_names := NewArray(instance_count, string,, allocator = temp);
    instance_transforms := NewArray(instance_count, [..] Matrix4,, allocator = temp);
    for *transforms: instance_transforms {
        transforms.allocator = temp;
    }

    for node: json.nodes {
        if !node.mesh {
            continue;
        }

        translation: Vector3;
        translation.component = node.translation;
        rotation: Quaternion;
        rotation.component = node.rotation;
        scaled: Vector3;
        scaled.component = node.scale;

        transform := make_translation_matrix4(translation);
        transform = rotate(transform, rotation);
        transform = scale(transform, scaled);

        mesh := json.meshes[node.mesh.*];
        for *primitive: mesh.primitives {
            if !is_valid_primitive(primitive) {
                continue;
            }

            geometry_index, geometry_index_found := table_find(*primitive_to_geometry, primitive);
            assert(geometry_index_found);

            if geometry_instance_counts[geometry_index] <= 1 {
                continue;   
            }

            desired_instance_count := geometry_instance_counts[geometry_index];
            instance_index := instance_lookup[geometry_index];

            if instance_transforms[instance_index].allocated < desired_instance_count {
                array_reserve(*instance_transforms[instance_index], desired_instance_count);
            }

            if node.name && !instance_names[instance_index] {
                instance_names[instance_index] = node.name.*;
            }

            array_add(*instance_transforms[instance_index], transform);
        }
    }

    array_reserve(*models, model_count);
    array_reserve(*instances, instance_count);
    
    for geometry, index: geometries {
        if geometry_instance_counts[index] > 1 {
            instance_index := instance_lookup[index];
            transforms := instance_transforms[instance_index];

            instance := create_instanced_model(geometry, transforms, should_upload = should_upload);
            if instance_names[instance_index] {
                instance.name = copy_string(instance_names[instance_index]);
            }

            array_add(*instances, instance);
        } else if geometry_instance_counts[index] == 1 {
            model_index := model_lookup[index];
            info := model_infos[model_index];

            model := create_model(geometry, should_upload = should_upload);
            model.position = info.position;
            model.rotation = info.rotation;
            model.scale = info.scale;

            if info.name_reference {
                model.name = copy_string(info.name_reference);
            }

            array_add(*models, model);
        }
    }

    buffers := get_buffers(json, binary);
    defer array_free(buffers);

    bufferviews := get_bufferviews(json, buffers);
    defer array_free(bufferviews);

    textures: Table(int, Texture);
    defer table_reset(*textures);

    for mesh, mesh_index: json.meshes {
        for *primitive: mesh.primitives {
            if !is_valid_primitive(primitive) {
                continue;
            }

            geometry_index, geometry_index_found := table_find(*primitive_to_geometry, primitive);
            assert(geometry_index_found);

            instance_count := geometry_instance_counts[geometry_index];
            assert(instance_count > 0, "Found a mesh geometry with no instances.\n");

            cull_face: *bool;
            uniforms: *ShaderUniforms;
            material_id: *int;
            properties: *[..] [2] string;
            material_properties: *[..] [2] string;
            if instance_count > 1 {
                instance_index := instance_lookup[geometry_index];
                instanced := instances[instance_index];

                cull_face = *instanced.cull_face;
                uniforms = *instanced.uniforms;
                material_id = *instanced.material_id;
                properties = *instanced.properties;
                material_properties = *instanced.material_properties;
            } else if instance_count == 1 {
                model_index := model_lookup[geometry_index];
                model := models[model_index];

                cull_face = *model.cull_face;
                uniforms = *model.uniforms;
                material_id = *model.material_id;
                properties = *model.properties;
                material_properties = *model.material_properties;
            }

            if mesh.extras {
                assert(mesh.extras.type == .Object);
                
                for entry: mesh.extras.object {
                    array_add(properties, get_property_entry(mesh.name, entry));
                }
            }

            if primitive.material {
                material := json.materials[primitive.material.*];

                cull_face.* = !material.doubleSided;
                material_id.* = primitive.material.*;

                if material.extras {
                    assert(material.extras.type == .Object);

                    name := ifx material.name then material.name.* else "";
                    
                    for entry: material.extras.object {
                        array_add(material_properties, get_property_entry(name, entry));
                    }
                }
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

                texture, found := table_find(*textures, texture_index);
                if !found {
                    texture = get_texture(json, bufferviews, texture_index, should_upload);
                    if material.name {
                        texture.name = copy_string(material.name.*);
                    }
                    table_set(*textures, texture_index, texture);
                }

                assert(!has_uniform(uniforms.*, "uTexture0"), "Cannot already have a diffuse texture.");
                set(uniforms, "uTexture0", texture);
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
                    assert(!has_uniform(uniforms.*, "uTexture0"), "Cannot already have a diffuse texture.");
                    set(uniforms, "uTexture0", texture);
                }
            }

            has_normal_texture := true;
            has_normal_texture = has_normal_texture && primitive.material;
            has_normal_texture = has_normal_texture && json.materials[primitive.material.*].normalTexture;
            has_normal_texture = has_normal_texture && json.textures[json.materials[primitive.material.*].normalTexture.index].source;
            if has_normal_texture {
                material := json.materials[primitive.material.*];
                cull_face.* = !material.doubleSided;

                texture_name := material.name;
                assert(!!texture_name, "I thought materials always had to have a name...");
                
                texture_index := material.normalTexture.index;

                texture, found := table_find(*textures, texture_index);
                if !found {
                    texture = get_texture(json, bufferviews, texture_index, should_upload);
                    if material.name {
                        texture.name = copy_string(material.name.*);
                    }
                    table_set(*textures, texture_index, texture);
                }
                
                assert(!has_uniform(uniforms.*, "uNormal0"), "Cannot already have a normal texture.");
                set(uniforms, "uNormal0", texture);
            }

            has_emissive_texture := true;
            has_emissive_texture = has_emissive_texture && primitive.material;
            has_emissive_texture = has_emissive_texture && json.materials[primitive.material.*].emissiveTexture;
            has_emissive_texture = has_emissive_texture && json.textures[json.materials[primitive.material.*].emissiveTexture.index].source;
            if has_emissive_texture {
                material := json.materials[primitive.material.*];
                cull_face.* = !material.doubleSided;

                texture_name := material.name;
                assert(!!texture_name, "I thought materials always had to have a name...");
                
                texture_index := material.emissiveTexture.index;

                texture, found := table_find(*textures, texture_index);
                if !found {
                    texture = get_texture(json, bufferviews, texture_index, should_upload);
                    if material.name {
                        texture.name = copy_string(material.name.*);
                    }
                    table_set(*textures, texture_index, texture);
                }
                
                assert(!has_uniform(uniforms.*, "uEmissive0"), "Cannot already have an emissive texture.");
                set(uniforms, "uEmissive0", texture);
            }
        }
    }

    return models, instances, true;
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
