
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

create_shader :: (vertex: string, fragment: string, name: string = "", location := #caller_location) -> Shader {
    return create_shader(.{}, vertex, .{}, fragment, ifx name then name else get_location_name(location));
}

create_shader :: (vertex_part: ShaderPart, fragment: string, name: string = "", location := #caller_location) -> Shader {
    return create_shader(vertex_part, "", .{}, fragment, ifx name then name else get_location_name(location));
}

create_shader :: (vertex: string, fragment_part: ShaderPart, name: string = "", location := #caller_location) -> Shader {
    return create_shader(.{}, vertex, fragment_part, "", ifx name then name else get_location_name(location));
}

create_shader :: (vertex_part: ShaderPart, fragment_part: ShaderPart, name: string = "", location := #caller_location) -> Shader {
    return create_shader(vertex_part, "", fragment_part, "", ifx name then name else get_location_name(location));
}

create_shader :: (vertex_part: ShaderPart, vertex: string, fragment_part: ShaderPart, fragment: string, name: string = "") -> Shader {
    shader: Shader;
    shader.name = name;
    shader.vertex_parts = flatten_resolve_dependencies(vertex_part);
    shader.fragment_parts = flatten_resolve_dependencies(fragment_part);
    shader.vertex = vertex;
    shader.fragment = fragment;
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
