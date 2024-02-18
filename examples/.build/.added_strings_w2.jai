// Workspace: Target Program
//
// #insert text. Generated from C:/Users/Kuju/Projects/KodaJai/examples/../../ContiguousJsonJai/reader.jai:290.
//
if name == "asset" {
InnerType :: #run type_of(result.asset);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 0), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "scene" {
InnerType :: #run type_of(result.scene);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 40), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "buffers" {
InnerType :: #run type_of(result.buffers);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 48), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "bufferViews" {
InnerType :: #run type_of(result.bufferViews);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 88), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "scenes" {
InnerType :: #run type_of(result.scenes);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 128), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "accessors" {
InnerType :: #run type_of(result.accessors);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 168), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "images" {
InnerType :: #run type_of(result.images);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 208), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "samplers" {
InnerType :: #run type_of(result.samplers);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 248), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "textures" {
InnerType :: #run type_of(result.textures);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 288), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "materials" {
InnerType :: #run type_of(result.materials);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 328), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "meshes" {
InnerType :: #run type_of(result.meshes);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 368), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "nodes" {
InnerType :: #run type_of(result.nodes);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 408), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "skins" {
InnerType :: #run type_of(result.skins);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 448), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "animations" {
InnerType :: #run type_of(result.animations);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 456), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else {
index, success = skip_unknown_type(content, index);
if !success {
return index, false;
}
}

//
// #insert text. Generated from C:/Users/Kuju/Projects/KodaJai/examples/../../ContiguousJsonJai/reader.jai:41.
//
if result.asset.copyright {
result.asset.copyright = xx ((cast(*u8) result.asset.copyright) + pointer_offset);
}
if result.asset.generator {
result.asset.generator = xx ((cast(*u8) result.asset.generator) + pointer_offset);
}
if result.asset.minVersion {
result.asset.minVersion = xx ((cast(*u8) result.asset.minVersion) + pointer_offset);
}
if result.buffers.data {
result.buffers.data = xx ((cast(*u8) result.buffers.data) + pointer_offset);
for result_buffers_iterator: 0..result.buffers.count - 1 {
if result.buffers.data[result_buffers_iterator].uri {
result.buffers.data[result_buffers_iterator].uri = xx ((cast(*u8) result.buffers.data[result_buffers_iterator].uri) + pointer_offset);
}
if result.buffers.data[result_buffers_iterator].name {
result.buffers.data[result_buffers_iterator].name = xx ((cast(*u8) result.buffers.data[result_buffers_iterator].name) + pointer_offset);
}
}
}
if result.bufferViews.data {
result.bufferViews.data = xx ((cast(*u8) result.bufferViews.data) + pointer_offset);
for result_bufferViews_iterator: 0..result.bufferViews.count - 1 {
if result.bufferViews.data[result_bufferViews_iterator].byteStride {
result.bufferViews.data[result_bufferViews_iterator].byteStride = xx ((cast(*u8) result.bufferViews.data[result_bufferViews_iterator].byteStride) + pointer_offset);
}
if result.bufferViews.data[result_bufferViews_iterator].target {
result.bufferViews.data[result_bufferViews_iterator].target = xx ((cast(*u8) result.bufferViews.data[result_bufferViews_iterator].target) + pointer_offset);
}
if result.bufferViews.data[result_bufferViews_iterator].name {
result.bufferViews.data[result_bufferViews_iterator].name = xx ((cast(*u8) result.bufferViews.data[result_bufferViews_iterator].name) + pointer_offset);
}
}
}
if result.scenes.data {
result.scenes.data = xx ((cast(*u8) result.scenes.data) + pointer_offset);
for result_scenes_iterator: 0..result.scenes.count - 1 {
if result.scenes.data[result_scenes_iterator].nodes {
result.scenes.data[result_scenes_iterator].nodes = xx ((cast(*u8) result.scenes.data[result_scenes_iterator].nodes) + pointer_offset);
if result.scenes.data[result_scenes_iterator].nodes.data {
result.scenes.data[result_scenes_iterator].nodes.data = xx ((cast(*u8) result.scenes.data[result_scenes_iterator].nodes.data) + pointer_offset);
}
}
if result.scenes.data[result_scenes_iterator].name {
result.scenes.data[result_scenes_iterator].name = xx ((cast(*u8) result.scenes.data[result_scenes_iterator].name) + pointer_offset);
}
}
}
if result.accessors.data {
result.accessors.data = xx ((cast(*u8) result.accessors.data) + pointer_offset);
for result_accessors_iterator: 0..result.accessors.count - 1 {
if result.accessors.data[result_accessors_iterator].bufferView {
result.accessors.data[result_accessors_iterator].bufferView = xx ((cast(*u8) result.accessors.data[result_accessors_iterator].bufferView) + pointer_offset);
}
if result.accessors.data[result_accessors_iterator].max {
result.accessors.data[result_accessors_iterator].max = xx ((cast(*u8) result.accessors.data[result_accessors_iterator].max) + pointer_offset);
if result.accessors.data[result_accessors_iterator].max.data {
result.accessors.data[result_accessors_iterator].max.data = xx ((cast(*u8) result.accessors.data[result_accessors_iterator].max.data) + pointer_offset);
}
}
if result.accessors.data[result_accessors_iterator].min {
result.accessors.data[result_accessors_iterator].min = xx ((cast(*u8) result.accessors.data[result_accessors_iterator].min) + pointer_offset);
if result.accessors.data[result_accessors_iterator].min.data {
result.accessors.data[result_accessors_iterator].min.data = xx ((cast(*u8) result.accessors.data[result_accessors_iterator].min.data) + pointer_offset);
}
}
if result.accessors.data[result_accessors_iterator].sparse {
result.accessors.data[result_accessors_iterator].sparse = xx ((cast(*u8) result.accessors.data[result_accessors_iterator].sparse) + pointer_offset);
}
if result.accessors.data[result_accessors_iterator].name {
result.accessors.data[result_accessors_iterator].name = xx ((cast(*u8) result.accessors.data[result_accessors_iterator].name) + pointer_offset);
}
}
}
if result.images.data {
result.images.data = xx ((cast(*u8) result.images.data) + pointer_offset);
for result_images_iterator: 0..result.images.count - 1 {
if result.images.data[result_images_iterator].uri {
result.images.data[result_images_iterator].uri = xx ((cast(*u8) result.images.data[result_images_iterator].uri) + pointer_offset);
}
if result.images.data[result_images_iterator].mimeType {
result.images.data[result_images_iterator].mimeType = xx ((cast(*u8) result.images.data[result_images_iterator].mimeType) + pointer_offset);
}
if result.images.data[result_images_iterator].bufferView {
result.images.data[result_images_iterator].bufferView = xx ((cast(*u8) result.images.data[result_images_iterator].bufferView) + pointer_offset);
}
if result.images.data[result_images_iterator].name {
result.images.data[result_images_iterator].name = xx ((cast(*u8) result.images.data[result_images_iterator].name) + pointer_offset);
}
}
}
if result.samplers.data {
result.samplers.data = xx ((cast(*u8) result.samplers.data) + pointer_offset);
for result_samplers_iterator: 0..result.samplers.count - 1 {
if result.samplers.data[result_samplers_iterator].magFilter {
result.samplers.data[result_samplers_iterator].magFilter = xx ((cast(*u8) result.samplers.data[result_samplers_iterator].magFilter) + pointer_offset);
}
if result.samplers.data[result_samplers_iterator].minFilter {
result.samplers.data[result_samplers_iterator].minFilter = xx ((cast(*u8) result.samplers.data[result_samplers_iterator].minFilter) + pointer_offset);
}
if result.samplers.data[result_samplers_iterator].name {
result.samplers.data[result_samplers_iterator].name = xx ((cast(*u8) result.samplers.data[result_samplers_iterator].name) + pointer_offset);
}
}
}
if result.textures.data {
result.textures.data = xx ((cast(*u8) result.textures.data) + pointer_offset);
for result_textures_iterator: 0..result.textures.count - 1 {
if result.textures.data[result_textures_iterator].sampler {
result.textures.data[result_textures_iterator].sampler = xx ((cast(*u8) result.textures.data[result_textures_iterator].sampler) + pointer_offset);
}
if result.textures.data[result_textures_iterator].source {
result.textures.data[result_textures_iterator].source = xx ((cast(*u8) result.textures.data[result_textures_iterator].source) + pointer_offset);
}
if result.textures.data[result_textures_iterator].name {
result.textures.data[result_textures_iterator].name = xx ((cast(*u8) result.textures.data[result_textures_iterator].name) + pointer_offset);
}
}
}
if result.materials.data {
result.materials.data = xx ((cast(*u8) result.materials.data) + pointer_offset);
for result_materials_iterator: 0..result.materials.count - 1 {
if result.materials.data[result_materials_iterator].name {
result.materials.data[result_materials_iterator].name = xx ((cast(*u8) result.materials.data[result_materials_iterator].name) + pointer_offset);
}
if result.materials.data[result_materials_iterator].pbrMetallicRoughness {
result.materials.data[result_materials_iterator].pbrMetallicRoughness = xx ((cast(*u8) result.materials.data[result_materials_iterator].pbrMetallicRoughness) + pointer_offset);
if result.materials.data[result_materials_iterator].pbrMetallicRoughness.baseColorTexture {
result.materials.data[result_materials_iterator].pbrMetallicRoughness.baseColorTexture = xx ((cast(*u8) result.materials.data[result_materials_iterator].pbrMetallicRoughness.baseColorTexture) + pointer_offset);
}
if result.materials.data[result_materials_iterator].pbrMetallicRoughness.metallicRoughnessTexture {
result.materials.data[result_materials_iterator].pbrMetallicRoughness.metallicRoughnessTexture = xx ((cast(*u8) result.materials.data[result_materials_iterator].pbrMetallicRoughness.metallicRoughnessTexture) + pointer_offset);
}
}
if result.materials.data[result_materials_iterator].normalTexture {
result.materials.data[result_materials_iterator].normalTexture = xx ((cast(*u8) result.materials.data[result_materials_iterator].normalTexture) + pointer_offset);
}
if result.materials.data[result_materials_iterator].occlusionTexture {
result.materials.data[result_materials_iterator].occlusionTexture = xx ((cast(*u8) result.materials.data[result_materials_iterator].occlusionTexture) + pointer_offset);
}
if result.materials.data[result_materials_iterator].emissiveTexture {
result.materials.data[result_materials_iterator].emissiveTexture = xx ((cast(*u8) result.materials.data[result_materials_iterator].emissiveTexture) + pointer_offset);
}
}
}
if result.meshes.data {
result.meshes.data = xx ((cast(*u8) result.meshes.data) + pointer_offset);
for result_meshes_iterator: 0..result.meshes.count - 1 {
if result.meshes.data[result_meshes_iterator].primitives.data {
result.meshes.data[result_meshes_iterator].primitives.data = xx ((cast(*u8) result.meshes.data[result_meshes_iterator].primitives.data) + pointer_offset);
for result_meshes_data_result_meshes_iterator__primitives_iterator: 0..result.meshes.data[result_meshes_iterator].primitives.count - 1 {
json_object_update_pointers(*result.meshes.data[result_meshes_iterator].primitives.data[result_meshes_data_result_meshes_iterator__primitives_iterator].attributes, pointer_offset);
if result.meshes.data[result_meshes_iterator].primitives.data[result_meshes_data_result_meshes_iterator__primitives_iterator].indices {
result.meshes.data[result_meshes_iterator].primitives.data[result_meshes_data_result_meshes_iterator__primitives_iterator].indices = xx ((cast(*u8) result.meshes.data[result_meshes_iterator].primitives.data[result_meshes_data_result_meshes_iterator__primitives_iterator].indices) + pointer_offset);
}
if result.meshes.data[result_meshes_iterator].primitives.data[result_meshes_data_result_meshes_iterator__primitives_iterator].material {
result.meshes.data[result_meshes_iterator].primitives.data[result_meshes_data_result_meshes_iterator__primitives_iterator].material = xx ((cast(*u8) result.meshes.data[result_meshes_iterator].primitives.data[result_meshes_data_result_meshes_iterator__primitives_iterator].material) + pointer_offset);
}
if result.meshes.data[result_meshes_iterator].primitives.data[result_meshes_data_result_meshes_iterator__primitives_iterator].targets {
result.meshes.data[result_meshes_iterator].primitives.data[result_meshes_data_result_meshes_iterator__primitives_iterator].targets = xx ((cast(*u8) result.meshes.data[result_meshes_iterator].primitives.data[result_meshes_data_result_meshes_iterator__primitives_iterator].targets) + pointer_offset);
if result.meshes.data[result_meshes_iterator].primitives.data[result_meshes_data_result_meshes_iterator__primitives_iterator].targets.data {
result.meshes.data[result_meshes_iterator].primitives.data[result_meshes_data_result_meshes_iterator__primitives_iterator].targets.data = xx ((cast(*u8) result.meshes.data[result_meshes_iterator].primitives.data[result_meshes_data_result_meshes_iterator__primitives_iterator].targets.data) + pointer_offset);
for result_meshes_data_result_meshes_iterator__primitives_data_result_meshes_data_result_meshes_iterator__primitives_iterator__targets_iterator: 0..result.meshes.data[result_meshes_iterator].primitives.data[result_meshes_data_result_meshes_iterator__primitives_iterator].targets.count - 1 {
json_object_update_pointers(*result.meshes.data[result_meshes_iterator].primitives.data[result_meshes_data_result_meshes_iterator__primitives_iterator].targets.data[result_meshes_data_result_meshes_iterator__primitives_data_result_meshes_data_result_meshes_iterator__primitives_iterator__targets_iterator], pointer_offset);
}
}
}
}
}
if result.meshes.data[result_meshes_iterator].weights.data {
result.meshes.data[result_meshes_iterator].weights.data = xx ((cast(*u8) result.meshes.data[result_meshes_iterator].weights.data) + pointer_offset);
}
}
}
if result.nodes.data {
result.nodes.data = xx ((cast(*u8) result.nodes.data) + pointer_offset);
for result_nodes_iterator: 0..result.nodes.count - 1 {
if result.nodes.data[result_nodes_iterator].camera {
result.nodes.data[result_nodes_iterator].camera = xx ((cast(*u8) result.nodes.data[result_nodes_iterator].camera) + pointer_offset);
}
if result.nodes.data[result_nodes_iterator].children {
result.nodes.data[result_nodes_iterator].children = xx ((cast(*u8) result.nodes.data[result_nodes_iterator].children) + pointer_offset);
if result.nodes.data[result_nodes_iterator].children.data {
result.nodes.data[result_nodes_iterator].children.data = xx ((cast(*u8) result.nodes.data[result_nodes_iterator].children.data) + pointer_offset);
}
}
if result.nodes.data[result_nodes_iterator].skin {
result.nodes.data[result_nodes_iterator].skin = xx ((cast(*u8) result.nodes.data[result_nodes_iterator].skin) + pointer_offset);
}
if result.nodes.data[result_nodes_iterator].matrix {
result.nodes.data[result_nodes_iterator].matrix = xx ((cast(*u8) result.nodes.data[result_nodes_iterator].matrix) + pointer_offset);
}
if result.nodes.data[result_nodes_iterator].mesh {
result.nodes.data[result_nodes_iterator].mesh = xx ((cast(*u8) result.nodes.data[result_nodes_iterator].mesh) + pointer_offset);
}
if result.nodes.data[result_nodes_iterator].weights {
result.nodes.data[result_nodes_iterator].weights = xx ((cast(*u8) result.nodes.data[result_nodes_iterator].weights) + pointer_offset);
if result.nodes.data[result_nodes_iterator].weights.data {
result.nodes.data[result_nodes_iterator].weights.data = xx ((cast(*u8) result.nodes.data[result_nodes_iterator].weights.data) + pointer_offset);
}
}
if result.nodes.data[result_nodes_iterator].name {
result.nodes.data[result_nodes_iterator].name = xx ((cast(*u8) result.nodes.data[result_nodes_iterator].name) + pointer_offset);
}
}
}
if result.skins {
result.skins = xx ((cast(*u8) result.skins) + pointer_offset);
if result.skins.data {
result.skins.data = xx ((cast(*u8) result.skins.data) + pointer_offset);
for result_skins_iterator: 0..result.skins.count - 1 {
if result.skins.data[result_skins_iterator].inverseBindMatrices {
result.skins.data[result_skins_iterator].inverseBindMatrices = xx ((cast(*u8) result.skins.data[result_skins_iterator].inverseBindMatrices) + pointer_offset);
}
if result.skins.data[result_skins_iterator].skeleton {
result.skins.data[result_skins_iterator].skeleton = xx ((cast(*u8) result.skins.data[result_skins_iterator].skeleton) + pointer_offset);
}
if result.skins.data[result_skins_iterator].joints.data {
result.skins.data[result_skins_iterator].joints.data = xx ((cast(*u8) result.skins.data[result_skins_iterator].joints.data) + pointer_offset);
}
if result.skins.data[result_skins_iterator].name {
result.skins.data[result_skins_iterator].name = xx ((cast(*u8) result.skins.data[result_skins_iterator].name) + pointer_offset);
}
}
}
}
if result.animations {
result.animations = xx ((cast(*u8) result.animations) + pointer_offset);
if result.animations.data {
result.animations.data = xx ((cast(*u8) result.animations.data) + pointer_offset);
for result_animations_iterator: 0..result.animations.count - 1 {
if result.animations.data[result_animations_iterator].channels.data {
result.animations.data[result_animations_iterator].channels.data = xx ((cast(*u8) result.animations.data[result_animations_iterator].channels.data) + pointer_offset);
for result_animations_data_result_animations_iterator__channels_iterator: 0..result.animations.data[result_animations_iterator].channels.count - 1 {
if result.animations.data[result_animations_iterator].channels.data[result_animations_data_result_animations_iterator__channels_iterator].target.node {
result.animations.data[result_animations_iterator].channels.data[result_animations_data_result_animations_iterator__channels_iterator].target.node = xx ((cast(*u8) result.animations.data[result_animations_iterator].channels.data[result_animations_data_result_animations_iterator__channels_iterator].target.node) + pointer_offset);
}
}
}
if result.animations.data[result_animations_iterator].samplers.data {
result.animations.data[result_animations_iterator].samplers.data = xx ((cast(*u8) result.animations.data[result_animations_iterator].samplers.data) + pointer_offset);
}
if result.animations.data[result_animations_iterator].name {
result.animations.data[result_animations_iterator].name = xx ((cast(*u8) result.animations.data[result_animations_iterator].name) + pointer_offset);
}
}
}
}

//
// #insert text. Generated from C:/Users/Kuju/Projects/KodaJai/examples/../../ContiguousJsonJai/reader.jai:290.
//
if name == "copyright" {
InnerType :: #run type_of(result.copyright);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 0), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "generator" {
InnerType :: #run type_of(result.generator);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 8), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "version" {
InnerType :: #run type_of(result.version);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 16), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "minVersion" {
InnerType :: #run type_of(result.minVersion);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 32), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else {
index, success = skip_unknown_type(content, index);
if !success {
return index, false;
}
}

//
// #insert text. Generated from C:/Users/Kuju/Projects/KodaJai/examples/../../ContiguousJsonJai/reader.jai:290.
//
if name == "uri" {
InnerType :: #run type_of(result.uri);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 0), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "byteLength" {
InnerType :: #run type_of(result.byteLength);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 8), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "name" {
InnerType :: #run type_of(result.name);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 16), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else {
index, success = skip_unknown_type(content, index);
if !success {
return index, false;
}
}

//
// #insert text. Generated from C:/Users/Kuju/Projects/KodaJai/examples/../../ContiguousJsonJai/reader.jai:290.
//
if name == "buffer" {
InnerType :: #run type_of(result.buffer);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 0), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "byteOffset" {
InnerType :: #run type_of(result.byteOffset);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 8), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "byteLength" {
InnerType :: #run type_of(result.byteLength);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 16), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "byteStride" {
InnerType :: #run type_of(result.byteStride);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 24), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "target" {
InnerType :: #run type_of(result.target);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 32), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "name" {
InnerType :: #run type_of(result.name);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 40), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else {
index, success = skip_unknown_type(content, index);
if !success {
return index, false;
}
}

//
// #insert text. Generated from C:/Users/Kuju/Projects/KodaJai/examples/../../ContiguousJsonJai/reader.jai:290.
//
if name == "nodes" {
InnerType :: #run type_of(result.nodes);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 0), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "name" {
InnerType :: #run type_of(result.name);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 8), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else {
index, success = skip_unknown_type(content, index);
if !success {
return index, false;
}
}

//
// #insert text. Generated from C:/Users/Kuju/Projects/KodaJai/examples/../../ContiguousJsonJai/reader.jai:290.
//
if name == "bufferView" {
InnerType :: #run type_of(result.bufferView);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 0), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "byteOffset" {
InnerType :: #run type_of(result.byteOffset);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 8), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "componentType" {
InnerType :: #run type_of(result.componentType);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 16), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "normalized" {
InnerType :: #run type_of(result.normalized);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 24), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "count" {
InnerType :: #run type_of(result.count);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 32), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "type" {
InnerType :: #run type_of(result.type);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 40), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "max" {
InnerType :: #run type_of(result.max);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 56), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "min" {
InnerType :: #run type_of(result.min);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 64), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "sparse" {
InnerType :: #run type_of(result.sparse);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 72), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "name" {
InnerType :: #run type_of(result.name);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 80), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else {
index, success = skip_unknown_type(content, index);
if !success {
return index, false;
}
}

//
// #insert text. Generated from C:/Users/Kuju/Projects/KodaJai/examples/../../ContiguousJsonJai/reader.jai:290.
//
if name == "uri" {
InnerType :: #run type_of(result.uri);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 0), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "mimeType" {
InnerType :: #run type_of(result.mimeType);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 8), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "bufferView" {
InnerType :: #run type_of(result.bufferView);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 16), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "name" {
InnerType :: #run type_of(result.name);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 24), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else {
index, success = skip_unknown_type(content, index);
if !success {
return index, false;
}
}

//
// #insert text. Generated from C:/Users/Kuju/Projects/KodaJai/examples/../../ContiguousJsonJai/reader.jai:290.
//
if name == "magFilter" {
InnerType :: #run type_of(result.magFilter);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 0), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "minFilter" {
InnerType :: #run type_of(result.minFilter);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 8), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "wrapS" {
InnerType :: #run type_of(result.wrapS);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 16), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "wrapT" {
InnerType :: #run type_of(result.wrapT);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 24), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "name" {
InnerType :: #run type_of(result.name);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 32), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else {
index, success = skip_unknown_type(content, index);
if !success {
return index, false;
}
}

//
// #insert text. Generated from C:/Users/Kuju/Projects/KodaJai/examples/../../ContiguousJsonJai/reader.jai:290.
//
if name == "sampler" {
InnerType :: #run type_of(result.sampler);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 0), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "source" {
InnerType :: #run type_of(result.source);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 8), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "name" {
InnerType :: #run type_of(result.name);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 16), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else {
index, success = skip_unknown_type(content, index);
if !success {
return index, false;
}
}

//
// #insert text. Generated from C:/Users/Kuju/Projects/KodaJai/examples/../../ContiguousJsonJai/reader.jai:290.
//
if name == "name" {
InnerType :: #run type_of(result.name);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 0), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "pbrMetallicRoughness" {
InnerType :: #run type_of(result.pbrMetallicRoughness);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 8), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "normalTexture" {
InnerType :: #run type_of(result.normalTexture);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 16), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "occlusionTexture" {
InnerType :: #run type_of(result.occlusionTexture);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 24), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "emissiveTexture" {
InnerType :: #run type_of(result.emissiveTexture);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 32), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "emissiveFactor" {
InnerType :: #run type_of(result.emissiveFactor);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 40), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "alphaMode" {
InnerType :: #run type_of(result.alphaMode);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 56), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "alphaCutoff" {
InnerType :: #run type_of(result.alphaCutoff);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 72), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "doubleSided" {
InnerType :: #run type_of(result.doubleSided);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 76), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else {
index, success = skip_unknown_type(content, index);
if !success {
return index, false;
}
}

//
// #insert text. Generated from C:/Users/Kuju/Projects/KodaJai/examples/../../ContiguousJsonJai/reader.jai:290.
//
if name == "primitives" {
InnerType :: #run type_of(result.primitives);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 0), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "weights" {
InnerType :: #run type_of(result.weights);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 40), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "name" {
InnerType :: #run type_of(result.name);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 80), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else {
index, success = skip_unknown_type(content, index);
if !success {
return index, false;
}
}

//
// #insert text. Generated from C:/Users/Kuju/Projects/KodaJai/examples/../../ContiguousJsonJai/reader.jai:290.
//
if name == "camera" {
InnerType :: #run type_of(result.camera);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 0), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "children" {
InnerType :: #run type_of(result.children);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 8), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "skin" {
InnerType :: #run type_of(result.skin);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 16), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "matrix" {
InnerType :: #run type_of(result.matrix);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 24), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "mesh" {
InnerType :: #run type_of(result.mesh);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 32), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "rotation" {
InnerType :: #run type_of(result.rotation);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 40), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "scale" {
InnerType :: #run type_of(result.scale);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 56), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "translation" {
InnerType :: #run type_of(result.translation);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 68), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "weights" {
InnerType :: #run type_of(result.weights);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 80), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "name" {
InnerType :: #run type_of(result.name);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 88), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else {
index, success = skip_unknown_type(content, index);
if !success {
return index, false;
}
}

//
// #insert text. Generated from C:/Users/Kuju/Projects/KodaJai/examples/../../ContiguousJsonJai/reader.jai:290.
//
if name == "attributes" {
InnerType :: #run type_of(result.attributes);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 0), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "indices" {
InnerType :: #run type_of(result.indices);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 48), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "material" {
InnerType :: #run type_of(result.material);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 56), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "mode" {
InnerType :: #run type_of(result.mode);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 64), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "targets" {
InnerType :: #run type_of(result.targets);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 72), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else {
index, success = skip_unknown_type(content, index);
if !success {
return index, false;
}
}

//
// #insert text. Generated from C:/Users/Kuju/Projects/KodaJai/examples/../../ContiguousJsonJai/reader.jai:290.
//
if name == "inverseBindMatrices" {
InnerType :: #run type_of(result.inverseBindMatrices);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 0), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "skeleton" {
InnerType :: #run type_of(result.skeleton);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 8), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "joints" {
InnerType :: #run type_of(result.joints);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 16), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "name" {
InnerType :: #run type_of(result.name);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 56), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else {
index, success = skip_unknown_type(content, index);
if !success {
return index, false;
}
}

//
// #insert text. Generated from C:/Users/Kuju/Projects/KodaJai/examples/../../ContiguousJsonJai/reader.jai:290.
//
if name == "baseColorFactor" {
InnerType :: #run type_of(result.baseColorFactor);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 0), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "baseColorTexture" {
InnerType :: #run type_of(result.baseColorTexture);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 16), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "metallicFactor" {
InnerType :: #run type_of(result.metallicFactor);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 24), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "roughnessFactor" {
InnerType :: #run type_of(result.roughnessFactor);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 28), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "metallicRoughnessTexture" {
InnerType :: #run type_of(result.metallicRoughnessTexture);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 32), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else {
index, success = skip_unknown_type(content, index);
if !success {
return index, false;
}
}

//
// #insert text. Generated from C:/Users/Kuju/Projects/KodaJai/examples/../../ContiguousJsonJai/reader.jai:290.
//
if name == "index" {
InnerType :: #run type_of(result.index);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 0), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "texCoord" {
InnerType :: #run type_of(result.texCoord);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 8), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "scale" {
InnerType :: #run type_of(result.scale);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 16), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else {
index, success = skip_unknown_type(content, index);
if !success {
return index, false;
}
}

//
// #insert text. Generated from C:/Users/Kuju/Projects/KodaJai/examples/../../ContiguousJsonJai/reader.jai:290.
//
if name == "channels" {
InnerType :: #run type_of(result.channels);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 0), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "samplers" {
InnerType :: #run type_of(result.samplers);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 40), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "name" {
InnerType :: #run type_of(result.name);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 80), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else {
index, success = skip_unknown_type(content, index);
if !success {
return index, false;
}
}

//
// #insert text. Generated from C:/Users/Kuju/Projects/KodaJai/examples/../../ContiguousJsonJai/reader.jai:290.
//
if name == "sampler" {
InnerType :: #run type_of(result.sampler);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 0), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "target" {
InnerType :: #run type_of(result.target);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 8), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else {
index, success = skip_unknown_type(content, index);
if !success {
return index, false;
}
}

//
// #insert text. Generated from C:/Users/Kuju/Projects/KodaJai/examples/../../ContiguousJsonJai/reader.jai:290.
//
if name == "index" {
InnerType :: #run type_of(result.index);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 0), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "texCoord" {
InnerType :: #run type_of(result.texCoord);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 8), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else {
index, success = skip_unknown_type(content, index);
if !success {
return index, false;
}
}

//
// #insert text. Generated from C:/Users/Kuju/Projects/KodaJai/examples/../../ContiguousJsonJai/reader.jai:290.
//
if name == "index" {
InnerType :: #run type_of(result.index);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 0), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "texCoord" {
InnerType :: #run type_of(result.texCoord);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 8), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else {
index, success = skip_unknown_type(content, index);
if !success {
return index, false;
}
}

//
// #insert text. Generated from C:/Users/Kuju/Projects/KodaJai/examples/../../ContiguousJsonJai/reader.jai:290.
//
if name == "count" {
InnerType :: #run type_of(result.count);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 0), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "indices" {
InnerType :: #run type_of(result.indices);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 8), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "values" {
InnerType :: #run type_of(result.values);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 32), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else {
index, success = skip_unknown_type(content, index);
if !success {
return index, false;
}
}

//
// #insert text. Generated from C:/Users/Kuju/Projects/KodaJai/examples/../../ContiguousJsonJai/reader.jai:290.
//
if name == "input" {
InnerType :: #run type_of(result.input);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 0), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "interpolation" {
InnerType :: #run type_of(result.interpolation);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 8), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "output" {
InnerType :: #run type_of(result.output);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 24), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else {
index, success = skip_unknown_type(content, index);
if !success {
return index, false;
}
}

//
// #insert text. Generated from C:/Users/Kuju/Projects/KodaJai/examples/../../ContiguousJsonJai/reader.jai:290.
//
if name == "index" {
InnerType :: #run type_of(result.index);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 0), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "texCoord" {
InnerType :: #run type_of(result.texCoord);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 8), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "strength" {
InnerType :: #run type_of(result.strength);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 16), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else {
index, success = skip_unknown_type(content, index);
if !success {
return index, false;
}
}

//
// #insert text. Generated from C:/Users/Kuju/Projects/KodaJai/examples/../../ContiguousJsonJai/reader.jai:290.
//
if name == "node" {
InnerType :: #run type_of(result.node);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 0), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "path" {
InnerType :: #run type_of(result.path);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 8), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else {
index, success = skip_unknown_type(content, index);
if !success {
return index, false;
}
}

//
// #insert text. Generated from C:/Users/Kuju/Projects/KodaJai/examples/../../ContiguousJsonJai/reader.jai:290.
//
if name == "bufferView" {
InnerType :: #run type_of(result.bufferView);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 0), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "byteOffset" {
InnerType :: #run type_of(result.byteOffset);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 8), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "componentType" {
InnerType :: #run type_of(result.componentType);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 16), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else {
index, success = skip_unknown_type(content, index);
if !success {
return index, false;
}
}

//
// #insert text. Generated from C:/Users/Kuju/Projects/KodaJai/examples/../../ContiguousJsonJai/reader.jai:290.
//
if name == "bufferView" {
InnerType :: #run type_of(result.bufferView);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 0), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "byteOffset" {
InnerType :: #run type_of(result.byteOffset);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 8), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else {
index, success = skip_unknown_type(content, index);
if !success {
return index, false;
}
}

//
// #insert text. Generated from C:/Users/Kuju/Projects/KodaJai/examples/../../ContiguousJsonJai/reader.jai:290.
//
if name == "index" {
InnerType :: #run type_of(result.index);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 0), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else if name == "texCoord" {
InnerType :: #run type_of(result.texCoord);
index, success = json_parse_into(content, index, cast(*InnerType) ((cast(*u8) result) + 8), memory, relative, contiguous_memory, keep_strings_in_place);
if !success {
return index, false;
}
} else {
index, success = skip_unknown_type(content, index);
if !success {
return index, false;
}
}
