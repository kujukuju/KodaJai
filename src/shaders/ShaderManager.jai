
ShaderEntry :: struct {
    attributes: [..] Attribute;
    shader: *Shader;
}

default_shaders: [..] ShaderEntry;

init_default_shaders :: () {
    set_default_shader(.[.Position, .Texcoord], *default_shader);
    set_default_shader(.[.Position, .Normal, .Texcoord], *default_shader3);
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