
// TODO for now I'm just calling glGetUniformLocation every time, but I probably shouldnt be
Shader :: struct {
    program: u32;
    uniforms: ShaderUniforms;
    output_channels: [] int;
    name: string;
    vertex_parts: [] ResolvedShaderPart;
    fragment_parts: [] ResolvedShaderPart;
    vertex: string;
    fragment: string;
}

operator == :: (a: Shader, b: Shader) -> bool {
    return a.vertex.data == b.vertex.data && a.fragment.data == b.fragment.data;
}

// the dependency names must match what the resolved shader dependencies expect
initialize_shader :: (shader: *Shader, dependencies: ..Any, $caller := #caller_code) {
    if shader.program > 0 {
        return;
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

        source_index, source_index_found := parse_int(*source_index_string);
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

        line_number, line_number_found := parse_int(*line_number_string);
        if !line_number_found {
            return;
        }
        line_index := line_number - 1;

        shader_lines := split(shader_source, "\n",, allocator = temp);
        if line_index < shader_lines.count {
            error_line = shader_lines[line_index];
        }
    }

    make_shader_object :: (name: string, shader: string, sections: [] string, shader_type: GLenum) -> GLuint, bool #must {
        shader_object := glCreateShader(shader_type);

        source_strings := NewArray(sections.count + 1, *u8,, allocator = temp);
        source_lengths := NewArray(sections.count + 1, s32,, allocator = temp);

        source_strings[source_strings.count - 1] = shader.data;
        source_lengths[source_strings.count - 1] = cast(s32) shader.count;
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
                assert(false, tprint("Found shader output % that is at a unique location %. This isn't yet supported.", output_name, output_location));
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
                    assert(false, tprint("Unknown shader output component type for %: %.\n", output_name, output_type));
            }
        }

        return output_channels;
    }

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

    if !validate_dependencies(shader.vertex_parts, shader.fragment_parts, ..dependencies, dependency_names) {
        return;
    }

    // resolve dependencies in place
    resolved_vertex_parts := resolve_dependencies(shader.vertex_parts, ..dependencies, dependency_names,, allocator = temp);
    resolved_fragment_parts := resolve_dependencies(shader.fragment_parts, ..dependencies, dependency_names,, allocator = temp);

    shader_v: u32;
    success_v := true;
    if shader.vertex || resolved_vertex_parts {
        shader_v, success_v = make_shader_object(shader.name, shader.vertex, resolved_vertex_parts, GL_VERTEX_SHADER);
        if !success_v {
            print("Could not initialized vertex shader.\n");
        }
    }
    defer if shader.vertex || resolved_vertex_parts then glDeleteShader(shader_v);

    shader_f: u32;
    success_f := true;
    if shader.fragment || resolved_fragment_parts {
        shader_f, success_f = make_shader_object(shader.name, shader.fragment, resolved_fragment_parts, GL_FRAGMENT_SHADER);
        if !success_f {
            print("Could not initialized fragment shader.\n");
        }
    }
    defer if shader.fragment || resolved_fragment_parts then glDeleteShader(shader_f);

    shader.program = glCreateProgram();

    if !success_v || !success_f || !shader.program {
        glDeleteProgram(shader.program);
        print("Failure initalizing shader.\n");

        shader.program = 0;

        assert(false, "Failure initializing shader.");
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

    shader.output_channels = get_output_channels(shader.program);

    if !success {
        message: [512] u8;
        glGetProgramInfoLog(shader.program, 512, null, message.data);
        print("Shader error: %\n", to_string(message.data));

        glDeleteProgram(shader.program);
        shader.program = 0;

        assert(false, "Shader error.");
    }
}

validate_dependencies :: (vertex_parts: [] ResolvedShaderPart, fragment_parts: [] ResolvedShaderPart, dependencies: ..Any, $dependency_names: [$N] string) -> bool {
    found_dependencies: [dependency_names.count] bool;
    
    // all_parts := ResolvedShaderPart.[vertex_parts, fragment_parts];
    for parts: [] ResolvedShaderPart.[vertex_parts, fragment_parts] {
        for part: parts {
            for injection: part.injections {
                dependency_found, dependency_index := array_find(dependency_names, injection);
                if !dependency_found {
                    assert(false, tprint("Could not find shader injection with name % inside provided dependency names %.\n", injection, dependency_names));
                    return false;
                }

                found_dependencies[dependency_index] = true;
            }
        }
    }

    if array_find(found_dependencies, false) {
        builder: String_Builder;
        append(*builder, "Did not find an injection for all provided shader dependencies:\n");
        for found, index: found_dependencies {
            append(*builder, "\t");
            append(*builder, dependency_names[index]);
            append(*builder, ": ");
            append(*builder, ifx found then "FOUND" else "NOT FOUND");
            append(*builder, "\n");
        }
        assert(false, builder_to_string(*builder,, allocator = temp));
        return false;
    }

    return true;
}

resolve_dependencies :: (parts: [] ResolvedShaderPart, dependencies: ..Any, $dependency_names: [] string) -> [] string {
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

                array_add(*resolved, tprint("%", dependencies[dependency_index]));
            }
        }
    }

    return resolved;
}

destroy_shader :: (shader: Shader) {
    array_free(shader.vertex_parts);
    array_free(shader.fragment_parts);
    free(shader.vertex);
    free(shader.fragment);
    array_free(shader.output_channels);
    array_free(shader.uniforms.uniforms);
    glDeleteProgram(shader.program);
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

// TODO apply_uniform singular as well? maybe impossible bc of textures

apply_uniforms :: (shader: *Shader, uniforms: ShaderUniforms, printing: bool = false) {
    if shader != koda.shader {
        print("Applying uniforms to inactive shader. This is very unusual. I'm even considering disallowing this.\n");
        print_stack_trace();
    }

    // final_uniforms: ShaderUniforms;
    // defer destroy(final_uniforms);

    // for uniform: shader.uniforms.uniforms {
    //     shader.uniforms[xx uniform.name] = uniform;
    //     shader.uniforms[xx uniform.name].ownership = false;
    //     debug_shaders && print("set % % %\n", to_string(uniform.name), uniform, shader.uniforms[xx uniform.name].*);
    // }

    for uniform: uniforms.uniforms {
        existing := shader.uniforms[xx uniform.name];
        shader.uniforms[xx uniform.name] = uniform;
        shader.uniforms[xx uniform.name].ownership = false;
        
        if existing && existing.location {
            shader.uniforms[xx uniform.name].location = existing.location;
        }
    }

    // TODO because currently the shader does not own its own memory, this is leaking memory every frame
    // TODO so the shader should have uniforms that it owns, and then there should be an unowned stack uniform that gets applied or something

    // the uniforms stay in order for the shaders uniforms, so after we apply all the uniforms we can lookup the texture indices by iterating over them in order
    // for *uniform: uniforms.uniforms {
        texture_index: s32;

        for *uniform: shader.uniforms.uniforms {
            if uniform.location == -1 {
                continue;
            }

            // if uniform.name == shader_uniform.name {
                // TODO this could be improved if I force uniform names to be less than a certain size, and use fixed strings
                location := glGetUniformLocation(shader.program, uniform.name);
                uniform.location = location;
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
                    case .Texture;
                        glActiveTexture(GL_TEXTURE0 + cast(u32) texture_index);
                        glBindTexture(GL_TEXTURE_2D, uniform.texture.buffer);
                        glUniform1i(location, texture_index);

                        texture_index += 1;
                    case .TextureArray;
                        glActiveTexture(GL_TEXTURE0 + cast(u32) texture_index);
                        glBindTexture(GL_TEXTURE_2D_ARRAY, uniform.texture_array.buffer);
                        glUniform1i(location, texture_index);

                        texture_index += 1;
                    case .Texture3;
                        glActiveTexture(GL_TEXTURE0 + cast(u32) texture_index);
                        glBindTexture(GL_TEXTURE_3D, uniform.texture3.buffer);
                        glUniform1i(location, texture_index);

                        texture_index += 1;
                    case .CubemapTexture;
                        glActiveTexture(GL_TEXTURE0 + cast(u32) texture_index);
                        glBindTexture(GL_TEXTURE_CUBE_MAP, uniform.cubemap_texture.buffer);
                        glUniform1i(location, texture_index);

                        texture_index += 1;
                    // case .TextureN;
                    //     // TODO no allocations
                    //     texture_values := NewArray(uniform.uint1n.count, u32, initialized = false);
                    //     defer array_free(texture_values);

                    //     for i: 0..uniform.uint1n.count - 1 {
                    //         glActiveTexture(GL_TEXTURE0 + texture_index);
                    //         glBindTexture(GL_TEXTURE_2D, uniform.uint1n[i]);
                    //         texture_values[i] = texture_index;

                    //         texture_index += 1;
                    //     }
                    //     glUniform1uiv(location, xx texture_values.count, texture_values.data);
                }
            // } else {
            //     if shader_uniform.type == {
            //         case .Texture;
            //             texture_index += 1;
            //         case .Texture3;
            //             texture_index += 1;
            //         case .CubemapTexture;
            //             texture_index += 1;
            //         // case .TextureN;
            //         //     texture_index += cast(u32) shader_uniform.uint1n.count;
            //     }
            // }
        }
    // }

    // TODO is it important to set back glActiveTexture(GL_TEXTURE0); here?
}

use_shader :: (shader: *Shader) {
    if !shader.program {
        assert(false, tprint("You have to manually initialize shaders. %\n", shader.name));
        if !shader.name {
            print_stack_trace();
        }
        // initialize_shader(shader);

        if !shader.program {
            print("Cannot use shader. You must initialized it first.\n");
            assert(false, "Cannot use uninitialized shader.");
            return;
        }
    }

    if shader.output_channels.count != koda.active_pass_channels.count {
        assert(false, tprint("Using shader % with % output channels inside a render pass with % output channels.\n", shader.name, shader.output_channels.count, koda.active_pass_channels.count));
        return;
    }

    for i: 0..shader.output_channels.count - 1 {
        channel_component_count := get_component_count(koda.active_pass_channels[i]);
        if shader.output_channels[i] != channel_component_count {
            assert(false, tprint("Using shader % where output channel % has % components inside a render pass where output channel % has % components.\n", shader.name, i, shader.output_channels[i], i, channel_component_count));
            return;
        }
    }

    if koda.active_program == shader.program {
        return;
    }

    glUseProgram(shader.program);
    koda.active_program = shader.program;
    koda.shader = shader;
}

#import "Basic";