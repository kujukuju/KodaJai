











DrawCallContainer :: struct {
    renderables: [..] *Renderable;
}

add_model :: (container: *DrawCallContainer, renderable: *Renderable) {
    if #complete renderable.type == {
        case .Sprite;
            draw(cast(*Sprite) renderable);
        case .Model;
            draw(cast(*Model) renderable);
        case .InstancedModel;
            draw(cast(*InstancedModel) renderable);
    }


    // best_similarity_before := 0;
    // best_similarity := 0;
    // best_similarity_after := 0;
    // best_similarity_index := -1;

    // last_similarity := 0;
    
    // for i: 0..container.renderables.count - 1 {
    //     similarity := get_draw_similarity(container.renderables[i], renderable);
    //     defer last_similarity = similarity;

    //     if similarity >= best_similarity {
    //         if i == 0 {
    //             best_similarity_before = similarity;
    //         } else {
    //             best_similarity_before = last_similarity;
    //         }
    //         best_similarity = similarity;
    //         best_similarity_after = similarity;
    //         best_similarity_index = i;
    //     }

    //     if best_similarity_index >= 0 && best_similarity_index == i - 1 {
    //         best_similarity_after = similarity;
    //     }
    // }

    // if best_similarity_index >= 0 {
    //     if best_similarity_before > best_similarity_after {
    //         array_insert_at(*container.renderables, renderable, best_similarity_index);
    //     } else {
    //         array_insert_at(*container.renderables, renderable, best_similarity_index + 1);
    //     }
    // } else {
    //     array_add(*container.renderables, renderable);
    // }
}

draw :: (container: DrawCallContainer) {
    for renderable: container.renderables {
        if #complete renderable.type == {
            case .Sprite;
                draw(cast(*Sprite) renderable);
            case .Model;
                draw(cast(*Model) renderable);
            case .InstancedModel;
                draw(cast(*InstancedModel) renderable);
        }
    }
}

reset :: (container: *DrawCallContainer) {
    container.renderables.count = 0;
}

destroy :: (container: DrawCallContainer) {
    array_free(container.renderables);
}

#scope_file

get_shader :: inline (a: *Renderable) -> *Shader {
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

    return shader;
}

get_uniforms :: inline (a: *Renderable) -> *ShaderUniforms {
    if #complete a.type == {
        case .Sprite;
            return *(cast(*Sprite) a).uniforms;
        case .Model;
            return *(cast(*Model) a).uniforms;
        case .InstancedModel;
            return *(cast(*InstancedModel) a).uniforms;
    }
}

get_texture_buffer :: inline (uniform: ShaderUniform) -> u32 {
    if uniform.type == {
        case .Texture;
            return uniform.texture.buffer;
        case .TextureArray;
            return uniform.texture_array.buffer;
        case .Texture3;
            return uniform.texture3.buffer;
        case .CubemapTexture;
            return uniform.cubemap_texture.buffer;
    }
    return 0;
}

get_draw_similarity :: inline (a: *Renderable, b: *Renderable) -> int {
    similarity := 0;

    similarity = similarity << 1;
    similarity += ifx a.type == b.type then 1 else 0;

    shader_a := get_shader(a);
    shader_b := get_shader(b);
    assert(shader_a && shader_b);
    
    similarity = similarity << 1;
    similarity += ifx shader_a && shader_b && shader_a.program == shader_b.program then 1 else 0;

    uniforms_a := get_uniforms(a);
    uniforms_b := get_uniforms(b);

    texture_count := 0;
    for uniform_a: uniforms_a {
        texture_buffer_a := get_texture_buffer(uniform_a);
        if !texture_buffer_a {
            continue;
        }

        for uniform_b: uniforms_b {
            texture_buffer_b := get_texture_buffer(uniform_b);
            if texture_buffer_a == texture_buffer_b {
                texture_count += 1;
            }
        }
    }

    texture_count = min(texture_count, (1 << 8) - 1);
    similarity = similarity << 8;
    similarity += texture_count;

    return similarity;
}