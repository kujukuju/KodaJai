
IntermediaryShaderPart :: struct {
    dependency_names: [..] string;
    section: string;
}

// for now I'll assume the files you give it only have 1 actual shader in them
load_external_shader :: (shader_name: string, dependencies: [] string) -> Shader {
    shader_parts: Table(string, IntermediaryShaderPart);
    shader_parts.allocator = temp;

    shader_literals: Table(string, string);
    shader_literals.allocator = temp;

    create_shader_vertex_name: string;
    create_shader_fragment_name: string;

    last_ident: string;
    already_established_shader: bool;
    inside_create_shader_block: bool;
    inside_create_shader_parameter_block: bool;
    current_shader_part: *IntermediaryShaderPart;
    inside_shader_part_dependencies: bool;

    lexer: Lexer;

    for dependency: dependencies {
        print("Reading %\n", dependency);
        contents := read_entire_file(dependency,, temp);
        set_input_from_string(*lexer, contents);

        while true {
            token := peek_next_token(*lexer);
            if token.type == .END_OF_INPUT break;

            eat_token(*lexer);

            if token.type < 128 {
                data: [1] u8;
                data[0] = cast(u8) token.type;
                s: string;
                s.count = 1;
                s.data = data.data;

                if inside_create_shader_block && s == "(" {
                    inside_create_shader_parameter_block = true;
                    assert(last_ident == "create_shader" || last_ident == "create_prelim_shader", "Unknown function call in shader file. %\n", last_ident);
                } else if inside_create_shader_parameter_block && s == ")" {
                    inside_create_shader_block = false;
                    inside_create_shader_parameter_block = false;
                } else if inside_shader_part_dependencies && s == "]" {
                    inside_shader_part_dependencies = false;
                } else if current_shader_part && s == "}" {
                    current_shader_part = null;
                }
            } else {
                if token.type == {
                    case .IDENT;
                        ident := token.ident_value.name;
                        defer last_ident = ident;

                        if inside_create_shader_parameter_block && !create_shader_vertex_name {
                            create_shader_vertex_name = ident;
                        } else if inside_create_shader_parameter_block && !create_shader_fragment_name {
                            create_shader_fragment_name = ident;
                        } else if inside_create_shader_parameter_block && create_shader_vertex_name && create_shader_fragment_name && ident != "name" {
                            assert(false, "Inside create shader parameter block and found an ident without being able to assign it to anywhere.\n");
                        } else if ident == "create_shader" || ident == "create_prelim_shader" {
                            assert(!already_established_shader, "Trying to create a shader twice in a single group of file dependencies.\n");
                            inside_create_shader_block = true;
                            already_established_shader = true;
                        } else if ident == "ShaderPart" {
                            part := IntermediaryShaderPart.{};
                            part.dependency_names.allocator = temp;

                            part_exists := table_contains(*shader_parts, last_ident);
                            assert(!part_exists, "Shader part already has been found. % %\n", last_ident, dependency);

                            current_shader_part = table_set(*shader_parts, last_ident, part);
                        } else if inside_shader_part_dependencies {
                            assert(!!current_shader_part, "Found shader part dependencies without having a shader.\n");
                            array_add(*current_shader_part.dependency_names, ident);
                        }

                    case .STRING;
                        if current_shader_part {
                            current_shader_part.section = token.string_value;
                        } else if inside_create_shader_parameter_block && create_shader_vertex_name && create_shader_fragment_name {
                            // ignore name
                        } else {
                            literal_exists := table_contains(*shader_literals, last_ident);
                            assert(!literal_exists, "Found a shader literal but it already exists. %\n", last_ident);

                            table_set(*shader_literals, last_ident, token.string_value);
                        }

                    case .BEGIN_ARRAY_LITERAL;
                        assert(!!current_shader_part, "Found array literal without being inside a shader part.\n");
                        
                        inside_shader_part_dependencies = true;

                    case;
                }
            }
        }
    }

    reconstruct_shader_part :: (intermediary: IntermediaryShaderPart, shader_parts: *Table(string, IntermediaryShaderPart)) -> ShaderPart {
        shader_part: ShaderPart;
        shader_part.dependencies = NewArray(intermediary.dependency_names.count, ShaderPart,, temp);

        for dependency_name: intermediary.dependency_names {
            intermediary_dependency, found := table_find(shader_parts, dependency_name);
            assert(found, "Could not find required intermediary part. %\n", dependency_name);
            if !found {
                continue;
            }
            shader_part.dependencies[it_index] = reconstruct_shader_part(intermediary_dependency, shader_parts);
        }

        shader_part.section = intermediary.section;

        return shader_part;
    }

    shader: Shader;

    if table_contains(*shader_literals, create_shader_vertex_name) && table_contains(*shader_literals, create_shader_fragment_name) {
        vert_part, vert_found := table_find(*shader_literals, create_shader_vertex_name);
        frag_part, frag_found := table_find(*shader_literals, create_shader_fragment_name);

        shader = create_shader(vert_part, frag_part, watch_files = false);
    } else if table_contains(*shader_literals, create_shader_vertex_name) && table_contains(*shader_parts, create_shader_fragment_name) {
        vert_part, vert_found := table_find(*shader_literals, create_shader_vertex_name);
        frag_part, frag_found := table_find(*shader_parts, create_shader_fragment_name);

        shader = create_shader(vert_part, reconstruct_shader_part(frag_part, *shader_parts), watch_files = false);
    } else if table_contains(*shader_parts, create_shader_vertex_name) && table_contains(*shader_literals, create_shader_fragment_name) {
        vert_part, vert_found := table_find(*shader_parts, create_shader_vertex_name);
        frag_part, frag_found := table_find(*shader_literals, create_shader_fragment_name);

        shader = create_shader(reconstruct_shader_part(vert_part, *shader_parts), frag_part, watch_files = false);
    } else if table_contains(*shader_parts, create_shader_vertex_name) && table_contains(*shader_parts, create_shader_fragment_name) {
        vert_part, vert_found := table_find(*shader_parts, create_shader_vertex_name);
        frag_part, frag_found := table_find(*shader_parts, create_shader_fragment_name);

        shader = create_shader(reconstruct_shader_part(vert_part, *shader_parts), reconstruct_shader_part(frag_part, *shader_parts), watch_files = false);
    } else {
        assert(false, "Could not find where the create shader dependencies live. % %", create_shader_vertex_name, create_shader_fragment_name);
    }

    // print("Creating a shader...\n");
    // print("\tVert: %\n", create_shader_vertex_name);
    // print("\tFrag: %\n", create_shader_fragment_name);

    // name_dependencies: [..] string;
    // name_dependencies.allocator = temp;

    // array_add(*name_dependencies, create_shader_vertex_name);
    // array_add(*name_dependencies, create_shader_fragment_name);

    // while name_dependencies.count > 0 {
    //     dependency := name_dependencies[0];
    //     array_ordered_remove_by_index(*name_dependencies, 0);

    //     if table_contains(*shader_literals, dependency) {
    //         literal, literal_found := table_find(*shader_literals, dependency);
    //         print("\n%\n", literal);
    //     }

    //     if table_contains(*shader_parts, dependency) {
    //         part, part_found := table_find(*shader_parts, dependency);

    //         print("\n%\n", part.section);

    //         array_add(*name_dependencies, ..part.dependency_names);
    //     }
    // }

    return shader;
}

#import "Jai_Lexer";
