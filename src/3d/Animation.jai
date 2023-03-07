
Animation :: struct {
    name: string;
    world: Matrix4;
    inverse_world: Matrix4;
    // the entire traversed hierarchy of all the bones, some of which aren't included in the skin calculations
    bone_hierarchy: [..] AnimationJoint;
    // these are the indices into the bone_hierarchy that the shader expects as a uniform
    joint_indices: [..] int;
    // the inverse binds only for the respective joint_indices
    inverse_binds: [..] Matrix4;
    // the indices are the bone indices, the inner indices are for the animation frames
    frames: [..][..] AnimationFrame;
}

AnimationJoint :: struct {
    transform: Matrix4 = Matrix4Identity;
    parent: int;
}

AnimationFrame :: struct {
    frame: float;
    translation: Vector3 = .{0, 0, 0};
    rotation: Quaternion = .{0, 0, 0, 1};
    scale: Vector3 = .{1, 1, 1};
}

load_animation :: (path: string) -> [..] Animation, bool {
    file, success := read_entire_file(path);
    defer free(file);
    if !success {
        empty: [..] Animation;
        return empty, false;
    }

    if ends_with(path, ".glb") {
        animations, success := load_animation_glb(file);
        if !success {
            empty: [..] Animation;
            return empty, false;
        }

        return animations, true;
    } else if ends_with(path, ".gltf") {
        animations, success := load_animation_gltf(file, path);
        if !success {
            empty: [..] Animation;
            return empty, false;
        }

        return animations, true;
    } else {
        print("Unknown file type. %\n", path);
        empty: [..] Animation;
        return empty, false;
    }
}

get_joints :: (animations: [..] Animation, name: string, frame: float, $count: int) -> [count] Matrix4 {
    for animation: animations {
        if animation.name == name {
            return get_joints(animation, frame, count);
        }
    }

    assert(false, "Unknown animation name.");

    empty: [count] Matrix4;
    return empty;
}

get_joints :: (animation: Animation, frame: float, $count: int) -> [count] Matrix4 {
    get_interpolated :: (frames: [..] AnimationFrame, frame: float) -> Matrix4 {
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

        interpolated_matrix := Matrix4Identity;
        interpolated_matrix = translate(interpolated_matrix, frame_translation);
        interpolated_matrix = rotate(interpolated_matrix, frame_rotation);
        interpolated_matrix = scale(interpolated_matrix, frame_scale);

        return interpolated_matrix;
    }

    joints_bones: [count] Matrix4;

    for i: 0..animation.bone_hierarchy.count - 1 {
        joint := animation.bone_hierarchy[i];

        // if the joint parent isn't itself then set the parent
        // parent_transform := animation.world;
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
            interpolated_matrix = get_interpolated(animation.frames[i], frame);
        }

        // local_transform := interpolated_matrix;
        joints_bones[i] = parent_transform * interpolated_matrix;
    }

    joints: [count] Matrix4;

    for i: 0..animation.joint_indices.count - 1 {
        real_index := animation.joint_indices[i];
        joints[i] = joints_bones[real_index];
    }

    for i: 0..animation.inverse_binds.count - 1 {
        joints[i] = joints[i] * animation.inverse_binds[i];
        // joints[i] = animation.inverse_world * joints[i];
    }

    return joints;
}

#scope_file

load_animation_glb :: (file: string) -> [..] Animation, bool {
    json, binary, json_memory, valid := load_glb(file);
    defer free(json_memory);
    if !valid {
        empty: [..] Animation;
        return empty, false;
    }

    animations, success := load_animation_gltf_data(json, binary);
    return animations, success;
}

load_animation_gltf :: (file: string, path: string) -> [..] Animation, bool {
    json, binary, json_memory, valid := load_gltf(file, path);
    defer free(json_memory);
    if !valid {
        empty: [..] Animation;
        return empty, false;
    }

    animations, success := load_animation_gltf_data(json, binary);
    return animations, success;
}

load_animation_gltf_data :: (json: GltfJson, binary: [] u8) -> [..] Animation, bool {
    if !json.skins || !json.animations {
        empty: [..] Animation;
        return empty, false;
    }

    assert(json.skins.count == 1, "I'm not sure yet how to handle multiple skins. This is complicated enough as it is.");
    skin := json.skins.data[0];

    assert(json.animations.count == 1, "I'm not sure how to handle multiple animations either.");
    current_animation := json.animations.data[0];

    assert(json.scenes.count == 1, "I'm not sure how to handle multiple scenes.");
    assert(!!json.scenes[0].nodes, "I'm not sure how to handle the root node not being labelled.");
    assert(json.scenes[0].nodes.count == 1, "I'm not sure how to handle multiple node hierarchies.");

    scene_root_node_index := json.scenes[0].nodes.data[0];

    skin_root_node_index := -1;

    node_parents: Table(int, int);
    node_parents.allocator = temp;

    for node, node_index: json.nodes {
        if node.children {
            for i: 0..node.children.count - 1 {
                child_index := node.children.data[i];

                assert(!table_find_pointer(*node_parents, child_index), "Attempting to double set a node parent.");
                table_set(*node_parents, child_index, node_index);
            }
        }

        if node.skin {
            assert(skin_root_node_index == -1, "Attempting to double set the skin root node.");
            skin_root_node_index = node_index;
        }
    }

    assert(skin_root_node_index >= 0, "Could not find the skin root node.");

    skin_root_node_parent_path: [..] int;
    skin_root_node_parent_path.allocator = temp;

    array_add(*skin_root_node_parent_path, skin_root_node_index);
    parent_node_index_pointer := table_find_pointer(*node_parents, skin_root_node_index);
    while !!parent_node_index_pointer {
        array_add(*skin_root_node_parent_path, << parent_node_index_pointer);
        parent_node_index_pointer = table_find_pointer(*node_parents, << parent_node_index_pointer);
    }

    world_transform := Matrix4Identity;

    for < node_index: skin_root_node_parent_path {
        node := json.nodes[node_index];

        node_matrix := get_transform(node);
        world_transform = world_transform * node_matrix;
    }

    buffers := get_buffers(json, binary);
    defer array_free(buffers);

    bufferviews := get_bufferviews(json, buffers);
    defer array_free(bufferviews);

    accessors := get_accessors(json, bufferviews);
    defer array_free(accessors);

    node_to_bone_remap: Table(int, int);
    node_to_bone_remap.allocator = temp;

    bone_to_node_remap: Table(int, int);
    bone_to_node_remap.allocator = temp;

    search_queue: [..] int;
    search_queue.allocator = temp;

    array_add(*search_queue, scene_root_node_index);

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

    for node_index: skin.joints {
        assert(!!table_find_pointer(*node_to_bone_remap, node_index), "Did not find all relevant nodes by traversing the node hierarchy.");
    }

    assert(node_count >= skin.joints.count, "The found joint hierarchy count must be the same as or more than the skin inner joints count.");

    animations: [..] Animation;
    animation := array_add(*animations);
    animation.world = world_transform;
    animation.inverse_world = inverse(world_transform);

    if current_animation.name && current_animation.name.count > 0 {
        animation.name = copy_string(<< current_animation.name);
    }

    array_reserve(*animation.joint_indices, skin.joints.count);
    animation.joint_indices.count = skin.joints.count;
    for i: 0..skin.joints.count - 1 {
        animation.joint_indices[i] = << table_find_pointer(*node_to_bone_remap, skin.joints[i]);
    }

    array_resize(*animation.bone_hierarchy, node_count);

    for bone_index: 0..node_count - 1 {
        node_index := << table_find_pointer(*bone_to_node_remap, bone_index);
        node := json.nodes[node_index];

        animation.bone_hierarchy[bone_index].transform = get_transform(node);

        // every child should have a prent except the root node which is 0 so its a parent to itself
        // so we don't have to worry about this
        if node.children {
            for i: 0..node.children.count - 1 {
                child_node_index := node.children.data[i];
                child_bone_index := << table_find_pointer(*node_to_bone_remap, child_node_index);

                assert(animation.bone_hierarchy[child_bone_index].parent == 0, "Attempting to double set a childs parent.");
                animation.bone_hierarchy[child_bone_index].parent = bone_index;
            }
        }
    }

    array_reserve(*animation.inverse_binds, skin.joints.count);
    animation.inverse_binds.count = skin.joints.count;

    // fill up the inverse bind matrices
    if skin.inverseBindMatrices {
        matrix_accessor := get_accessor_view(accessors[<< skin.inverseBindMatrices], "MAT4");
        assert(matrix_accessor.count == skin.joints.count, "I think you must have the same number of inverse binds as inner joints.");

        for i: 0..matrix_accessor.count - 1 {
            animation.inverse_binds[i] = transpose(matrix_accessor[i]);
        }
    } else {
        for i: 0..skin.joints.count - 1 {
            animation.inverse_binds[i] = Matrix4Identity;
        }
    }

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

        if animation.frames[bone_index].count == 0 {
            m_translation, m_rotation, m_scale := decompose_matrix4(animation.bone_hierarchy[bone_index].transform);

            m_rotation = normalize(m_rotation);
            if m_rotation.w < 0 {
                m_rotation *= -1;
            }

            array_resize(*animation.frames[bone_index], time_view.count);
            for i: 0..time_view.count - 1 {
                animation.frames[bone_index][i].frame = time_view[i];
                animation.frames[bone_index][i].translation = m_translation;
                animation.frames[bone_index][i].rotation = m_rotation;
                animation.frames[bone_index][i].scale = m_scale;
            }
        } else {
            assert(animation.frames[bone_index].count == time_view.count, "If the frames have already been initialized the count can't change.");
        }

        assert(animation.frames[bone_index].count == time_view.count, "I expect that every transformation for a given bone has the same number of frames.");

        if channel.target.path == {
            case "translation";
                translation_view := get_accessor_view(transformation_accessor, "VEC3");
                assert(translation_view.count == time_view.count, "I think you have to have the same number of transformations for a given node as frames.");

                for i: 0..time_view.count - 1 {
                    animation.frames[bone_index][i].translation = translation_view[i];
                }

            case "rotation";
                rotation_view := get_accessor_view(transformation_accessor, "QUAT");
                assert(rotation_view.count == time_view.count, "I think you have to have the same number of transformations for a given node as frames.");

                for i: 0..time_view.count - 1 {
                    animation.frames[bone_index][i].rotation = normalize(rotation_view[i]);
                    if animation.frames[bone_index][i].rotation.w < 0 {
                        animation.frames[bone_index][i].rotation *= -1;
                    }
                }

            case "scale";
                scale_view := get_accessor_view(transformation_accessor, "VEC3");
                assert(scale_view.count == time_view.count, "I think you have to have the same number of transformations for a given node as frames.");

                for i: 0..time_view.count - 1 {
                    animation.frames[bone_index][i].scale = scale_view[i];
                }

            case;
                print("Unhandled animation transformation type. %\n", channel.target.path);
                assert(false, "Unhandled animation transformation type.");
        }
    }

    return animations, true;
}

#scope_export
