
ModelAnimations :: struct {
    // the entire traversed hierarchy of all the bones, some of which aren't included in the skin calculations
    bone_hierarchy: [..] AnimationJoint;
    // these are the indices into the bone_hierarchy that the shader expects as a uniform
    joint_indices: [..] int;
    // the inverse binds only for the respective joint_indices
    inverse_binds: [..] Matrix4;
    // the actual animation frames if available
    animations: [..] Animation;
}

Animation :: struct {
    name: string;
    // the indices are the bone indices, the inner indices are for the animation frames
    frames: [..][..] AnimationFrame;
    // these are the relevancy weights for a given animation
    bone_weights: [..] float;
}

AnimationJoint :: struct {
    name: string;
    transform: Matrix4 = Matrix4Identity;
    translation: Vector3 = .{0, 0, 0};
    rotation: Quaternion = .{0, 0, 0, 1};
    scale: Vector3 = .{1, 1, 1};
    parent: int;
}

AnimationFrame :: struct {
    frame: float;
    translation: Vector3 = .{0, 0, 0};
    rotation: Quaternion = .{0, 0, 0, 1};
    scale: Vector3 = .{1, 1, 1};
}

AnimationMix :: struct {
    name: string;
    weight: float;
    absolute: bool = false;
}

load_animations :: (path: string, name_override: string = "", base_only: bool = false, stationary_bone: string = "") -> ModelAnimations, bool {
    animations: ModelAnimations;
    success := load_animations(*animations, path, name_override, base_only, stationary_bone);
    if !success {
        destroy(animations);
        return .{}, false;
    }

    return animations, true;
}

load_animations :: (animations: *ModelAnimations, path: string, name_override: string = "", base_only: bool = false, stationary_bone: string = "") -> bool {
    file, success := read_entire_file(path);
    defer free(file);
    if !success {
        return false;
    }

    if ends_with(path, ".glb") {
        success := load_animation_glb(animations, file, name_override, base_only, stationary_bone);
        if !success {
            return false;
        }

        return true;
    } else if ends_with(path, ".gltf") {
        success := load_animation_gltf(animations, file, path, name_override, base_only, stationary_bone);
        if !success {
            return false;
        }

        return true;
    } else {
        print("Unknown file type. %\n", path);
        return false;
    }
}

load_remap_animations :: (target: string, animation_source: string, remap: [] [2] string, name_override: string = "") -> ModelAnimations, bool {
    animations: ModelAnimations;
    load_animations(*animations, target, base_only = true);

    success := load_remap_animations(*animations, target, animation_source, remap, name_override);
    if !success {
        destroy(animations);
        return .{}, false;
    }

    return animations, true;
}

load_remap_animations :: (animations: *ModelAnimations, animation_source: string, remap: [] [2] string, name_override: string = "") -> bool {
    source_animations, source_success := load_animations(animation_source, name_override);
    defer destroy(source_animations);
    if !source_success {
        return false;
    }

    if !remap_animations(animations, source_animations, remap) {
        return false;
    }

    // for animation: source_animations.animations {
    //     print("source animation name %\n", animation.name);
    //     print("source animation frames %\n", animation.frames);
    // }

    return true;
}

remap_animations :: (animations: *ModelAnimations, source: ModelAnimations, remap: [] [2] string) -> bool {
    assert(!!animations.bone_hierarchy, "You cannot remap animations if you haven't yet established any bones.");

    target_name_indices: Table(string, int);
    target_name_indices.allocator = temp;
    for joint, index: animations.bone_hierarchy {
        if !joint.name {
            continue;
        }

        table_set(*target_name_indices, joint.name, index);
    }

    source_name_indices: Table(string, int);
    source_name_indices.allocator = temp;
    for joint, index: source.bone_hierarchy {
        if !joint.name {
            continue;
        }

        table_set(*source_name_indices, joint.name, index);
    }

    // the index remap from the target to the source
    target_to_source_indices: Table(int, int);
    target_to_source_indices.allocator = temp;
    for pair: remap {
        target_index, has_target_index := table_find(*target_name_indices, pair[1]);
        if !has_target_index {
            print("Target bone does not exist %\n", pair[1]);
        }
        assert(has_target_index, "If you specified a target bone to map it must exist.");

        source_index, has_source_index := table_find(*source_name_indices, pair[0]);
        if !has_source_index {
            print("Source bone does not exist %\n", pair[0]);
        }
        assert(has_source_index, "If you specified a source bone to map it must exist.");

        table_set(*target_to_source_indices, target_index, source_index);
    }

    for joint, index: animations.bone_hierarchy {
        if !joint.name {
            continue;
        }

        map_index, has_map_index := table_find(*target_to_source_indices, index);
        if !has_map_index {
            print("Warning. The target has a bone that wasn't mapped: %\n", joint.name);
        }
    }

    // target_binds: [..] Matrix4;
    // target_binds.allocator = temp;
    // array_resize(*target_binds, animations.bone_hierarchy.count);
    // for i: 0..target_binds.count - 1 {
    //     parent := Matrix4Identity;
    //     if animations.bone_hierarchy[i].parent != i {
    //         parent = target_binds[animations.bone_hierarchy[i].parent];
    //     }

    //     target_binds[i] = parent * animations.bone_hierarchy[i].transform;
    // }

    // source_binds: [..] Matrix4;
    // source_binds.allocator = temp;
    // array_resize(*source_binds, source.bone_hierarchy.count);
    // for i: 0..source_binds.count - 1 {
    //     parent := Matrix4Identity;
    //     if source.bone_hierarchy[i].parent != i {
    //         parent = source_binds[source.bone_hierarchy[i].parent];
    //     }

    //     source_binds[i] = parent * source.bone_hierarchy[i].transform;
    // }

    local_binds: [..] Matrix4;
    local_binds.allocator = temp;
    array_resize(*local_binds, animations.bone_hierarchy.count);
    for joint, index: animations.bone_hierarchy {
        // local_binds[index] = target_binds[index];
        local_binds[index] = joint.transform;
    }

    local_inverse_binds: [..] Matrix4;
    local_inverse_binds.allocator = temp;
    array_resize(*local_inverse_binds, animations.bone_hierarchy.count);
    for joint, index: animations.bone_hierarchy {
        // local_inverse_binds[index] = inverse(target_binds[index]);
        local_inverse_binds[index] = inverse(joint.transform);
    }

    local_binds_source: [..] Matrix4;
    local_binds_source.allocator = temp;
    array_resize(*local_binds_source, source.bone_hierarchy.count);
    for joint, index: source.bone_hierarchy {
        // local_inverse_binds_source[index] = source_binds[index];
        local_binds_source[index] = joint.transform;
    }

    local_inverse_binds_source: [..] Matrix4;
    local_inverse_binds_source.allocator = temp;
    array_resize(*local_inverse_binds_source, source.bone_hierarchy.count);
    for joint, index: source.bone_hierarchy {
        // local_inverse_binds_source[index] = inverse(source_binds[index]);
        local_inverse_binds_source[index] = inverse(joint.transform);
    }

    node_count := animations.bone_hierarchy.count;

    // get the world bind transforms to calculate new bind transforms at the end
    world_bind_transforms: [..] Matrix4;
    world_bind_transforms.allocator = temp;
    get_joints(animations, *world_bind_transforms);

    array_reserve(*animations.animations, animations.animations.count + source.animations.count);

    for animation_index: 0..source.animations.count - 1 {
        animation := array_add(*animations.animations);

        source_animation := source.animations[animation_index];
        array_copy(*animation.bone_weights, source_animation.bone_weights);

        animation.name = copy_string(source_animation.name);

        array_resize(*animation.bone_weights, node_count);
        for joint_index: 0..node_count - 1 {
            source_joint_index, has_source_index := table_find(*target_to_source_indices, joint_index);
            if has_source_index {
                animation.bone_weights[joint_index] = source_animation.bone_weights[source_joint_index];
            }
        }

        print("at animation %\n", animation.name);

        array_resize(*animation.frames, node_count);
        if !source_animation.frames {
            continue;
        }

        print("writing frames % %\n", animation.name, animation.frames.count);

        for joint_index: 0..animation.frames.count - 1 {
            // we only apply the frames if they exist because otherwise the data will
            // get pulled from the bind pose in the hierarchy
            source_joint_index, has_source_index := table_find(*target_to_source_indices, joint_index);
            if has_source_index && source_animation.frames[source_joint_index].count > 0 {
                array_copy(*animation.frames[joint_index], source_animation.frames[source_joint_index]);

                target_translation := animations.bone_hierarchy[joint_index].translation;
                target_scale := animations.bone_hierarchy[joint_index].scale;

                target_local_bind := local_binds[joint_index];
                target_local_inverse_bind := local_inverse_binds[joint_index];
                source_local_bind := local_binds_source[source_joint_index];
                source_local_inverse_bind := local_inverse_binds_source[source_joint_index];

                for frame_index: 0..animation.frames[joint_index].count - 1 {
                    transform := Matrix4Identity;
                    transform = translate(transform, animation.frames[joint_index][frame_index].translation);
                    transform = rotate(transform, animation.frames[joint_index][frame_index].rotation);
                    transform = scale(transform, animation.frames[joint_index][frame_index].scale);

                    // stick_to_goblin := target_local_bind * source_local_inverse_bind;
                    // goblin_to_stick := source_local_bind * target_local_inverse_bind;
                    // modified_transform := goblin_to_stick * transform * stick_to_goblin;

                    // skeleton_to_goblin_bind := target_local_bind * source_local_inverse_bind;

                    modified_transform := target_local_bind * inverse(source_local_inverse_bind * transform);
                    // modified_transform := transform * source_local_bind * target_local_inverse_bind;
                    modified_translation, modified_rotation, modified_scale := decompose_matrix4(modified_transform);

                    animation.frames[joint_index][frame_index].translation = target_translation; // modified_translation;
                    animation.frames[joint_index][frame_index].rotation = modified_rotation;
                    animation.frames[joint_index][frame_index].scale = target_scale; // modified_scale;
                }
            } else if has_source_index {
                frame := array_add(*animation.frames[joint_index]);

                target_translation := animations.bone_hierarchy[joint_index].translation;
                target_scale := animations.bone_hierarchy[joint_index].scale;

                target_local_bind := local_binds[joint_index];
                target_local_inverse_bind := local_inverse_binds[joint_index];
                source_local_bind := local_binds_source[source_joint_index];
                source_local_inverse_bind := local_inverse_binds_source[source_joint_index];

                // modified_transform := source_local_bind * target_local_inverse_bind;
                modified_transform := source_local_inverse_bind * target_local_bind;
                modified_translation, modified_rotation, modified_scale := decompose_matrix4(modified_transform);

                frame.translation = target_translation; // modified_translation;
                frame.rotation = modified_rotation;
                frame.scale = target_scale; // modified_scale;
            }
        }
    }

    return true;
}

destroy :: (animations: ModelAnimations) {
    // these are shared arrays
    array_free(animations.bone_hierarchy);
    array_free(animations.joint_indices);
    array_free(animations.inverse_binds);

    // these are not shared memory
    for animation: animations.animations {
        free(animation.name);
        array_free(animation.frames);
        array_free(animation.bone_weights);
    }

    array_free(animations.animations);
}

// this will apply the animations in the order received, not all at the same time
// as such the weights dont have to add up to 1, you can merge with the previous animation to create a new animation
// and then completely overwrite part of the new animation
// for example, if you want to mix walk directions (50%/50%) and then have the character holding a bow (100%)
// get_joints :: (animations: [..] Animation, mix: [] AnimationMix, frame: float, $count: int) -> [count] Matrix4 {
//     return get_joints(animations, ..mix, frame, count);
// }

// if you give this an absolute animation, a weight of 1.0 will factor in bone relevancy weights and
// completely override any previous animation data for the maximum bone
// if you aren't using absolute animations, a weight of 1.0 will be treated as mixed into the existing weights provided
// so 0.5 -> 0.5 -> 1.0, the last animation would be weighted at 2x the other strengths, and 1.0 -> 1.0 -> 1.0, the last
// animation is equal to the previous mixed animation strength
get_joints :: (animations: ModelAnimations, mix: [] AnimationMix, frame: float, $count: int) -> [count] Matrix4 {
    assert(animations.animations.count > 0);
    assert(mix.count > 0);
    // assert(mix[0].weight == 1, "The way this animation mixing works it doesn't make sense to start with anything other than 1.");

    bone_count := animations.bone_hierarchy.count;

    TransformEntry :: struct {
        translation: Vector3;
        rotation: Quaternion;
        scale: Vector3;
    }

    current_weights: [..] float;
    current_weights.allocator = temp;
    array_resize(*current_weights, bone_count);

    current: [..] TransformEntry;
    current.allocator = temp;
    array_resize(*current, bone_count);

    found_any := false;

    for i: 0..mix.count - 1 {
        animation: Animation;
        for current: animations.animations {
            if current.name == mix[i].name {
                animation = current;
                found_any = true;
                break;
            }
        }

        // the way well do this is well only increment the index when the bones frame count is not 0
        // then well do the same thing when were applying the animations
        for bone_index: 0..animation.frames.count - 1 {
            // if we're using an absolute animation we will respect the weight of the individual bones, otherwise we don't because they're mixed never overwritten
            bone_weight: float;
            if mix[i].absolute {
                bone_weight = max(mix[i].weight, 0.0) * animation.bone_weights[bone_index];
            } else {
                bone_weight = max(mix[i].weight, 0.0);
            }

            if animation.frames[bone_index].count > 0 {
                translation, rotation, scale := get_interpolated_components(animation.frames[bone_index], frame);

                if current_weights[bone_index] == 0 && i == 0 {
                    current[bone_index].translation = translation;
                    current[bone_index].rotation = rotation;
                    current[bone_index].scale = scale;

                    current_weights[bone_index] = bone_weight;
                } else if bone_weight > 0 {
                    percentage_new: float;
                    if mix[i].absolute {
                        percentage_new = bone_weight;
                    } else {
                        percentage_new = bone_weight / (bone_weight + current_weights[bone_index]);
                    }

                    current[bone_index].translation = lerp(current[bone_index].translation, translation, percentage_new);
                    current[bone_index].rotation = quat_slerp(current[bone_index].rotation, rotation, percentage_new);
                    current[bone_index].scale = lerp(current[bone_index].scale, scale, percentage_new);
                    
                    current_weights[bone_index] = lerp(current_weights[bone_index], bone_weight, percentage_new);
                }
            } else {
                translation := animations.bone_hierarchy[bone_index].translation;
                rotation := animations.bone_hierarchy[bone_index].rotation;
                scale := animations.bone_hierarchy[bone_index].scale;

                if current_weights[bone_index] == 0 && i == 0 {
                    current[bone_index].translation = translation;
                    current[bone_index].rotation = rotation;
                    current[bone_index].scale = scale;

                    current_weights[bone_index] = bone_weight;
                } else if bone_weight > 0 {
                    percentage_new: float;
                    if mix[i].absolute {
                        percentage_new = bone_weight;
                    } else {
                        percentage_new = bone_weight / (bone_weight + current_weights[bone_index]);
                    }

                    current[bone_index].translation = lerp(current[bone_index].translation, translation, percentage_new);
                    current[bone_index].rotation = quat_slerp(current[bone_index].rotation, rotation, percentage_new);
                    current[bone_index].scale = lerp(current[bone_index].scale, scale, percentage_new);
                    
                    current_weights[bone_index] = lerp(current_weights[bone_index], bone_weight, percentage_new);
                }
            }
        }
    }

    // if not a single animation was found return the bind pose
    if !found_any {
        output: [count] Matrix4;
        get_joints(animations, *output);
        return output;
    }

    // now the same animation code
    joints_bones: [..] Matrix4;
    joints_bones.allocator = temp;
    array_reserve(*joints_bones, bone_count);
    joints_bones.count = bone_count;

    for i: 0..bone_count - 1 {
        joint := animations.bone_hierarchy[i];

        // if the joint parent isn't itself then set the parent
        // parent_transform := animation.world;
        parent_transform := Matrix4Identity;
        if joint.parent != i {
            parent_transform = joints_bones[joint.parent];
            empty: Matrix4;
            assert(parent_transform != empty, "If there's a parent it shouldn't be empty. At least identity.");
        }

        bone_translation := current[i].translation;
        bone_rotation := current[i].rotation;
        bone_scale := current[i].scale;

        interpolated_matrix := Matrix4Identity;
        interpolated_matrix = translate(interpolated_matrix, bone_translation);
        interpolated_matrix = rotate(interpolated_matrix, bone_rotation);
        interpolated_matrix = scale(interpolated_matrix, bone_scale);

        // local_transform := interpolated_matrix;
        joints_bones[i] = parent_transform * interpolated_matrix;
    }

    joints: [count] Matrix4;

    for i: 0..animations.joint_indices.count - 1 {
        real_index := animations.joint_indices[i];
        joints[i] = joints_bones[real_index];
    }

    for i: 0..animations.inverse_binds.count - 1 {
        joints[i] = joints[i] * animations.inverse_binds[i];
        // joints[i] = animation.inverse_world * joints[i];
    }

    return joints;
}

get_joints :: (animations: ModelAnimations, $count: int) -> [count] Matrix4 {
    joints: [count] Matrix4;
    casted: [] Matrix4;
    casted.data = output.data;
    casted.count = count;
    get_joints(animations, *casted);

    return joints;
}

get_joints :: (animations: ModelAnimations, joints: *[..] Matrix4) {
    if joints.count < animations.joint_indices.count {
        array_resize(joints, animations.joint_indices.count);
    }

    casted_joints := cast(*[] Matrix4) joints;

    get_joints(animations, casted_joints);
}

get_joints :: (animations: ModelAnimations, joints: *[] Matrix4) {
    assert(joints.count >= animations.joint_indices.count);

    joints_bones: [..] Matrix4;
    joints_bones.allocator = temp;
    array_reserve(*joints_bones, animations.bone_hierarchy.count);
    joints_bones.count = animations.bone_hierarchy.count;

    for i: 0..animations.bone_hierarchy.count - 1 {
        joint := animations.bone_hierarchy[i];

        // if the joint parent isn't itself then set the parent
        parent_transform := Matrix4Identity;
        if joint.parent != i {
            parent_transform = joints_bones[joint.parent];
            empty: Matrix4;
            assert(parent_transform != empty, "If there's a parent it shouldn't be empty. At least identity.");
        }

        interpolated_matrix := joint.transform;
        joints_bones[i] = parent_transform * interpolated_matrix;
    }

    for i: 0..animations.joint_indices.count - 1 {
        real_index := animations.joint_indices[i];
        joints.data[i] = joints_bones[real_index];
    }

    for i: 0..animations.inverse_binds.count - 1 {
        joints.data[i] = joints.data[i] * animations.inverse_binds[i];
    }
}

get_joints :: (animations: ModelAnimations, name: string, frame: float, $count: int) -> [count] Matrix4 {
    for animation: animations.animations {
        if animation.name == name {
            return get_joints(animations, animation, frame, count);
        }
    }

    // if not a single animation was found return the bind pose
    output: [count] Matrix4;
    casted: [] Matrix4;
    casted.data = output.data;
    casted.count = count;
    get_joints(animations, *casted);
    return output;
}

get_joints :: (animations: ModelAnimations, animation: Animation, frame: float, $count: int) -> [count] Matrix4 {
    joints_bones: [..] Matrix4;
    joints_bones.allocator = temp;
    array_reserve(*joints_bones, animations.bone_hierarchy.count);
    joints_bones.count = animations.bone_hierarchy.count;

    for i: 0..animations.bone_hierarchy.count - 1 {
        joint := animations.bone_hierarchy[i];

        // if the joint parent isn't itself then set the parent
        parent_transform := Matrix4Identity;
        if joint.parent != i {
            parent_transform = joints_bones[joint.parent];
            empty: Matrix4;
            assert(parent_transform != empty, "If there's a parent it shouldn't be empty. At least identity.");
        }

        interpolated_matrix: Matrix4;
        if animation.frames[i].count == 0 {
            interpolated_matrix = joint.transform;
        } else {
            interpolated_matrix = get_interpolated_matrix(animation.frames[i], frame);
        }

        joints_bones[i] = parent_transform * interpolated_matrix;
    }

    joints: [count] Matrix4;

    for i: 0..animations.joint_indices.count - 1 {
        real_index := animations.joint_indices[i];
        joints[i] = joints_bones[real_index];
    }

    for i: 0..animations.inverse_binds.count - 1 {
        joints[i] = joints[i] * animations.inverse_binds[i];
    }

    return joints;
}

#scope_file

load_animation_glb :: (animations: *ModelAnimations, file: string, name_override: string, base_only: bool, stationary_bone: string) -> bool {
    json, binary, json_memory, valid := load_glb(file);
    defer free(json_memory);
    if !valid {
        return false;
    }

    print("Beginning load...\n");

    success := load_animation_gltf_data(animations, json, binary, name_override, base_only, stationary_bone);
    print("Load was %\n", success);
    return success;
}

load_animation_gltf :: (animations: *ModelAnimations, file: string, path: string, name_override: string, base_only: bool, stationary_bone: string) -> bool {
    json, binary, json_memory, valid := load_gltf(file, path);
    defer free(json_memory);
    if !valid {
        return false;
    }

    success := load_animation_gltf_data(animations, json, binary, name_override, base_only, stationary_bone);
    return success;
}

load_animation_gltf_data :: (animations: *ModelAnimations, json: GltfJson, binary: [] u8, name_override: string, base_only: bool, stationary_bone: string) -> bool {
    assert(json.scenes.count == 1, "I'm not sure how to handle multiple scenes.");
    scene := json.scenes[0];
    assert(!!scene.nodes, "I'm not sure how to handle the root node not being labelled.");

    if name_override {
        assert(json.animations.count == 1, "You can't override an animation name if there's more than 1 animation.");
    }

    node_count, buffers, bufferviews, accessors, node_to_bone_remap, bone_to_node_remap, skin_joints := precursory_animation_code(json, binary);
    defer array_free(buffers);
    defer array_free(bufferviews);
    defer array_free(accessors);

    // bone hierarchy
    if !animations.bone_hierarchy {
        array_resize(*animations.bone_hierarchy, node_count);

        for bone_index: 0..node_count - 1 {
            node_index := << table_find_pointer(*bone_to_node_remap, bone_index);
            node := json.nodes[node_index];

            if node.name {
                animations.bone_hierarchy[bone_index].name = copy_string(<< node.name);
            }

            animations.bone_hierarchy[bone_index].transform = get_transform(node);

            bone_translation, bone_rotation, bone_scale := decompose_matrix4(animations.bone_hierarchy[bone_index].transform);
            animations.bone_hierarchy[bone_index].translation = bone_translation;
            animations.bone_hierarchy[bone_index].rotation = bone_rotation;
            animations.bone_hierarchy[bone_index].scale = bone_scale;

            // every child should have a prent except the root node which is 0 so its a parent to itself
            // so we don't have to worry about this
            if node.children {
                for i: 0..node.children.count - 1 {
                    child_node_index := node.children.data[i];
                    child_bone_index := << table_find_pointer(*node_to_bone_remap, child_node_index);

                    assert(animations.bone_hierarchy[child_bone_index].parent == 0, "Attempting to double set a childs parent.");
                    animations.bone_hierarchy[child_bone_index].parent = bone_index;
                }
            }
        }
    }

    // joint indices
    if !animations.joint_indices {
        array_reserve(*animations.joint_indices, skin_joints.count);
        animations.joint_indices.count = skin_joints.count;

        for i: 0..skin_joints.count - 1 {
            animations.joint_indices[i] = << table_find_pointer(*node_to_bone_remap, skin_joints[i]);
        }
    }

    // inverse binds
    if !animations.inverse_binds {
        array_reserve(*animations.inverse_binds, skin_joints.count);
        animations.inverse_binds.count = skin_joints.count;

        if json.skins && json.skins.count > 0 && json.skins.data[0].inverseBindMatrices {
            assert(json.skins.count == 1, "Not sure how to handle multiple skins.");

            matrix_accessor := get_accessor_view(accessors[<< json.skins.data[0].inverseBindMatrices], "MAT4");
            assert(matrix_accessor.count == skin_joints.count, "I think you must have the same number of inverse binds as inner joints.");

            for i: 0..matrix_accessor.count - 1 {
                animations.inverse_binds[i] = transpose(matrix_accessor[i]);
            }
        } else {
            for i: 0..skin_joints.count - 1 {
                node := json.nodes[skin_joints[i]];
                animations.inverse_binds[i] = inverse(get_transform(node));
            }
        }
    }

    // animations
    if !base_only {
        array_reserve(*animations.animations, animations.animations.count + json.animations.count);

        for animation_index: 0..json.animations.count - 1 {
            current_animation := json.animations.data[animation_index];

            animation := array_add(*animations.animations);
            // animation.world = world_transform;
            // animation.inverse_world = inverse(world_transform);

            if name_override {
                animation.name = copy_string(name_override);
            } else if current_animation.name && current_animation.name.count > 0 {
                animation.name = copy_string(<< current_animation.name);
            }

            print("Animation: %\n", animation.name);

            // the animation samplers inputs are times
            // the animation samplers outputs are the transformations, presumably for each time

            // the animation channels sampler is the animation sampler
            // the animation channels target is the node entry in the hierarchy and the type of transformation

            array_resize(*animation.frames, node_count);

            for channel: current_animation.channels {
                assert(!!channel.target.node, "I'm not sure what it would mean for a channel target to not have a node (hierarchy index).");

                sampler_index := channel.sampler;
                node_index := << channel.target.node;

                if !table_find_pointer(*node_to_bone_remap, node_index) {
                    // TODO I'm not sure if this is right, but some transformations seem to be on node 1 while the skeleton starts on node 2
                    // TODO so I think these transformations are moving the whole body and we don't care about them
                    // TODO otherwise I'm not sure how to calculate the bone hierarchy based on the data gltf provides....
                    // TODO except loop through all channels and get the min and max nodes on top of what I'm already doing which seems awful
                    continue;
                }

                bone_index := << table_find_pointer(*node_to_bone_remap, node_index);

                sampler := current_animation.samplers[sampler_index];
                time_view := get_accessor_view(accessors[sampler.input], "SCALAR");
                interpolation_method := sampler.interpolation;
                transformation_accessor := accessors[sampler.output];

                // TODO I could calculate this all in one loop by only moving forward for each list but its hard
                missing_frame_count := 0;
                for i: 0..time_view.count - 1 {
                    for a: 0..animation.frames[bone_index].count - 1 {
                        if time_view[i] == animation.frames[bone_index][a].frame {
                            continue i;
                        }
                    }

                    missing_frame_count += 1;
                }

                if missing_frame_count > 0 {
                    m_translation, m_rotation, m_scale := decompose_matrix4(animations.bone_hierarchy[bone_index].transform);

                    array_reserve(*animation.frames[bone_index], animation.frames[bone_index].count + missing_frame_count);
                    for i: 0..time_view.count - 1 {
                        insert_index := animation.frames[bone_index].count;
                        for a: 0..animation.frames[bone_index].count - 1 {
                            if animation.frames[bone_index][a].frame == time_view[i] {
                                continue i;
                            } else if animation.frames[bone_index][a].frame > time_view[i] {
                                insert_index = a;
                                break;
                            }
                        }

                        entry: AnimationFrame;
                        entry.frame = time_view[i];
                        entry.translation = m_translation;
                        entry.rotation = m_rotation;
                        entry.scale = m_scale;

                        array_insert_at(*animation.frames[bone_index], entry, insert_index);
                    }
                }

                if channel.target.path == {
                    case "translation";
                        if stationary_bone && animations.bone_hierarchy[bone_index].name == stationary_bone {
                            continue;
                        }

                        translation_view := get_accessor_view(transformation_accessor, "VEC3");
                        assert(translation_view.count == time_view.count, "I think you have to have the same number of transformations for a given node as frames.");

                        for i: 0..time_view.count - 1 {
                            for a: 0..animation.frames[bone_index].count - 1 {
                                if time_view[i] == animation.frames[bone_index][a].frame {
                                    animation.frames[bone_index][a].translation = translation_view[i];
                                    continue i;
                                }
                            }

                            assert(false, "Reached the end of the bone frame loop without finding where to insert the specific frame transform.");
                        }

                    case "rotation";
                        rotation_view := get_accessor_view(transformation_accessor, "QUAT");
                        assert(rotation_view.count == time_view.count, "I think you have to have the same number of transformations for a given node as frames.");

                        for i: 0..time_view.count - 1 {
                            for a: 0..animation.frames[bone_index].count - 1 {
                                if time_view[i] == animation.frames[bone_index][a].frame {
                                    animation.frames[bone_index][a].rotation = rotation_view[i];
                                    continue i;
                                }
                            }

                            assert(false, "Reached the end of the bone frame loop without finding where to insert the specific frame transform.");
                        }

                    case "scale";
                        scale_view := get_accessor_view(transformation_accessor, "VEC3");
                        assert(scale_view.count == time_view.count, "I think you have to have the same number of transformations for a given node as frames.");

                        for i: 0..time_view.count - 1 {
                            for a: 0..animation.frames[bone_index].count - 1 {
                                if time_view[i] == animation.frames[bone_index][a].frame {
                                    animation.frames[bone_index][a].scale = scale_view[i];
                                    continue i;
                                }
                            }

                            assert(false, "Reached the end of the bone frame loop without finding where to insert the specific frame transform.");
                        }

                    case;
                        print("Unhandled animation transformation type. %\n", channel.target.path);
                        assert(false, "Unhandled animation transformation type.");
                }
            }

            calculate_bone_weights(animations, animation);
        }
    }

    return true;
}

calculate_bone_weights :: (animations: ModelAnimations, animation: *Animation) {
    assert(animation.bone_weights.count == 0, "Cannot calculate bone weights they already exist.");

    // iterate through all bones calculating their cumulative delta between frames
    // put these cumulative values in the bone slots
    // add these values together down the hierarchy

    array_resize(*animation.bone_weights, animations.bone_hierarchy.count);

    joints_bones: [..] Matrix4;
    joints_bones.allocator = temp;
    array_reserve(*joints_bones, animations.bone_hierarchy.count);
    joints_bones.count = animations.bone_hierarchy.count;

    largest_frame_count := 0;
    for i: 0..animation.frames.count - 1 {
        largest_frame_count = max(largest_frame_count, animation.frames[i].count);
    }

    // this is the maximum size of the bone with the most frames
    weights: [..] float;
    weights.allocator = temp;
    array_reserve(*weights, largest_frame_count);

    for i: 0..animations.bone_hierarchy.count - 1 {
        joint := animations.bone_hierarchy[i];

        joint_rotation := joint.rotation;

        // each weight is the change between the current bone and the next bone, because they all just get added up at the end anyways
        // we'll also add the base rotation away from the default pose each frame because if you just rotate your body that's still a relevant part of the transformation
        weights.count = animation.frames[i].count;
        memset(weights.data, 0, weights.count * size_of(float));

        frames := animation.frames[i];
        for frame_index: 0..frames.count - 2 {
            current_frame := frames[frame_index];
            
            current_translation := current_frame.translation;
            current_rotation := current_frame.rotation;
            current_scale := current_frame.scale;

            next_frame_index := frame_index + 1;
            next_frame := frames[next_frame_index];
            
            next_translation := next_frame.translation;
            next_rotation := next_frame.rotation;
            next_scale := next_frame.scale;

            radians_between := abs(quat_radians_between(current_rotation, next_rotation));
            // radians_between += abs(quat_radians_between(current_rotation, joint_rotation));
            radians_between *= next_frame.frame - current_frame.frame;
            weights[frame_index] = radians_between;
        }

        cumulative_weight := 0.0;
        for weight: weights {
            cumulative_weight += weight;
            // cumulative_weight += weight * weight;
        }

        animation.bone_weights[i] = cumulative_weight;
    }

    for i: 0..animations.bone_hierarchy.count - 1 {
        joint := animations.bone_hierarchy[i];

        parent_weight := 0.0;
        if joint.parent != i {
            assert(joint.parent < i, "This won't work correctly if the parent is after the current index.");
            parent_weight = animation.bone_weights[joint.parent];
        }

        animation.bone_weights[i] += parent_weight;
    }

    largest_weight := 0.0;
    for i: 0..animations.bone_hierarchy.count - 1 {
        largest_weight = max(largest_weight, animation.bone_weights[i]);
    }

    // we normalize back to [0, 1]
    if largest_weight > 0 {
        for i: 0..animations.bone_hierarchy.count - 1 {
            animation.bone_weights[i] /= largest_weight;
        }
    }
}

get_interpolated_components :: (frames: [..] AnimationFrame, frame: float) -> Vector3, Quaternion, Vector3 {
    assert(frames.count > 0, "Cannot get an interpolated transform if there are no frames.");

    minimum_frame := frames[0].frame;
    maximum_frame := frames[frames.count - 1].frame;
    starting_index := 0;
    ending_index := 0;

    wrapped_frame := fmod_cycling(frame - minimum_frame, maximum_frame - minimum_frame) + minimum_frame;

    i := frames.count - 2;
    while i >= 0 {
        if wrapped_frame >= frames[i].frame {
            starting_index = i;
            ending_index = i + 1;
            break;
        }

        i -= 1;
    }

    assert(starting_index != ending_index, "Could not find the frames that the requested frame is in between.");

    starting_frame := frames[starting_index];
    ending_frame := frames[ending_index];

    starting_frame_time := starting_frame.frame;
    ending_frame_time := ending_frame.frame;

    progress := (wrapped_frame - starting_frame_time) / (ending_frame_time - starting_frame_time);

    starting_translation := starting_frame.translation;
    ending_translation := ending_frame.translation;
    starting_rotation := starting_frame.rotation;
    ending_rotation := ending_frame.rotation;
    starting_scale := starting_frame.scale;
    ending_scale := ending_frame.scale;

    frame_translation := lerp(starting_translation, ending_translation, progress);
    frame_rotation := quat_slerp(starting_rotation, ending_rotation, progress);
    frame_scale := lerp(starting_scale, ending_scale, progress);

    return frame_translation, frame_rotation, frame_scale;
}

get_interpolated_matrix :: (frames: [..] AnimationFrame, frame: float) -> Matrix4 {
    frame_translation, frame_rotation, frame_scale := get_interpolated_components(frames, frame);

    interpolated_matrix := Matrix4Identity;
    interpolated_matrix = translate(interpolated_matrix, frame_translation);
    interpolated_matrix = rotate(interpolated_matrix, frame_rotation);
    interpolated_matrix = scale(interpolated_matrix, frame_scale);

    return interpolated_matrix;
}

precursory_animation_code :: (json: GltfJson, binary: [] u8) -> int, [..] [] u8, [..] [] u8, [..] GltfAccessorInfo, Table(int, int), Table(int, int), [..] int {
    skin_joints: [..] int;
    skin_joints.allocator = temp;

    if !json.skins || json.skins.count == 0 {
        array_reserve(*skin_joints, json.nodes.count);
        for i: 0..json.nodes.count - 1 {
            array_add(*skin_joints, i);
        }
    } else {
        assert(json.skins.count == 1, "I'm not sure how to handle multiple skins.");

        array_reserve(*skin_joints, json.skins.data[0].joints.count);
        for joint_index: json.skins.data[0].joints {
            array_add(*skin_joints, joint_index);
        }
        
        if json.skins.data[0].skeleton {
            skeleton_root_index := << json.skins.data[0].skeleton;
            assert(skeleton_root_index == skin_joints[0], "I'm not sure what it means if the skeleton root is different from the first skin joint.");
        }
    }

    scene := json.scenes[0];

    buffers := get_buffers(json, binary);
    bufferviews := get_bufferviews(json, buffers);
    accessors := get_accessors(json, bufferviews);

    node_to_bone_remap: Table(int, int);
    node_to_bone_remap.allocator = temp;

    bone_to_node_remap: Table(int, int);
    bone_to_node_remap.allocator = temp;

    search_queue: [..] int;
    search_queue.allocator = temp;

    for scene_node_index: 0..scene.nodes.count - 1 {
        array_add(*search_queue, scene.nodes.data[scene_node_index]);
    }

    node_count := 0;
    while search_queue.count > 0 {
        current_node_index := search_queue[0];
        assert(!table_find_pointer(*node_to_bone_remap, current_node_index), "This node entry already exists in the remap.");
        table_set(*node_to_bone_remap, current_node_index, node_count);
        table_set(*bone_to_node_remap, node_count, current_node_index);

        children_pointer := json.nodes[current_node_index].children;
        array_unordered_remove_by_index(*search_queue, 0);

        if children_pointer {
            children := << children_pointer;
            array_add(*search_queue, ..children);
        }

        node_count += 1;
    }

    for node_index: skin_joints {
        assert(!!table_find_pointer(*node_to_bone_remap, node_index), "Did not find all relevant nodes by traversing the node hierarchy.");
    }

    assert(node_count >= skin_joints.count, "The found joint hierarchy count must be the same as or more than the skin inner joints count.");

    return node_count, buffers, bufferviews, accessors, node_to_bone_remap, bone_to_node_remap, skin_joints;
}

#scope_export
