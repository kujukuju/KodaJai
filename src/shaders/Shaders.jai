
// TODO for now I'm just calling glGetUniformLocation every time, but I probably shouldnt be
Shader :: struct {
    program: u32;
    uniforms: ShaderUniforms;
    vertex_parts: [] ResolvedShaderPart;
    fragment_parts: [] ResolvedShaderPart;
    output_channels: [] int;
    uniform_locations: [] UniformLocation;
    name: string;
    has_vertex_shader: bool;
    has_fragment_shader: bool;

    #if HOT_LOAD_SHADERS {
        watching: bool;
        watch_files: [] string;
        last_dependencies: [] string;
        last_dependency_names: [] string;
    }
}

UniformLocation :: struct {
    name: FixedString(UNIFORM_LENGTH);
    type: ShaderUniformType;
    location: s32;
}

ShaderDependency :: struct {
    name: string;
    value: Any;
}

// operator == :: (a: Shader, b: Shader) -> bool {
//     return a.vertex.data == b.vertex.data && a.fragment.data == b.fragment.data;
// }

initialize_shader :: (shader: *Shader) {
    dependencies :: Any.[];
    dependency_names :: string.[];
    initialize_shader(shader, dependencies, dependency_names);
}

// the dependency names must match what the resolved shader dependencies expect
initialize_shader :: (shader: *Shader, dependencies: ..Any, $caller := #caller_code) {
    // TODO this shouldn't be done this way I guess... I think it's causing the most significant slowdown
    dependency_count :: #run () -> int {
        nodes := compiler_get_nodes(caller);
        proc_call := cast(*Code_Procedure_Call) nodes;
        proc_args := proc_call.arguments_unsorted;
        assert(proc_args.count >= 1);

        return proc_args.count - 1;
    }();
    dependency_names :: #run () -> [dependency_count] string {
        nodes := compiler_get_nodes(caller);
        proc_call := cast(*Code_Procedure_Call) nodes;
        proc_args := proc_call.arguments_unsorted;
        assert(proc_args.count == dependency_count + 1);

        names: [dependency_count] string;
        for index: 0..dependency_count - 1 {
            arg_ident := cast(*Code_Ident) proc_args[index + 1].expression;
            assert(arg_ident.kind == .IDENT);

            names[index] = arg_ident.name;
        }

        return names;
    }();
    assert(dependencies.count == dependency_names.count, "Dependency count doesn't match shader initialization dependencies. Maybe the syntax changed?\n");

    fixed_dependencies: [dependency_count] Any;
    for dependency, index: dependencies {
        fixed_dependencies[index] = dependency;
    }

    initialize_shader(shader, fixed_dependencies, dependency_names);
}

initialize_shader :: (shader: *Shader, named_dependencies: ..ShaderDependency, $caller := #caller_code) {
    // maybe you can get the count at compile time from dependencies? I didn't check
    dependency_count :: #run () -> int {
        nodes := compiler_get_nodes(caller);
        proc_call := cast(*Code_Procedure_Call) nodes;
        proc_args := proc_call.arguments_unsorted;
        assert(proc_args.count >= 1);

        return proc_args.count - 1;
    }();

    dependencies: [dependency_count] Any;
    dependency_names: [dependency_count] string;

    for named_dependency, index: named_dependencies {
        dependencies[index] = named_dependency.value;
        dependency_names[index] = named_dependency.name;
    }

    initialize_shader(shader, dependencies, dependecy_names);
}

initialize_shader :: (shader: *Shader, dependencies: [] Any, dependency_names: [] string) {
    resolved_dependencies := NewArray(dependencies.count, string,, temp);
    for dependency: dependencies {
        resolved_dependencies[it_index] = resolve_dependency_value(dependency);
    }

    initialize_shader(shader, resolved_dependencies, dependency_names);
}

initialize_shader :: (shader: *Shader, resolved_dependencies: [] string, dependency_names: [] string, allow_failure: bool = false) {
    assert(koda.initialized && koda.window, "You can only initialize shaders after koda has been initialized and a window has been created.\n");

    if !shader.fragment_parts && !shader.vertex_parts {
        return;
    }

    #if HOT_LOAD_SHADERS {
        array_free(shader.last_dependencies);
        array_free(shader.last_dependency_names);
        shader.last_dependencies = array_copy(resolved_dependencies);
        shader.last_dependency_names = array_copy(dependency_names);

        // memory leak yay
        for *resolved_dependency: shader.last_dependencies {
            resolved_dependency.* = copy_string(resolved_dependency.*);
        }

        watch_shader(shader.watch_files, shader);
    }

    if shader.program {
        glDeleteProgram(shader.program);
        shader.program = 0;
    }

    print_pretty_error :: (name: string, message: string, shader_source: string, type_string: string) {
        // try to build out the error data, but we're allowed to exit at any point to avoid super deep nesting
        error_line: string = "Could not find shader error line. This is an internal library error.";
        defer print("Shader compile error:\n\t%\n\t%\n\t%\n\t%\n", name, type_string, error_line, message);

        source_index_string: string;
        source_index_string.data = message.data;
        source_index_string.count = message.count;

        if source_index_string[0] == #char "\0" {
            return;
        }

        index := 0;
        while index < source_index_string.count && source_index_string[index] != #char "(" && source_index_string[index] != #char "\0" {
            index += 1;
        }
        source_index_string.count = index;

        source_index_view := source_index_string;
        source_index, source_index_found := parse_int(*source_index_view);
        if !source_index_found {
            return;
        }

        if message[index] != #char "(" {
            return;
        }

        line_number_string: string;
        line_number_string.data = message.data + index + 1;
        line_number_string.count = message.count - index - 1;

        index = 0;
        while index < line_number_string.count && line_number_string[index] != #char ")" && line_number_string[index] != #char "\0" {
            index += 1;
        }
        line_number_string.count = index;

        line_number_view := line_number_string;
        line_number, line_number_found := parse_int(*line_number_view);
        if !line_number_found {
            return;
        }
        line_index := line_number - 1;

        shader_lines := split(shader_source, "\n",, allocator = temp);
        if line_index < shader_lines.count {
            error_line = shader_lines[line_index];
        }
    }

    make_shader_object :: (name: string, sections: [] string, shader_type: GLenum) -> GLuint, bool {
        shader_object := glCreateShader(shader_type);

        source_strings := NewArray(sections.count, *u8,, allocator = temp);
        source_lengths := NewArray(sections.count, s32,, allocator = temp);

        for i: 0..sections.count - 1 {
            source_strings[i] = sections[i].data;
            source_lengths[i] = cast(s32) sections[i].count;
        }

        glShaderSource(shader_object, cast(u32) source_strings.count, source_strings.data, source_lengths.data);
        glCompileShader(shader_object);

        success: s32;
        glGetShaderiv(shader_object, GL_COMPILE_STATUS, *success);

        if !success {
            shader_source := get_shader_source(shader_object,, allocator = temp);

            message_length: s32;
            glGetShaderiv(shader_object, GL_INFO_LOG_LENGTH, *message_length);

            message := alloc_string(message_length,, allocator = temp);
            glGetShaderInfoLog(shader_object, cast(u32) message.count, null, message.data);

            type_string: string;
            if shader_type == {
                case GL_VERTEX_SHADER;
                    type_string = "Vertex Shader";
                case GL_FRAGMENT_SHADER;
                    type_string = "Fragment Shader";
                case;
                    type_string = "Unknown Shader Type";
            }

            message_parts := split(message, "\n",, allocator = temp);

            for message_part: message_parts {
                if message_part {
                    print_pretty_error(name, message_part, shader_source, type_string);
                }
            }

            return 0, false;
        }

        return shader_object, true;
    }

    get_output_channels :: (program: u32) -> [] int {
        name_bytes: [256] u8;

        active_output_count: s32;
        glGetProgramInterfaceiv(program, GL_PROGRAM_OUTPUT, GL_ACTIVE_RESOURCES, *active_output_count);

        output_channels := NewArray(active_output_count, int);
        output_channels.count = 0;

        for i: 0..active_output_count - 1 {
            properties :: u32.[GL_NAME_LENGTH, GL_TYPE, GL_LOCATION];

            values: [3] s32;
            glGetProgramResourceiv(program, GL_PROGRAM_OUTPUT, cast(u32) i, properties.count, properties.data, values.count, null, values.data);

            output_name_length, output_type, output_location := values[0], values[1], values[2];

            // this is something built in
            if output_location < 0 {
                continue;
            }

            glGetProgramResourceName(program, GL_PROGRAM_OUTPUT, cast(u32) i, name_bytes.count, null, name_bytes.data);
            output_name: string;
            output_name.data = name_bytes.data;
            output_name.count = min(name_bytes.count, output_name_length);

            if output_location >= active_output_count {
                assert(false, "Found shader output % that is at a unique location %. This isn't yet supported.", output_name, output_location);
                continue;
            }

            output_channels.count = max(output_channels.count, output_location + 1);

            if output_type == {
                case GL_FLOAT;
                    output_channels[output_location] = 1;
                case GL_FLOAT_VEC2;
                    output_channels[output_location] = 2;
                case GL_FLOAT_VEC3;
                    output_channels[output_location] = 3;
                case GL_FLOAT_VEC4;
                    output_channels[output_location] = 4;
                case;
                    assert(false, "Unknown shader output component type for %: %.\n", output_name, output_type);
            }
        }

        return output_channels;
    }

    if !validate_dependencies(shader.name, shader.vertex_parts, shader.fragment_parts, dependency_names) {
        return;
    }

    // resolve dependencies in place
    resolved_vertex_parts := resolve_dependencies(shader.vertex_parts, resolved_dependencies, dependency_names,, allocator = temp);
    resolved_fragment_parts := resolve_dependencies(shader.fragment_parts, resolved_dependencies, dependency_names,, allocator = temp);

    shader_v: u32;
    success_v := true;
    if resolved_vertex_parts {
        shader.has_vertex_shader = true;
        shader_v, success_v = make_shader_object(shader.name, resolved_vertex_parts, GL_VERTEX_SHADER);
        if !success_v {
            print("Could not initialized vertex shader.\n");
        }
    }
    defer if shader.has_vertex_shader then glDeleteShader(shader_v);

    shader_f: u32;
    success_f := true;
    if resolved_fragment_parts {
        shader.has_fragment_shader = true;
        shader_f, success_f = make_shader_object(shader.name, resolved_fragment_parts, GL_FRAGMENT_SHADER);
        if !success_f {
            print("Could not initialized fragment shader.\n");
        }
    }
    defer if shader.has_fragment_shader then glDeleteShader(shader_f);

    shader.program = glCreateProgram();

    if !success_v || !success_f || !shader.program {
        glDeleteProgram(shader.program);
        print("Failure initalizing shader.\n");
        if allow_failure {
            print("But allowing shader failure.\n");
        }

        shader.program = 0;

        if !allow_failure {
            assert(false, "Failure initializing shader.");
        }

        return;
    }

    if shader_v {
        glAttachShader(shader.program, shader_v);
    }
    if shader_f {
        glAttachShader(shader.program, shader_f);
    }
    glLinkProgram(shader.program);

    success: GLint;
    glGetProgramiv(shader.program, GL_LINK_STATUS, *success);

    if shader.output_channels then array_free(shader.output_channels);
    shader.output_channels = get_output_channels(shader.program);

    if shader.uniform_locations then array_free(shader.uniform_locations);
    shader.uniform_locations = get_uniform_locations(shader.name, shader.program);

    if !success {
        message: [512] u8;
        glGetProgramInfoLog(shader.program, 512, null, message.data);
        print("Shader error: %\n", to_string(message.data));

        glDeleteProgram(shader.program);
        shader.program = 0;

        assert(false, "Shader error.");
    }
}

validate_dependencies :: (name: string, vertex_parts: [] ResolvedShaderPart, fragment_parts: [] ResolvedShaderPart, dependency_names: [] string) -> bool {
    found_dependencies := NewArray(dependency_names.count, bool,, temp);

    for parts: [] ResolvedShaderPart.[vertex_parts, fragment_parts] {
        for part: parts {
            for injection: part.injections {
                dependency_found, dependency_index := array_find(dependency_names, injection);
                if !dependency_found {
                    assert(false, tprint("Could not find shader injection with name % inside provided dependency names % for shader %.\n", injection, dependency_names, name));
                    return false;
                }

                found_dependencies[dependency_index] = true;
            }
        }
    }

    if array_find(found_dependencies, false) {
        builder: String_Builder;
        append(*builder, "Provided unnecessary dependencies for shader ");
        append(*builder, name);
        append(*builder, ":\n");
        for found, index: found_dependencies {
            append(*builder, "\t");
            append(*builder, dependency_names[index]);
            append(*builder, ": ");
            append(*builder, ifx found then "NECESSARY" else "NOT NECESSARY");
            append(*builder, "\n");
        }
        assert(false, builder_to_string(*builder,, allocator = temp));
        return false;
    }

    return true;
}

resolve_dependencies :: (parts: [] ResolvedShaderPart, resolved_dependencies: [] string, dependency_names: [] string) -> [] string {
    count := 0;
    for part: parts {
        count += part.sections.count;
        count += part.injections.count;
    }

    resolved: [..] string;
    array_reserve(*resolved, count);

    for part: parts {
        assert(part.sections.count == part.injections.count + 1);

        for index: 0..part.sections.count - 1 {
            array_add(*resolved, part.sections[index]);

            if index < part.injections.count {
                dependency_found, dependency_index := array_find(dependency_names, part.injections[index]);
                assert(dependency_found, "Missing shader dependency. This should have been caught earlier.\n");

                shader_value := resolved_dependencies[dependency_index];
                array_add(*resolved, shader_value);
            }
        }
    }

    return resolved;
}

resolve_dependency_value :: (value: Any) -> string {
    type := value.type.type;

    if type == {
        case .INTEGER;
            return tprint("%", value);

        case .FLOAT;
            return tprint("%", value);

        case .STRUCT;
            struct_type := (cast(*Type) *value.type).*;
            if struct_type == Vector2 {
                vec := cast(*Vector2) value.value_pointer;
                return tprint("vec2(%, %)", vec.x, vec.y);
            } else if struct_type == Vector3 {
                vec := cast(*Vector3) value.value_pointer;
                return tprint("vec3(%, %, %)", vec.x, vec.y, vec.z);
            } else if struct_type == Vector4 {
                vec := cast(*Vector4) value.value_pointer;
                return tprint("vec4(%, %, %, %)", vec.x, vec.y, vec.z, vec.w);
            } else {
                assert(false, tprint("Unknown struct type for shader dependency. %\n", struct_type));
                return "";
            }

        case .ARRAY;
            array_info := cast(*Type_Info_Array) value.type;
            element_size := array_info.element_type.runtime_size;

            array_data: *u8;
            array_count: int;
            if array_info.array_type == .FIXED {
                // for non-fixed size arrays, you can't just look up into the variable memory
                array_data = cast(*u8) value.value_pointer;
                array_count = array_info.array_count;
            } else {
                assert(false, "Non-fixed arrays not currently supported although it would be easy. %\n", value);
            }

            builder: String_Builder;
            builder.allocator = temp;

            for i: 0..array_count - 1 {
                element: Any;
                element.type = array_info.element_type;
                element.value_pointer = cast(*void) (array_data + element_size * i);

                append(*builder, resolve_dependency_value(element));

                if i < array_count - 1 {
                    append(*builder, ", ");
                }
            }

            return builder_to_string(*builder);

        case;
            assert(false, tprint("Invalid dependency type of % %.\n", type, value));
            return tprint("%", value);
    }
}

destroy :: (shader: *Shader) {
    if shader.program {
        glDeleteProgram(shader.program);
        shader.program = 0;
    }
    destroy(shader.uniforms);
    shader.uniforms = .{};
    for part: shader.vertex_parts {
        free(part);
    }
    array_free(shader.vertex_parts);
    shader.vertex_parts = .[];
    for part: shader.fragment_parts {
        free(part);
    }
    array_free(shader.fragment_parts);
    shader.fragment_parts = .[];
    array_free(shader.output_channels);
    shader.output_channels = .[];
    array_free(shader.uniform_locations);
    shader.uniform_locations = .[];
    // the strings are expected to be constant more or less
    // so... should they go in the struct definition?
}

get_uniform_locations :: (shader_name: string, program: u32) -> [] UniformLocation {
    uniform_count: s32;

    built_ins :: string.[
        "gl_DepthRange.near",
        "gl_DepthRange.far",
        "gl_DepthRange.diff",
        "gl_DepthRange",
        "gl_NumSamples",
    ];

    glGetProgramiv(program, GL_ACTIVE_UNIFORMS, *uniform_count);

    uniforms := NewArray(uniform_count, UniformLocation);
    array_index := 0;
    for uniform_index: 0..uniform_count - 1 {
        length: u32;
        size: s32;
        type: u32;

        name_buffer: [UNIFORM_LENGTH + 1] u8;
        glGetActiveUniform(program, cast(u32) uniform_index, name_buffer.count, *length, *size, *type, name_buffer.data);

        name_string: string;
        name_string.data = name_buffer.data;
        name_string.count = length;

        if ends_with(name_string, "[0]") {
            name_string.count -= 3;
        }
        assert(length <= UNIFORM_LENGTH, "Shader has a uniform with too long of a name. %\n", name_string);

        if array_find(built_ins, name_string) {
            uniforms.count -= 1;

            continue;
        }

        uniforms[array_index].name = create_fixed_string(name_string, UNIFORM_LENGTH);
        uniforms[array_index].type = get_uniform_type(type, size);
        uniforms[array_index].location = glGetUniformLocation(program, to_c_string(*uniforms[array_index].name));
        assert(uniforms[array_index].location >= 0, "Could not find valid location for shader uniform. %: %\n", shader_name, name_string);

        array_index += 1;
    }

    return uniforms;
}

get_shader_source :: (shader_object: u32) -> string {
    shader_length: s32;
    glGetShaderiv(shader_object, GL_SHADER_SOURCE_LENGTH, *shader_length);
    shader_source := alloc_string(shader_length);
    glGetShaderSource(shader_object, cast(u32) shader_source.count, null, shader_source.data);

    return shader_source;
}

get_shader_strings :: (shader: Shader) -> string, string {
    shader_count: s32;
    glGetProgramiv(shader.program, GL_ATTACHED_SHADERS, *shader_count);
    assert(shader_count <= 2, "Cannot get shader strings, there are currently more than 2 shaders attached which I don't handle.");

    shader_names := NewArray(shader_count, u32);
    glGetAttachedShaders(shader.program, cast(u32) shader_count, null, shader_names.data);

    if shader_names.count == 2 {
        return get_shader_source(shader_names[0]), get_shader_source(shader_names[1]);
    } else if shader_names.count == 1 {
        return get_shader_source(shader_names[0]), "";
    }

    return "", "";
}

claim_texture_slot :: (buffer: u32, bytes: int) -> texture_slot: u32, already_bound: bool {
    // this could be optimized even more by having a heuristic that tries to avoid large texture binds

    for active_texture, active_slot: koda.active_textures {
        if active_texture.buffer == buffer {
            koda.texture_expirations[active_slot] = 0;
            return cast(u32) active_slot, true;
        }
    }

    // we haven't found the texture as currently uploaded
    if koda.active_textures.count < koda.maximum_active_texture_count {
        array_add(*koda.active_textures, .{buffer, bytes});
        array_add(*koda.texture_expirations, 0);

        active_slot := koda.active_textures.count - 1;

        return cast(u32) active_slot, false;
    } else {
        // texture_swap_count += 1;

        // I'm going off of the equation 8*8 -> 1, 16*16 -> 2, 32*32 -> 3, which is y=2^(2x+4)
        // and larger values are removed sooner, so we'll basically divide by this number
        get_expiration_mul :: inline (bytes: int) -> float {
            // multiplier meaning, we will multiplier the expirator by 1 more every time
            // a single dimension increases by this multiplier from the previous value
            multiplier :: 4;
            // this is 2^smallest_size_exp is a single dimension that will have a multiplier of 1
            smallest_size_exp :: 4;
            denominator :: #run multiplier * 2 * log(2.0);
            subtractive :: #run (smallest_size_exp - 1) / multiplier;

            // 2, 3 -> 2 + 2x -> log(y) / (4 * log(2)) - 1
            // 2, 4 -> 3 + 2x -> log(y) / (4 * log(2)) - 3 / 2
            // 2, 5 -> 4 + 2x -> log(y) / (4 * log(2)) - 2

            // 3, 3 -> 2 + 3x -> log(y) / (6 * log(2)) - 2 / 3
            // 3, 4 -> 3 + 3x -> log(y) / (6 * log(2)) - 1
            // 3, 5 -> 4 + 3x -> log(y) / (6 * log(2)) - 4 / 3

            bytes = max(bytes, 1);
            return cast(float) (1.0 / max(log(cast(float64) bytes) / denominator - subtractive, 1));
        }

        oldest_expiration_index := 0;
        oldest_expiration_value := 0.0;

        for expiration, expiration_index: koda.texture_expirations {
            expiration_mul := get_expiration_mul(koda.active_textures[expiration_index].bytes);

            if expiration * expiration_mul >= oldest_expiration_value {
                oldest_expiration_index = expiration_index;
                oldest_expiration_value = expiration * expiration_mul;
            }
        }

        assert(oldest_expiration_value > 0, "All texture slots are filled and there's another texture trying to be assigned. I think this means I actually need to detect the real texture uniform max.\n");

        koda.active_textures[oldest_expiration_index] = .{buffer, bytes};
        koda.texture_expirations[oldest_expiration_index] = 0;
        return cast(u32) oldest_expiration_index, false;
    }
}

release_texture_slot :: (buffer: u32) {
    for active_texture, active_slot: koda.active_textures {
        if active_texture.buffer == buffer {
            koda.active_textures[active_slot].buffer = 0;
            koda.active_textures[active_slot].bytes = 0;
            koda.texture_expirations[active_slot] = S32_MAX;
        }
    }
}

glBindTextureTemporary :: (texture_type: u32, buffer: u32) #expand {
    last_2d_texture: s32;
    last_3d_texture: s32;
    last_cube_map_texture: s32;
    last_array_texture: s32;
    glGetIntegerv(GL_TEXTURE_BINDING_2D, *last_2d_texture);
    glGetIntegerv(GL_TEXTURE_BINDING_3D, *last_3d_texture);
    glGetIntegerv(GL_TEXTURE_BINDING_CUBE_MAP, *last_cube_map_texture);
    glGetIntegerv(GL_TEXTURE_BINDING_2D_ARRAY, *last_array_texture);
    `defer if last_2d_texture then glBindTexture(GL_TEXTURE_2D, cast(u32) last_2d_texture);
    `defer if last_3d_texture then glBindTexture(GL_TEXTURE_3D, cast(u32) last_3d_texture);
    `defer if last_cube_map_texture then glBindTexture(GL_TEXTURE_CUBE_MAP, cast(u32) last_cube_map_texture);
    `defer if last_array_texture then glBindTexture(GL_TEXTURE_2D_ARRAY, cast(u32) last_array_texture);

    glBindTexture(texture_type, buffer);
}

apply_uniforms :: (shader: *Shader, uniforms: ShaderUniforms, printing: bool = false) {
    shader = get_shader_replacement(shader);

    if shader.program != koda.shader {
        print("Applying uniforms to inactive shader. This is very unusual. I'm even considering disallowing this.\n");
        print_stack_trace();
    }

    for *uniform: uniforms {
        location: s32 = -1;
        for uniform_location: shader.uniform_locations {
            if uniform_location.name == uniform.name {
                assert(uniform_location.type == uniform.type, "Trying to assign a texture uniform to a slot with a different type. %: %: % (expected) != % (given)\n", shader.name, to_string(*uniform.name), uniform_location.type, uniform.type);
                location = uniform_location.location;
                break;
            }
        }

        if location == -1 {
            continue;
        }

        if #complete uniform.type == {
            case .Float1;
                glUniform1f(location, uniform.float1);
            case .Float1N;
                glUniform1fv(location, xx uniform.float1n.count, uniform.float1n.data);
            case .Float2;
                glUniform2f(location, uniform.float2[0], uniform.float2[1]);
            case .Float2N;
                glUniform2fv(location, xx uniform.float2n.count, cast(*float) uniform.float2n.data);
            case .Float3;
                glUniform3f(location, uniform.float3[0], uniform.float3[1], uniform.float3[2]);
            case .Float3N;
                glUniform3fv(location, xx uniform.float3n.count, cast(*float) uniform.float3n.data);
            case .Float4;
                glUniform4f(location, uniform.float4[0], uniform.float4[1], uniform.float4[2], uniform.float4[3]);
            case .Float4N;
                glUniform4fv(location, xx uniform.float4n.count, cast(*float) uniform.float4n.data);
            case .Int1;
                glUniform1i(location, uniform.int1);
            case .Int1N;
                glUniform1iv(location, xx uniform.int1n.count, uniform.int1n.data);
            case .Int2;
                glUniform2i(location, uniform.int2[0], uniform.int2[1]);
            case .Int2N;
                glUniform2iv(location, xx uniform.int2n.count, cast(*s32) uniform.int2n.data);
            case .Int3;
                glUniform3i(location, uniform.int3[0], uniform.int3[1], uniform.int3[2]);
            case .Int3N;
                glUniform3iv(location, xx uniform.int3n.count, cast(*s32) uniform.int3n.data);
            case .Int4;
                glUniform4i(location, uniform.int4[0], uniform.int4[1], uniform.int4[2], uniform.int4[3]);
            case .Int4N;
                glUniform4iv(location, xx uniform.int4n.count, cast(*s32) uniform.int4n.data);
            case .UInt1;
                glUniform1ui(location, uniform.uint1);
            case .UInt1N;
                glUniform1uiv(location, xx uniform.uint1n.count, uniform.uint1n.data);
            case .UInt2;
                glUniform2ui(location, uniform.uint2[0], uniform.uint2[1]);
            case .UInt2N;
                glUniform2uiv(location, xx uniform.uint2n.count, cast(*u32) uniform.uint2n.data);
            case .UInt3;
                glUniform3ui(location, uniform.uint3[0], uniform.uint3[1], uniform.uint3[2]);
            case .UInt3N;
                glUniform3uiv(location, xx uniform.uint3n.count, cast(*u32) uniform.uint3n.data);
            case .UInt4;
                glUniform4ui(location, uniform.uint4[0], uniform.uint4[1], uniform.uint4[2], uniform.uint4[3]);
            case .UInt4N;
                glUniform4uiv(location, xx uniform.uint4n.count, cast(*u32) uniform.uint4n.data);
            case .Mat2;
                glUniformMatrix2fv(location, 1, true, cast(*float) uniform.mat2.data);
            case .Mat2N;
                glUniformMatrix2fv(location, xx uniform.mat2n.count, true, cast(*float) uniform.mat2n.data);
            case .Mat3;
                glUniformMatrix3fv(location, 1, true, cast(*float) uniform.mat3.data);
            case .Mat3N;
                glUniformMatrix3fv(location, xx uniform.mat3n.count, true, cast(*float) uniform.mat3n.data);
            case .Mat4;
                glUniformMatrix4fv(location, 1, true, cast(*float) uniform.mat4.data);
            case .Mat4N;
                glUniformMatrix4fv(location, xx uniform.mat4n.count, true, cast(*float) uniform.mat4n.data);
            case .Texture; #through;
            case .ShadowTexture;
                texture_slot, already_bound := claim_texture_slot(uniform.texture.buffer, get_bytes(uniform.texture));
                if !already_bound {
                    glActiveTexture(GL_TEXTURE0 + texture_slot);
                    glBindTexture(GL_TEXTURE_2D, uniform.texture.buffer);
                }
                glUniform1i(location, cast(s32) texture_slot);
            case .TextureArray;
                texture_slot, already_bound := claim_texture_slot(uniform.texture_array.buffer, get_bytes(uniform.texture_array));
                if !already_bound {
                    glActiveTexture(GL_TEXTURE0 + texture_slot);
                    glBindTexture(GL_TEXTURE_2D_ARRAY, uniform.texture_array.buffer);
                }
                glUniform1i(location, cast(s32) texture_slot);
            case .Texture3;
                texture_slot, already_bound := claim_texture_slot(uniform.texture3.buffer, get_bytes(uniform.texture3));
                if !already_bound {
                    glActiveTexture(GL_TEXTURE0 + texture_slot);
                    glBindTexture(GL_TEXTURE_3D, uniform.texture3.buffer);
                }
                glUniform1i(location, cast(s32) texture_slot);
            case .CubemapTexture;
                texture_slot, already_bound := claim_texture_slot(uniform.cubemap_texture.buffer, get_bytes(uniform.cubemap_texture));
                if !already_bound {
                    glActiveTexture(GL_TEXTURE0 + texture_slot);
                    glBindTexture(GL_TEXTURE_CUBE_MAP, uniform.cubemap_texture.buffer);
                }
                glUniform1i(location, cast(s32) texture_slot);
        }
    }
}

set_shader_replacement :: (source: *Shader, dest: *Shader) {
    for *replacement: koda.shader_replacements {
        if replacement.*[0] == source {
            replacement.*[1] = dest;
            return;
        }
    }

    array_add(*koda.shader_replacements, .[source, dest]);
}

clear_shader_replacements :: () {
    koda.shader_replacements.count = 0;
}

get_shader_replacement :: (source: *Shader) -> *Shader {
    for replacement: koda.shader_replacements {
        if replacement[0] == source {
            return replacement[1];
        }
    }

    assert(!should_assert_without_replacement, "Did not find shader replacement for shader %.\n", source.name);

    return source;
}

should_assert_without_replacement: bool;

set_should_assert_without_replacement :: (enabled: bool) {
    should_assert_without_replacement = enabled;
}

use_shader :: (shader: *Shader) {
    shader = get_shader_replacement(shader);

    old_should_assert_without_replacement := should_assert_without_replacement;
    defer should_assert_without_replacement = old_should_assert_without_replacement;
    should_assert_without_replacement = false;

    if !shader.program {
        assert(false, "You have to manually initialize shaders. %\n", shader.name);
        if !shader.name {
            print_stack_trace();
        }

        if !shader.program {
            print("Cannot use shader. You must initialized it first.\n");
            assert(false, "Cannot use uninitialized shader.");
            return;
        }
    }

    // we only validate information about the fragment output channels if there is a fragment shader
    if shader.has_fragment_shader && get_color_write() {
        if shader.output_channels.count != koda.active_pass_channels.count {
            assert(false, "Using shader % with % output channels inside a render pass with % output channels.\n", shader.name, shader.output_channels.count, koda.active_pass_channels.count);
            return;
        }

        for i: 0..shader.output_channels.count - 1 {
            channel_component_count := get_component_count(koda.active_pass_channels[i]);
            if shader.output_channels[i] != channel_component_count {
                assert(false, "Using shader % where output channel % has % components inside a render pass where output channel % has % components.\n", shader.name, i, shader.output_channels[i], i, channel_component_count);
                return;
            }
        }
    }

    // increment texture expirations and apply default shader uniforms if any
    for i: 0..koda.texture_expirations.count - 1 {
        koda.texture_expirations[i] += 1;
    }

    if koda.shader == shader.program {
        apply_uniforms(shader, shader.uniforms);
        return;
    }

    // if koda.active_program == shader.program {
    //     return;
    // }

    glUseProgram(shader.program);
    koda.active_program = shader.program;
    koda.shader = shader.program;

    apply_uniforms(shader, shader.uniforms);
}

#if HOT_LOAD_SHADERS {
    check_shader_watching :: () {
        changed_files := get_changes(*watcher);

        changed_shaders.count = 0;
        for changed_file: changed_files {
            affected_shaders_found, affected_shaders := table_find(*watch_files, changed_file);
            if affected_shaders_found {
                for affected_shader: affected_shaders {
                    if !array_find(changed_shaders, affected_shader) {
                        array_add(*changed_shaders, affected_shader);
                    }
                }
            }
        }

        // we leak memory everywhere

        for shader: changed_shaders {
            external_shader := load_external_shader(shader.name, shader.watch_files);

            print("Shader changed. %\n", shader.name);

            initialize_shader(*external_shader, shader.last_dependencies, shader.last_dependency_names, allow_failure = true);

            if !external_shader.program {
                print("Could not compile shader from hot reload. %\n", shader.name);
                continue;
            }

            print("Swapping shader. %\n", shader.name);

            shader.program = external_shader.program;

            shader.vertex_parts = array_copy(external_shader.vertex_parts);
            for *vertex_part, vertex_index: shader.vertex_parts {
                vertex_part.sections = array_copy(external_shader.vertex_parts[vertex_index].sections);
                vertex_part.injections = array_copy(external_shader.vertex_parts[vertex_index].injections);

                for *section: vertex_part.sections {
                    section.* = copy_string(section.*);
                }
                for *injections: vertex_part.injections {
                    injections.* = copy_string(injections.*);
                }
            }

            shader.fragment_parts = array_copy(external_shader.fragment_parts);
            for *fragment_part, fragment_index: shader.fragment_parts {
                fragment_part.sections = array_copy(external_shader.fragment_parts[fragment_index].sections);
                fragment_part.injections = array_copy(external_shader.fragment_parts[fragment_index].injections);

                for *section: fragment_part.sections {
                    section.* = copy_string(section.*);
                }
                for *injections: fragment_part.injections {
                    injections.* = copy_string(injections.*);
                }
            }

            shader.output_channels = array_copy(external_shader.output_channels);

            shader.uniform_locations = array_copy(external_shader.uniform_locations);

            shader.has_vertex_shader = external_shader.has_vertex_shader;
            shader.has_fragment_shader = external_shader.has_fragment_shader;
        }
    }

    watch_shader :: (files: [] string, shader: *Shader) {
        if shader.watching {
            return;
        }

        success := true;

        for file: files {
            file_shaders := find_or_add(*watch_files, file);
            if !array_find(file_shaders.*, shader) {
                array_add(file_shaders, shader);
            }

            if !watch_file(*watcher, file) {
                success = false;
                assert(false, "Could not watch shader file. % %\n", shader.name, file);
            }
        }

        if success {
            shader.watching = true;
        }
    }
} else {
    check_shader_watching :: () #expand {}
}

#scope_file

#if HOT_LOAD_SHADERS {
    watcher: FileChangeWatcher;
    watch_files: Table(string, [..] *Shader);
    changed_shaders: [..] *Shader;

    #import "File_Watcher";
}

#import "Basic";
