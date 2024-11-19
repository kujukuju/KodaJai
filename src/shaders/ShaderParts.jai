
ShaderPart :: struct {
    dependencies: [] ShaderPart;
    section: string;
}

ResolvedShaderPart :: struct {
    // these sections are split in order around the injections
    // the section count will be injections.count + 1
    // even if this means there might be empty sections due to start/ending/adjacent injections
    sections: [] string;
    injections: [] string;
}

free :: (resolved_part: ResolvedShaderPart) {
    array_free(sections);
    array_free(injections);
}

get_location_name :: (location: Source_Code_Location) -> string {
    name: string;
    name.data = location.fully_pathed_filename.data;
    name.count = location.fully_pathed_filename.count;

    start_index := find_index_from_right(name, #char "/");
    if start_index != -1 {
        name.data += start_index + 1;
        name.count -= start_index + 1;
        name.count -= 4;
    }

    return name;
}

create_shader :: (vertex: string, fragment: string, name: string = "", location := #caller_location, $caller := #caller_code) -> Shader {
    return create_shader(.{.[], vertex}, .{.[], fragment}, name, location, caller);
}

create_shader :: (vertex_part: ShaderPart, fragment: string, name: string = "", location := #caller_location, $caller := #caller_code) -> Shader {
    return create_shader(vertex_part, .{.[], fragment}, name, location, caller);
}

create_shader :: (vertex: string, fragment_part: ShaderPart, name: string = "", location := #caller_location, $caller := #caller_code) -> Shader {
    return create_shader(.{.[], vertex}, fragment_part, name, location, caller);
}

create_shader :: (vertex_part: ShaderPart, fragment_part: ShaderPart, name: string = "", location := #caller_location, $caller := #caller_code) -> Shader {
    shader: Shader;
    shader.name = ifx name then name else get_location_name(location);
    shader.vertex_parts = flatten_resolve_dependencies(vertex_part);
    shader.fragment_parts = flatten_resolve_dependencies(fragment_part);

    #if HOT_LOAD_SHADERS {
        watch_files := get_watch_files(caller);

        // vertex_watch_files := flatten_watch_files(vertex_part);
        // defer array_free(vertex_watch_files);
        // fragment_watch_files := flatten_watch_files(fragment_part);
        // defer array_free(fragment_watch_files);
        // shader.watch_files = flatten_watch_files(vertex_watch_files, fragment_watch_files);
    }

    return shader;
}

flatten_resolve_dependencies :: (part: ShaderPart) -> [] ResolvedShaderPart {
    if !part.section && part.dependencies.count == 0 {
        return .[];
    }

    resolve_dependencies :: (part: ShaderPart, flat_parts: *[..] string) {
        for dependency: part.dependencies {
            resolve_dependencies(dependency, flat_parts);
        }

        if part.section {
            array_add(flat_parts, part.section);
        }
    }
         
    flat_parts: [..] string;
    flat_parts.allocator = temp;
    resolve_dependencies(part, *flat_parts);

    if flat_parts.count > 128 {
        print("Warning: Your shader dependency list is larger than I expected. I think the resolve_dependecies method should be optimized now.\n");
    }

    // remove any duplicate entries
    // I'm just gonna loop back over the same array since I don't expect there to be a lot of dependencies
    insert_index := 0;
    check_index := 0;
    while check_index < flat_parts.count {
        should_remove := false;
        for dupe_index: 0..check_index - 1 {
            if flat_parts[check_index].data == flat_parts[dupe_index].data {
                should_remove = true;
                break;
            }
        }

        if should_remove {
            // remove
            check_index += 1;
        } else {
            if insert_index != check_index {
                flat_parts[insert_index] = flat_parts[check_index];
            }

            insert_index += 1;
            check_index += 1;
        }
    }
    flat_parts.count -= check_index - insert_index;

    resolved_parts := NewArray(flat_parts.count, ResolvedShaderPart);
    for flat_part, index: flat_parts {
        resolved_parts[index] = resolve_injections(flat_part);
    }

    return resolved_parts;
}

resolve_injections :: (section: string) -> ResolvedShaderPart {
    sections: [..] string;
    injections: [..] string;

    get_current_line :: (section: string, current_index: int) -> string {
        start_index := current_index;
        while start_index >= 0 {
            if section[start_index] == #char "\n" {
                break;
            }

            start_index -= 1;
        }
        start_index += 1;

        end_index := current_index;
        while end_index < section.count {
            if section[end_index] == #char "\n" {
                break;
            }

            end_index += 1;
        }

        line: string;
        line.data = section.data + start_index;
        line.count = end_index - start_index;
        return line;
    }

    section_index := 0;
    index := 0;
    while index < section.count {
        if section[index] == #char "$" {
            pre_section := array_add(*sections);
            pre_section.data = section.data + section_index;
            pre_section.count = index - section_index;

            start_index := index;
            index += 1;

            while index < section.count {
                character := section[index];
                if is_valid_injection_character(character) {
                    index += 1;
                } else {
                    injection_name: string;
                    injection_name.data = section.data + start_index + 1;
                    injection_name.count = index - start_index - 1;
                    if injection_name.count <= 0 {
                        assert(false, tprint("Your shader injection name indicated by '$' isn't valid.\n\t%\n", get_current_line(section, start_index)));
                    }

                    array_add(*injections, injection_name);
                    section_index = index;

                    break;
                }
            }
        } else {
            index += 1;
        }
    }

    post_section := array_add(*sections);
    post_section.data = section.data + section_index;
    post_section.count = index - section_index;

    part: ResolvedShaderPart;
    part.sections = sections;
    part.injections = injections;

    return part;
}

is_valid_injection_name :: (name: string) -> bool {
    valid := true;
    for i: 0..name.count - 1 {
        valid = valid && is_valid_injection_character(name[i]);
    }
    return valid;
}

is_valid_injection_character :: (character: u8) -> bool {
    valid_character := character >= #char "A" && character <= #char "Z";
    valid_character = valid_character || (character >= #char "a" && character <= #char "z");
    valid_character = valid_character || (character >= #char "0" && character <= #char "9");
    valid_character = valid_character || character == #char "_";
    return valid_character;
}

#scope_file

get_watch_files :: (watch_files: *[..] string, location: Code_Node.Location) {
    print("FOUND WATCH FILE: %\n", location.enclosing_load.fully_pathed_filename);
    array_add(watch_files, location.enclosing_load.fully_pathed_filename);
}

get_watch_files :: (watch_files: *[..] string, node: *Code_Struct_Literal_Info) {
    struct_type := (cast(*Type) *node.type_expression.result).*;

    assert(struct_type == ShaderPart, "Found unknown shader hot reloading struct literal type. %\n", struct_type);
    for arg: node.arguments {
        assert(arg.kind == .LITERAL);
        if arg.kind != .LITERAL {
            return;
        }

        get_watch_files(watch_files, cast(*Code_Literal) arg);
    }
}

get_watch_files :: (watch_files: *[..] string, node: *Code_Array_Literal_Info) {
    element_type := (cast(*Type) *node.element_type.result).*;

    assert(element_type == ShaderPart, "Found unknown shader hot reloading array element literal type. %\n", element_type);
    for arg: node.arguments {
        assert(arg.kind == .LITERAL);
        if arg.kind != .LITERAL {
            return;
        }

        get_watch_files(watch_files, cast(*Code_Literal) arg);
    }
}

get_watch_files :: (watch_files: *[..] string, node: *Code_Literal) {
    if node.value_type == .STRING {
        print("LITERAL %\n", node.*);
        get_watch_files(watch_files, node.location);
    } else if node.value_type == .STRUCT {
        print("LITERAL STRUCT %\n", node.*);
        get_watch_files(watch_files, node.struct_literal_info);
    } else if node.value_type == .ARRAY {
        print("LITERAL ARRAY %\n", node.*);
        get_watch_files(watch_files, node.array_literal_info);
    } else {
        assert(false, "Unhandled shader hot loading literal type. %\n", node.*);
    }
}

get_watch_files :: (watch_files: *[..] string, node: *Code_Ident) {
    assert(!!node.resolved_declaration);
    if !node.resolved_declaration {
        return;
    }

    resolved := node.resolved_declaration;
    print("RESOLVED %\n", resolved.*);

    expression := resolved.expression;
    assert(!!expression);
    if !expression {
        return;
    }

    print("EXPRESSION %\n\n", expression.*);
    assert(expression.kind == .LITERAL);
    if expression.kind != .LITERAL {
        return;
    }

    get_watch_files(watch_files, cast(*Code_Literal) expression);
}

get_watch_files :: (watch_files: *[..] string, node: *Code_Node) {
    if node.kind == .LITERAL {
        get_watch_files(watch_files, cast(*Code_Literal) node);
    } else if node.kind == .IDENT {
        get_watch_files(watch_files, cast(*Code_Ident) node);
    } else {
        assert(false, "Unhandled hot reloading shader argument type. %", node.kind);
    }
}

get_watch_files :: (caller: Code) -> [] string {
    caller_node := cast(*Code_Procedure_Call) compiler_get_nodes(caller);

    watch_files: [..] string;

    assert(caller_node && caller_node.kind == .PROCEDURE_CALL);
    if caller_node.kind != .PROCEDURE_CALL {
        return .[];
    }

    assert(caller_node.arguments_unsorted.count >= 2);
    if caller_node.arguments_unsorted.count < 2 {
        return .[];
    }

    for arg: caller_node.arguments_unsorted {
        if it_index >= 2 {
            break;
        }

        node := arg.expression;
        assert(!!node);
        if !node {
            return .[];
        }

        get_watch_files(*watch_files, node);

        // if node.kind == .LITERAL {
        //     literal := cast(*Code_Literal) node;
        //     assert(literal.value_type == .STRING);
        //     if literal.value_type != .STRING {
        //         return .[];
        //     }

        //     print("LITERAL %\n", literal.*);


        // } else if node.kind == .IDENT {
        //     ident := cast(*Code_Ident) node;
        //     print("\t\tname: %\n", ident.name);

        //     print("IDENT %\n", ident.*);

        //     assert(!!ident.resolved_declaration);
        //     if !ident.resolved_declaration {
        //         return .[];
        //     }

        //     resolved := ident.resolved_declaration;
        //     print("RESOLVED %\n", resolved.*);

        //     expression := resolved.expression;
        //     assert(!!expression);
        //     if !expression {
        //         return .[];
        //     }

        //     print("EXPRESSION %\n", expression.*);

        // } else {
        //     assert(false);
        //     return .[];
        // }
    }

    return watch_files;
}
