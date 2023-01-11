Pipeline :: struct {
    passes: [] Pass;
    renderables: [..] *Renderable;
}

add_renderable :: (pipeline: *Pipeline, renderable: *Renderable) {
    array_add(*pipeline.renderables, renderable);
}

remove_renderable :: (pipeline: *Pipeline, renderable: *Renderable) {
    array_ordered_remove_by_value(*pipeline.renderables, renderable);
}

draw :: (pipeline: Pipeline) {
    for pass: pipeline.passes {
        draw(pass, pipeline.renderables);
    }
}
