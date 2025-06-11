
PreliminaryShader :: struct {
    vertex_part: ShaderPart;
    fragment_part: ShaderPart;
    name: string;
#if HOT_LOAD_SHADERS {
    watch_files: [] string;
}
}

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

create_prelim_shader :: (vertex: string, fragment: string, name: string = "", location := #caller_location, caller := #caller_code, watch_files: bool = true) -> PreliminaryShader {
    return create_prelim_shader(.{.[], vertex}, .{.[], fragment}, name, location, caller, watch_files);
}

create_prelim_shader :: (vertex_part: ShaderPart, fragment: string, name: string = "", location := #caller_location, caller := #caller_code, watch_files: bool = true) -> PreliminaryShader {
    return create_prelim_shader(vertex_part, .{.[], fragment}, name, location, caller, watch_files);
}

create_prelim_shader :: (vertex: string, fragment_part: ShaderPart, name: string = "", location := #caller_location, caller := #caller_code, watch_files: bool = true) -> PreliminaryShader {
    return create_prelim_shader(.{.[], vertex}, fragment_part, name, location, caller, watch_files);
}

create_prelim_shader :: (vertex_part: ShaderPart, fragment_part: ShaderPart, name: string = "", location := #caller_location, caller := #caller_code, watch_files: bool = true) -> PreliminaryShader {
    prelim: PreliminaryShader;
    prelim.name = ifx name then name else get_location_name(location);
    prelim.vertex_part = vertex_part;
    prelim.fragment_part = fragment_part;

    #if HOT_LOAD_SHADERS {
        if watch_files {
            prelim.watch_files = get_watch_files(caller);
        }
    }

    return prelim;
}

create_shader :: (prelim: PreliminaryShader) -> Shader {
    shader: Shader;
    shader.name = prelim.name;
    shader.vertex_parts = flatten_resolve_dependencies(prelim.vertex_part);
    shader.fragment_parts = flatten_resolve_dependencies(prelim.fragment_part);
    #if HOT_LOAD_SHADERS {
        shader.watch_files = prelim.watch_files;
    }
    print("Creating shader %: %\n", prelim.name, shader.fragment_parts);
    return shader;
}

create_shader :: (vertex: string, fragment: string, name: string = "", location := #caller_location, caller := #caller_code, watch_files: bool = true) -> Shader {
    return create_shader(.{.[], vertex}, .{.[], fragment}, ifx name then name else get_location_name(location), location, caller, watch_files);
}

create_shader :: (vertex_part: ShaderPart, fragment: string, name: string = "", location := #caller_location, caller := #caller_code, watch_files: bool = true) -> Shader {
    return create_shader(vertex_part, .{.[], fragment}, ifx name then name else get_location_name(location), location, caller, watch_files);
}

create_shader :: (vertex: string, fragment_part: ShaderPart, name: string = "", location := #caller_location, caller := #caller_code, watch_files: bool = true) -> Shader {
    return create_shader(.{.[], vertex}, fragment_part, ifx name then name else get_location_name(location), caller, watch_files);
}

create_shader :: (vertex_part: ShaderPart, fragment_part: ShaderPart, name: string = "", location := #caller_location, caller := #caller_code, watch_files: bool = true) -> Shader {
    return create_shader(vertex_part, fragment_part, ifx name then name else get_location_name(location), caller, watch_files);
}

create_shader :: (vertex_part: ShaderPart, fragment_part: ShaderPart, name: string, caller: Code, watch_files: bool = true) -> Shader {
    shader: Shader;
    shader.name = name;
    shader.vertex_parts = flatten_resolve_dependencies(vertex_part);
    shader.fragment_parts = flatten_resolve_dependencies(fragment_part);

    #if HOT_LOAD_SHADERS {
        if watch_files {
            shader.watch_files = get_watch_files(caller);
        }
    }

    return shader;
}

#scope_file

get_watch_files :: (watch_files: *[..] string, location: Code_Node.Location) {
    array_add(watch_files, location.enclosing_load.fully_pathed_filename);
}

get_watch_files :: (watch_files: *[..] string, node: *Code_Struct_Literal_Info) {
    struct_type := (cast(*Type) *node.type_expression.result).*;

    assert(struct_type == ShaderPart, "Found unknown shader hot reloading struct literal type. %\n", struct_type);
    if struct_type != ShaderPart {
        return;
    }

    for arg: node.arguments {
        assert(arg.kind == .LITERAL);
        if arg.kind != .LITERAL {
            return;
        }

        get_watch_files(watch_files, cast(*Code_Literal) arg);
    }
}

get_watch_files :: (watch_files: *[..] string, node: *Code_Array_Literal_Info) {
    for member: node.array_members {
        assert(member.kind == .IDENT);
        if member.kind != .IDENT {
            return;
        }

        get_watch_files(watch_files, cast(*Code_Ident) member);
    }
}

get_watch_files :: (watch_files: *[..] string, node: *Code_Literal) {
    if node.value_type == .STRING {
        get_watch_files(watch_files, node.location);
    } else if node.value_type == .STRUCT {
        get_watch_files(watch_files, node.struct_literal_info);
    } else if node.value_type == .ARRAY {
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

    expression := resolved.expression;
    assert(!!expression);
    if !expression {
        return;
    }

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
    }

    // dedupe
    // I think an inner loop will work with an efficient remove since were starting at the next index
    // and the count doesn't change until the end?
    for watch_file: efficient_remove(*watch_files) {
        should_remove := false;

        for other_index: it_index + 1..watch_files.count - 1 {
            if watch_file == watch_files[other_index] {
                should_remove = true;
                break;
            }
        }

        if should_remove {
            remove;
        }
    }

    return watch_files;
}
