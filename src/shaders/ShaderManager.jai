
ShaderEntry :: struct {
    attributes: [..] Attribute;
    shader: *Shader;
}

default_shaders: [..] ShaderEntry;

clear_default_shaders :: () {
    while default_shaders.count > 0 {
        remove_default_shader(default_shaders[default_shaders.count - 1].shader);
    }
}

init_default_shaders :: () {
    blur_shader = create_shader(blur_shader_prelim);
    capsule_line_shader3 = create_shader(capsule_line_shader3_prelim);
    cubemap_shader = create_shader(cubemap_shader_prelim);
    default_color_normal_shader3 = create_shader(default_color_normal_shader3_prelim);
    default_color_shader3 = create_shader(default_color_shader3_prelim);
    default_ellipse_shader = create_shader(default_ellipse_shader_prelim);
    default_instanced_shader3 = create_shader(default_instanced_shader3_prelim);
    default_shader = create_shader(default_shader_prelim);
    default_shader3 = create_shader(default_shader3_prelim);
    default_shader_colors3 = create_shader(default_shader_colors3_prelim);
    default_shape_color_shader3 = create_shader(default_shape_color_shader3_prelim);
    default_shape_shader3 = create_shader(default_shape_shader3_prelim);
    flat_grid_shader3 = create_shader(flat_grid_shader3_prelim);
    font_particle_shader = create_shader(font_particle_shader_prelim);
    font_shader = create_shader(font_shader_prelim);
    infinite_grid_shader3 = create_shader(infinite_grid_shader3_prelim);
    instanced_capsule_line_shader3 = create_shader(instanced_capsule_line_shader3_prelim);
    instanced_shader2 = create_shader(instanced_shader2_prelim);
    instanced_shader3 = create_shader(instanced_shader3_prelim);
    occlusion_shader3 = create_shader(occlusion_shader3_prelim);
    rounded_rect_shader = create_shader(rounded_rect_shader_prelim);
    skinned_animation_double_shader3 = create_shader(skinned_animation_double_shader3_prelim);
    skinned_animation_double_texture_shader3 = create_shader(skinned_animation_double_texture_shader3_prelim);
    skinned_animation_no_normal_shader3 = create_shader(skinned_animation_no_normal_shader3_prelim);
    skinned_animation_no_texture_shader3 = create_shader(skinned_animation_no_texture_shader3_prelim);
    skinned_animation_shader3 = create_shader(skinned_animation_shader3_prelim);
    sprite_shader3 = create_shader(sprite_shader3_prelim);
    texture_shader3 = create_shader(texture_shader3_prelim);
    torus_shader3 = create_shader(torus_shader3_prelim);
    transform_shader = create_shader(transform_shader_prelim);
    volumetric_cloud_shader = create_shader(volumetric_cloud_shader_prelim);

    set_default_shader(.[.Position, .Texcoord], *default_shader);
    set_default_shader(.[.Position, .Normal, .Texcoord], *default_shader3);
    set_default_shader(.[.Position, .Normal, .Texcoord, .Vector4, .Vector4, .Vector4, .Vector4], *default_instanced_shader3);
    set_default_shader(.[.Position, .Normal, .Texcoord, .Texcoord], *occlusion_shader3);
    set_default_shader(.[.Position, .Normal, .Texcoord, .Texcoord, .Color], *default_color_normal_shader3);
    set_default_shader(.[.Position, .Normal, .Texcoord, .Color], *default_color_shader3);
    set_default_shader(.[.Position, .Normal, .JointIndices, .JointWeights], *skinned_animation_no_texture_shader3);
    set_default_shader(.[.Position, .Texcoord, .JointIndices, .JointWeights], *skinned_animation_no_normal_shader3);
    set_default_shader(.[.Position, .Normal, .Texcoord, .JointIndices, .JointWeights], *skinned_animation_shader3);
    set_default_shader(.[.Position, .Normal, .Texcoord, .JointIndices, .JointIndices, .JointWeights, .JointWeights], *skinned_animation_double_shader3);
    set_default_shader(.[.Position, .Normal, .Texcoord, .Texcoord, .JointIndices, .JointIndices, .JointWeights, .JointWeights], *skinned_animation_double_texture_shader3);
}

get_default_shader :: (attributes: [] Attribute) -> *Shader {
    for entry: default_shaders {
        if matches_attributes(attributes, entry.attributes) {
            return entry.shader;
        }
    }

    return null;
}

set_default_shader :: (attributes: [] Attribute, shader: *Shader) {
    for *entry, index: default_shaders {
        if matches_attributes(attributes, entry.attributes) {
            entry.shader = shader;
            return;
        }
    }

    // the shader doesn't exist here so we'll add it
    shader_entry := array_add(*default_shaders);
    array_copy(*shader_entry.attributes, attributes);
    shader_entry.shader = shader;
}

remove_default_shader :: (shader: *Shader) {
    for *shader_entry, shader_index: default_shaders {
        if shader_entry.shader == shader {
            array_free(shader_entry.attributes);
            array_ordered_remove_by_index(*default_shaders, shader_index);
            break;
        }
    }
}