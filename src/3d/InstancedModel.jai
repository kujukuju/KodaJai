
InstancedModel :: struct {
    shader: *Shader;
    uniforms: ShaderUniforms;
    vao: GLuint;
    vbo: GLuint;
    ebo: GLuint;
    particle_vbo: GLuint;
    gpu_type: Type;
    attributes: [] Attribute;
}

// create_instanced_model :: (geometry: *Geometry, should_upload: bool = false) -> *InstancedModel {
//     model := New(InstancedModel);
//     array_resize(*model.geometry, 1);
//     model.geometry[0] = geometry;

//     if should_upload {
//         upload(model);
//     }

//     return model;
// }

init_instanced_model :: (model: *InstancedModel, geometry: *Geometry, $gpu: $T) {
    model.attributes = array_copy(geometry.attributes);


}

draw :: (model: *InstancedModel, gpu: [] $T, shader: *Shader = null) {
    draw(model, gpu, get_perspective_matrix(), shader);
}

draw :: (model: *InstancedModel, gpu: [] $T, projection: Matrix4, shader: *Shader = null) {
    assert(T == model.gpu_type, "You must provide the instanced model with the same type used to initialize it.\n");

    if !shader {
        if model.shader {
            shader = model.shader;
        } else {
            shader = get_default_shader(model.attributes);
        }
    }

    if !shader {
        print("Could not find appropriate shader for model attributes. %\n", model.geometry[0].attributes);
        assert(false, tprint("Could not find appropriate shader for model attributes. %\n", model.name));
    }

    use_shader(shader);

    apply_uniforms(shader, model.uniforms);

    uniforms: ShaderUniforms;
    defer destroy(uniforms);

    view := koda.view;
    uniforms[xx "projection"] = create_uniform("projection", projection);
    uniforms[xx "view"] = create_uniform("view", view);
    
    apply_uniforms(shader, uniforms);


}

#scope_module

get_instanced_opengl_initialization :: (current_attribute_index_name: string, gpu: Type) -> string {
    struct_type := cast(*Type_Info_Struct) gpu;
    assert(struct_type.type == .STRUCT, "Your graphics particle must be a struct.");

    builder: String_Builder;

    append(*builder, tprint("opengl_current_attribute := %;\n", current_attribute_index_name));
    append(*builder, tprint("opengl_starting_attribute := %;\n", current_attribute_index_name));

    real_member_count := 0;

    skip_indices: [..] int;
    visited_offsets: [..] int;
    for member, index: struct_type.members {
        if array_find(visited_offsets, member.offset_in_bytes) {
            array_add(*skip_indices, index);
            continue;
        }

        array_add(*visited_offsets, member.offset_in_bytes);
        real_member_count += 1;
    }

    total_stride := 0;
    for member, index: struct_type.members {
        if array_find(skip_indices, index) {
            continue;
        }

        assert(member.type.runtime_size != -1, "Particle gpu member sizes cannot be -1, this indicates it's not yet been compiled.");

        total_stride += member.type.runtime_size;
    }

    stride_offset := 0;
    for member, index: struct_type.members {
        if array_find(skip_indices, index) {
            continue;
        }

        is_integer := member.type.type == .INTEGER;
        if is_integer {
            assert(member.type.runtime_size == 4, "Cannot have a group of integers yet.");
        }
        
        member_stride := member.type.runtime_size;

        append(*builder, tprint("glEnableVertexAttribArray(opengl_current_attribute);\n"));
        if is_integer {
            append(*builder, tprint("glVertexAttribIPointer(opengl_current_attribute, %, GL_INT, %, cast(*void) %);\n", member_stride / size_of(float32), total_stride, stride_offset));
        } else {
            append(*builder, tprint("glVertexAttribPointer(opengl_current_attribute, %, GL_FLOAT, GL_FALSE, %, cast(*void) %);\n", member_stride / size_of(float32), total_stride, stride_offset));
        }

        append(*builder, "opengl_current_attribute += 1;\n");

        stride_offset += member_stride;
    }

    for i: 0..real_member_count - 1 {
        append(*builder, tprint("glVertexAttribDivisor(opengl_starting_attribute + %, 1);\n", i));
    }

    return builder_to_string(*builder);
}
