











AnimatedModel :: struct {
    model: *Model;
    animations: ModelAnimations;
    // joints: [] Matrix4;
}

create_animated_model :: (model: *Model, animations: ModelAnimations) -> *AnimatedModel {
    animated_model := New(AnimatedModel);
    animated_model.model = model;
    animated_model.animations = animations;
    return animated_model;
}

destroy :: (animated: *AnimatedModel, children: bool = true) {
    if children {
        destroy(animated.model, children);
        destroy(animated.animations);
    }
    free(animated);
}

draw :: (animated: AnimatedModel, animation: string, frame: float = 0.0, transform: Matrix4 = Matrix4Identity, shader: *Shader = null) {
    draw(animated, animation, frame, transform, get_perspective_matrix(), shader);
}

draw :: (animated: AnimatedModel, animation: string, frame: float = 0.0, transform: Matrix4 = Matrix4Identity, projection: Matrix4, shader: *Shader = null) {
    if !animated.model.geometry {
        return;
    }

    joints := NewArray(animated.animations.joint_indices.count, Matrix4,, allocator = temp);
    get_joints(animated.animations, animation, frame, *joints);

    draw(animated, joints, transform, projection, shader);
}

draw :: (animated: AnimatedModel, mix: [] AnimationMix, transform: Matrix4 = Matrix4Identity, shader: *Shader = null) {
    draw(animated, mix, transform, get_perspective_matrix(), shader);
}

draw :: (animated: AnimatedModel, mix: [] AnimationMix, transform: Matrix4 = Matrix4Identity, projection: Matrix4, shader: *Shader = null) {
    joints := NewArray(animated.animations.joint_indices.count, Matrix4,, allocator = temp);
    get_joints(animated.animations, mix, *joints);

    draw(animated, joints, transform, projection, shader);
}

draw :: (animated: AnimatedModel, joints: [] Matrix4, transform: Matrix4 = Matrix4Identity, shader: *Shader = null) {
    draw(animated, joints, transform, get_perspective_matrix(), shader);
}

draw :: (animated: AnimatedModel, joints: [] Matrix4, transform: Matrix4 = Matrix4Identity, projection: Matrix4, shader: *Shader = null) {
    if shader == null {
        if animated.model.shader {
            shader = animated.model.shader;
        } else {
            shader = get_default_shader(animated.model.geometry[0].attributes);
        }
    }
    assert(!!shader, tprint("Could not find appropriate shader for animated model with attribtues %.\n", animated.model.geometry[0].attributes));

    cull_face := koda.cull_face;
    if cull_face != animated.model.cull_face {
        set_cull_face(animated.model.cull_face);
    }

    use_shader(shader);

    model_mat := transform * get_transform(animated.model);
    view := koda.view;

    apply_uniforms(shader, animated.model.uniforms);

    uniforms: ShaderUniforms;
    defer destroy(uniforms);

    model_view := view * model_mat;
    model_view_projection := projection * model_view;
    set(*uniforms, "modelViewProjection", model_view_projection);
    set(*uniforms, "modelView", model_view);
    set(*uniforms, "projection", projection);
    set(*uniforms, "model", model_mat);
    set(*uniforms, "view", view);

    set(*uniforms, "uJoints", joints);

    apply_uniforms(shader, uniforms);

    glBindVertexArray(animated.model.geometry.vao_);
    glDrawElements(GL_TRIANGLES, xx animated.model.geometry.indices.count, GL_UNSIGNED_INT, xx 0);
    glBindVertexArray(0);

    // TODO if we could avoid calling this gain that would be best
    // TODO but theres no guarantee right now throught all of the koda code that this will be checked
    if cull_face != animated.model.cull_face {
        set_cull_face(cull_face);
    }
}
