
ModelMatrixGpu :: struct {
    m1: Vector4;
    m2: Vector4;
    m3: Vector4;
    m4: Vector4;
#place m1;
    model: Matrix4 = ---;
}

InstancedModel :: struct (T: Type = ModelMatrixGpu) {
    shader: *Shader;
    uniforms: ShaderUniforms;
    cull_face: bool = true;
    vao: GLuint;
    vbo: GLuint;
    ebo: GLuint;
    indices_count: int;
    particle_vbo: GLuint;
    particle_vbo_count: int;
    particle_vbo_allocated: int;
    attributes: [] Attribute;
}

create_instanced_model :: (geometry: *Geometry) -> *InstancedModel(ModelMatrixGpu) {
    model := create_instanced_model(geometry, dynamic = true);
    return model;
}

create_instanced_model :: (geometry: *Geometry, instances: [] Matrix4) -> *InstancedModel(ModelMatrixGpu) {
    model := create_instanced_model(geometry, dynamic = false);
    set_instances(model, instances);
    return model;
}

create_instanced_model :: (geometry: *Geometry, dynamic: bool) -> *InstancedModel(ModelMatrixGpu) {
    model := create_instanced_model(ModelMatrixGpu, geometry, dynamic);
    return model;
}

create_instanced_model :: ($T: Type, geometry: *Geometry) -> *InstancedModel(T) {
    model := create_instanced_model(T, geometry, dynamic = true);
    return model;
}

create_instanced_model :: ($T: Type, geometry: *Geometry, instances: [] T) -> *InstancedModel(T) {
    model := create_instanced_model(T, geometry, dynamic = false);
    set_instances(model, instances);
    return model;
}

create_instanced_model :: ($T: Type, geometry: *Geometry, dynamic: bool) -> *InstancedModel(T) {
    model := New(InstancedModel(T));
    init_instanced_model(model, geometry, dynamic);
    return model;
}

init_instanced_model :: (model: *InstancedModel($T), geometry: *Geometry, dynamic: bool) {
    gpu_attributes :: #run get_attributes_from_struct(T);
    model.attributes = NewArray(geometry.attributes.count + gpu_attributes.count, Attribute);
    for attribute, index: geometry.attributes {
        model.attributes[index] = attribute;
    }
    for attribute, index: gpu_attributes {
        model.attributes[index + geometry.attributes.count] = attribute;
    }

    model.indices_count = geometry.indices.count;

    draw_mode := ifx dynamic then cast(u32) GL_DYNAMIC_DRAW else GL_STATIC_DRAW;

    glGenVertexArrays(1, *model.vao);
    glGenBuffers(1, *model.vbo);
    glGenBuffers(1, *model.ebo);
    glGenBuffers(1, *model.particle_vbo);

    glBindVertexArray(model.vao);

    glBindBuffer(GL_ARRAY_BUFFER, model.vbo);
    glBufferData(GL_ARRAY_BUFFER, geometry.vertices.count * size_of(float32), geometry.vertices.data, draw_mode);  

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, model.ebo);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, geometry.indices.count * size_of(u32), geometry.indices.data, draw_mode);

    total_float_size := cast(u32) get_attribute_stride(geometry.attributes);
    current_attribute: u32;
    float_offset: s32;
    for attribute: geometry.attributes {
        attribute_size := cast(s32) get_attribute_size(attribute);
        glEnableVertexAttribArray(current_attribute);
        glVertexAttribPointer(current_attribute, attribute_size, GL_FLOAT, GL_FALSE, size_of(float32) * total_float_size, cast(*void) (size_of(float32) * float_offset));

        current_attribute += 1;
        float_offset += attribute_size;
    }

    default_particle_count :: 4;

    // generate the particle vbo, but currently we have no data
    glBindBuffer(GL_ARRAY_BUFFER, model.particle_vbo);
    glBufferData(GL_ARRAY_BUFFER, default_particle_count * size_of(T), null, GL_DYNAMIC_DRAW);
    model.particle_vbo_allocated = default_particle_count;

    // insert particle type vertex attribute data
    #insert #run get_instanced_opengl_initialization("current_attribute", gpu_attributes);

    glBindVertexArray(0);
}

set_instances :: (model: *InstancedModel($T), instances: [] T) {
    model.particle_vbo_count = instances.count;
    if model.particle_vbo_allocated >= instances.count {
        glBindBuffer(GL_ARRAY_BUFFER, model.particle_vbo);
        glBufferSubData(GL_ARRAY_BUFFER, 0, instances.count * size_of(T), instances.data);
    } else {
        model.particle_vbo_allocated = instances.count;
        glBindBuffer(GL_ARRAY_BUFFER, model.particle_vbo);
        glBufferData(GL_ARRAY_BUFFER, instances.count * size_of(T), instances.data, GL_DYNAMIC_DRAW);  
    }
}

set_instances :: (model: *InstancedModel(ModelMatrixGpu), instances: [] Matrix4) {
    #assert(size_of(ModelMatrixGpu) == size_of(Matrix4));
    instanced_gpu: [] ModelMatrixGpu;
    instanced_gpu.data = cast(*ModelMatrixGpu) instances.data;
    instanced_gpu.count = instances.count;

    set_instances(model, instanced_gpu);
}

draw :: (model: *InstancedModel, shader: *Shader = null) {
    draw(model, get_perspective_matrix(), shader);
}

draw :: (model: *InstancedModel, projection: Matrix4, shader: *Shader = null) {
    if model.particle_vbo_count == 0 {
        return;
    }
    
    if !shader {
        if model.shader {
            shader = model.shader;
        } else {
            shader = get_default_shader(model.attributes);
        }
    }

    if !shader {
        print("Could not find appropriate shader for model attributes. %\n", model.attributes);
        assert(false, tprint("Could not find appropriate shader for model attributes.\n"));
    }

    set_cull_face_scope(model.cull_face);

    use_shader(shader);

    apply_uniforms(shader, model.uniforms);

    uniforms: ShaderUniforms;
    defer destroy(uniforms);

    view := koda.view;
    uniforms[xx "projection"] = create_uniform("projection", projection);
    uniforms[xx "view"] = create_uniform("view", view);
    
    apply_uniforms(shader, uniforms);

    glBindVertexArray(model.vao);
    glDrawElementsInstanced(GL_TRIANGLES, cast(u32) model.indices_count, GL_UNSIGNED_INT, null, cast(u32) model.particle_vbo_count);
    glBindVertexArray(0);
}

#scope_module

// TODO what I could do is allow everything to be a union
// nothing would be allowed to be not a union
// and the FIRST union type is what's used
// and enforce that the FIRST union type is as large as the struct size itself
get_attributes_from_struct :: (gpu: Type) -> [] Attribute {
    is_integer_or_float :: (info: *Type_Info) -> bool {
        if info.type == .FLOAT {
            return true;
        } else if info.type == .INTEGER {
            return true;
        } else if info.type == .STRUCT {
            struct_info := cast(*Type_Info_Struct) info;

            visited_offsets: [..] int;
            visited_offsets.allocator = temp;
            array_reserve(*visited_offsets, struct_info.members.count);

            for member: struct_info.members {
                if array_find(visited_offsets, member.offset_in_bytes) {
                    continue;
                }
                array_add(*visited_offsets, member.offset_in_bytes);

                if !is_integer_or_float(member.type) {
                    return false;
                }
            }
            return true;
        }
        return false;
    }

    struct_info := cast(*Type_Info_Struct) gpu;
    assert(struct_info.type == .STRUCT, "Your graphics particle must be a struct.");

    attributes: [..] Attribute;

    visited_offsets: [..] int;
    visited_offsets.allocator = temp;
    array_reserve(*visited_offsets, struct_info.members.count);

    for member, index: struct_info.members {
        if array_find(visited_offsets, member.offset_in_bytes) {
            continue;
        }
        array_add(*visited_offsets, member.offset_in_bytes);

        assert(is_integer_or_float(member.type), "Only allowed to have a gpu struct of integers and floats.\n");
        
        member_stride := member.type.runtime_size;

        is_integer := member.type.type == .INTEGER;
        if is_integer {
            if member_stride == 4 {
                array_add(*attributes, .Integer);
            } else {
                assert(false, "Invalid member stride for integer attribute.\n");
            }
        } else {
            if member_stride == 4 {
                array_add(*attributes, .Float);
            } else if member_stride == 8 {
                array_add(*attributes, .Vector2);
            } else if member_stride == 12 {
                array_add(*attributes, .Vector3);
            } else if member_stride == 16 {
                array_add(*attributes, .Vector4);
            } else {
                assert(false, "Invalid member stride for float attribute.\n");
            }
        }
    }

    return attributes;
}

get_instanced_opengl_initialization :: (current_attribute_index_name: string, $attributes: [$N] Attribute) -> string {
    builder: String_Builder;

    append(*builder, tprint("opengl_current_attribute := %;\n", current_attribute_index_name));
    append(*builder, tprint("opengl_starting_attribute := %;\n", current_attribute_index_name));

    total_stride := get_attribute_stride(attributes) * 4;

    stride_offset := 0;
    for attribute: attributes {
        append(*builder, tprint("glEnableVertexAttribArray(opengl_current_attribute);\n"));

        if attribute == .Float || attribute == .Vector2 || attribute == .Vector3 || attribute == .Vector4 {
            member_stride := get_attribute_stride(attribute);
            append(*builder, tprint("glVertexAttribPointer(opengl_current_attribute, %, GL_FLOAT, GL_FALSE, %, cast(*void) %);\n", member_stride, total_stride, stride_offset));
            stride_offset += member_stride * 4;
        } else if attribute == .Integer {
            member_stride := get_attribute_stride(attribute);
            append(*builder, tprint("glVertexAttribIPointer(opengl_current_attribute, %, GL_INT, %, cast(*void) %);\n", member_stride, total_stride, stride_offset));
            stride_offset += member_stride * 4;
        } else {
            assert(false, "Unsupported gpu particle attribute type.\n");
        }

        append(*builder, "opengl_current_attribute += 1;\n");
    }

    for i: 0..attributes.count - 1 {
        append(*builder, tprint("glVertexAttribDivisor(opengl_starting_attribute + %, 1);\n", i));
    }

    assert(stride_offset == total_stride, "The combinated gpu particle member strides did not result in the expected total stride.\n");

    return builder_to_string(*builder);
}
