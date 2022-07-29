Renderable :: struct {
    type: RenderableType;
    pass_tag: u32;
    render_priority: int;
}

RenderableType :: enum {
    Sprite;
    Container2;
    Model;
    Container3;
}