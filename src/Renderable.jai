Renderable :: struct {
    type: RenderableType;
    pass_tag: u32;
    render_priority: int;
}

RenderableType :: enum {
    Sprite;
    Model;
    InstancedModel;
}