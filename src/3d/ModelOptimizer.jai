
sort_models_by_distance :: (models: [] $T, forward: Vector3) {
    ModelSortInfo :: struct {
        nearest_distance: float;
        index: int;
    }

    sort_info := NewArray(models.count, ModelSortInfo,, temp);
    for model: models {
        nearest_distance := FLOAT32_MAX;
        for vertex: get_vertices(model) {
            nearest_distance = min(nearest_distance, dot(vertex, forward));
        }

        sort_info[it_index] = .{
            nearest_distance,
            it_index,
        };
    }

    quick_sort(sort_info, (a: ModelSortInfo, b: ModelSortInfo) -> float {
        return a.nearest_distance - b.nearest_distance;
    });

    // I guess I have to copy it first? can't think of another way to do it efficiently really...
    old_models := array_copy(models,, temp);

    for i: 0..models.count - 1 {
        models[i] = old_models[sort_info[i].index];
    }
}

SortedGroupIterator :: struct (T: Type, get_group: #type (model: *Renderable) -> $R) {
    GroupType :: R;
    models: [] T;
}

sort_models_by_group_size :: (models: [] $T, $get_group: #type (model: *Renderable) -> $R) -> SortedGroupIterator(T, get_group) {
    return SortedGroupIterator(T, get_group).{models};
}

for_expansion :: (iterator: SortedGroupIterator($T, $get_group), body: Code, flags: For_Flags) #expand {
    #assert(!(flags & .REVERSE));
    #assert(!(flags & .POINTER));

    R :: SortedGroupIterator(T, get_group).GroupType;

    GroupModelCount :: struct {
        group: R;
        count: int;
    }

    group_model_counts: [..] GroupModelCount;
    group_model_counts.allocator = temp;

    models := iterator.models;
    model_groups := NewArray(models.count, R,, temp);

    for model, model_index: models {
        model_groups[model_index] = get_group(model);

        found_group: *GroupModelCount;
        for *group_model_count: group_model_counts {
            if group_model_count.group == model_groups[model_index] {
                found_group = group_model_count;
                break;
            }
        }
        if !found_group {
            found_group = array_add(*group_model_counts);
            found_group.group = model_groups[model_index];
        }

        found_group.count += 1;
    }

    quick_sort(group_model_counts, (a: GroupModelCount, b: GroupModelCount) -> int {
        return b.count - a.count;
    });

    starting_index := 0;
    for group_model_count, group_model_count_index: group_model_counts {
        current_group := group_model_count.group;

        group_start := starting_index;
        group_end_exclusive := starting_index;

        for replace_i: starting_index..models.count - 2 {
            starting_index = replace_i;

            // if the next model has the wrong group we look for the next correct group
            if model_groups[replace_i] != current_group {
                for search_i: replace_i + 1..models.count - 1 {
                    if model_groups[search_i] == current_group {
                        models[replace_i], models[search_i] = models[search_i], models[replace_i];
                        model_groups[replace_i], model_groups[search_i] = model_groups[search_i], model_groups[replace_i];
            
                        group_end_exclusive = replace_i + 1;

                        continue replace_i;
                    }
                }

                // if we didn't find another model in this same group we're done so continue to the next group
                break;
            } else {
                group_end_exclusive = replace_i + 1;
            }
        }

        // here we're done with this group
        group_view: [] T;
        group_view.data = models.data + group_start;
        group_view.count = group_end_exclusive - group_start;

        `it := group_view;
        `it_index := group_model_count_index;

        #insert body;
    }
}

sort_models_optimized :: (models: [] $T, forward: Vector3) {
    for program_group: sort_models_by_group_size(models, get_shader_program) {
        // print("TEXTURES\n");
        // for texture_group: sort_models_by_group_size(program_group, get_texture_hash) {
        //     print("DISTANCE MIN TO MAX\n");
        //     sort_models_by_distance(texture_group, forward);
        // }
        sort_models_by_distance(program_group, forward);
    }
}

#scope_file

get_texture_hash :: (a: *Renderable) -> u32 {
    textures: [..] u32;
    textures.allocator = temp;
    
    uniforms := get_uniforms(a);
    for uniform: uniforms {
        texture_buffer := get_texture_buffer(uniform);
        if texture_buffer {
            array_add(*textures, texture_buffer);
        }
    }

    quick_sort(textures, (a: u32, b: u32) -> int {
        return cast(int) a - cast(int) b;
    });

    return get_hash(textures);
}

get_shader_program :: (a: *Renderable) -> u32 {
    shader: *Shader;
    if #complete a.type == {
        case .Sprite;
            shader = (cast(*Sprite) a).shader;
            if !shader {
                shader = *default_shader;
            }
        case .Model;
            shader = (cast(*Model) a).shader;
            if !shader {
                shader = get_default_shader((cast(*Model) a).geometry.attributes);
            }
        case .InstancedModel;
            shader = (cast(*InstancedModel) a).shader;
            if !shader {
                shader = get_default_shader((cast(*InstancedModel) a).attributes);
            }
    }

    if shader {
        return shader.program;
    }

    return 0;
}

get_uniforms :: (a: *Renderable) -> *ShaderUniforms {
    if #complete a.type == {
        case .Sprite;
            return *(cast(*Sprite) a).uniforms;
        case .Model;
            return *(cast(*Model) a).uniforms;
        case .InstancedModel;
            return *(cast(*InstancedModel) a).uniforms;
    }
}

get_texture_buffer :: (uniform: ShaderUniform) -> u32 {
    if uniform.type == {
        case .Texture;
            return uniform.texture.buffer;
        case .TextureArray;
            return uniform.texture_array.buffer;
        case .Texture3;
            return uniform.texture3.buffer;
        case .CubemapTexture;
            return uniform.cubemap_texture.buffer;
        case .ShadowTexture;
            return uniform.shadow_texture.buffer;
    }
    return 0;
}
