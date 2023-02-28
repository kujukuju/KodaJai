AnimatedModel :: struct {
    model: *Model;
    animations: [..] Animation;
}

create_animated_model :: (model: *Model, animations: [..] Animation) -> *AnimatedModel {
    animated_model := New(AnimatedModel);
    animated_model.model = model;
    animated_model.animations = animations;
    return animated_model;
}
