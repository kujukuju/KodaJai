AnimatedModel :: struct {
    model: *Model;
    animations: ModelAnimations;
}

create_animated_model :: (model: *Model, animations: ModelAnimations) -> *AnimatedModel {
    animated_model := New(AnimatedModel);
    animated_model.model = model;
    animated_model.animations = animations;
    return animated_model;
}

// load_animated_model :: (path: string) -> [..] *AnimatedModel, bool {

// }

draw :: (animated: AnimatedModel, animation: string, frame: float = 0.0, transform: Matrix4 = Matrix4Identity, shader: *Shader = null) {
    draw(animated, animation, frame, transform, get_perspective_matrix(), shader);
}

draw :: (animated: AnimatedModel, animation: string, frame: float = 0.0, transform: Matrix4 = Matrix4Identity, projection: Matrix4, shader: *Shader = null) {
    if animated.model.geometry.count == 0 {
        return;
    }

    if shader == null {
        if model.shader {
            shader = model.shader;
        } else {
            shader = get_default_shader(animated.model.geometry[0].attributes);
        }
    }

    assert(!!shader, "Could not find appropriate shader for model attributes.");

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
    
    uniforms["projection"] = create_uniform("projection", projection);
    uniforms["model"] = create_uniform("model", model_mat);
    uniforms["view"] = create_uniform("view", view);

    joints := get_joints(animated.animations, animation, frame, 100);

    uniforms["uJoints"] = create_uniform("uJoints", joints);
    
    apply_uniforms(shader, uniforms);

    for geometry: animated.model.geometry {
        glBindVertexArray(geometry.vao_);
        glDrawElements(GL_TRIANGLES, xx geometry.indices.count, GL_UNSIGNED_INT, xx 0);
        glBindVertexArray(0);
    }

    // TODO if we could avoid calling this gain that would be best
    // TODO but theres no guarantee right now throught all of the koda code that this will be checked
    if cull_face != animated.model.cull_face {
        set_cull_face(cull_face);
    }
}

// draw :: (animated: AnimatedModel, mix: [] AnimationMix, frame: float = 0.0, transform: Matrix4 = Matrix4Identity, shader: *Shader = null) {
//     draw(animated, ..mix, frame, transform, shader);
// }

draw :: (animated: AnimatedModel, mix: [] AnimationMix, transform: Matrix4 = Matrix4Identity, shader: *Shader = null) {
    draw(animated, mix, transform, get_perspective_matrix(), shader);
}

// draw :: (animated: AnimatedModel, mix: [] AnimationMix, frame: float = 0.0, transform: Matrix4 = Matrix4Identity, projection: Matrix4, shader: *Shader) {
//     draw(animated, ..mix, frame, transform, projection, shader);
// }

draw :: (animated: AnimatedModel, mix: [] AnimationMix, transform: Matrix4 = Matrix4Identity, projection: Matrix4, shader: *Shader = null) {
    if animated.model.geometry.count == 0 {
        return;
    }

    if shader == null {
        if animated.model.shader {
            shader = animated.model.shader;
        } else {
            shader = get_default_shader(animated.model.geometry[0].attributes);
        }
    }

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
    
    uniforms["projection"] = create_uniform("projection", projection);
    uniforms["model"] = create_uniform("model", model_mat);
    uniforms["view"] = create_uniform("view", view);

    joints := get_joints(animated.animations, mix, 100);

    uniforms["uJoints"] = create_uniform("uJoints", joints);
    
    apply_uniforms(shader, uniforms);

    for geometry: animated.model.geometry {
        glBindVertexArray(geometry.vao_);
        glDrawElements(GL_TRIANGLES, xx geometry.indices.count, GL_UNSIGNED_INT, xx 0);
        glBindVertexArray(0);
    }

    // TODO if we could avoid calling this gain that would be best
    // TODO but theres no guarantee right now throught all of the koda code that this will be checked
    if cull_face != animated.model.cull_face {
        set_cull_face(cull_face);
    }
}
