Container2 :: struct {
    using #as renderable: Renderable;
    renderables: [..] *Renderable;
    position: Vector2;
    rotation: float;
}

destroy_container :: (container: Container2, destroy_children: bool = false) {
    if destroy_children {
        for child: container.renderables {
            if #complete child.type == {
                case .Sprite;
                    destroy_sprite(<< cast(*Sprite) child);
                case .Container2;
                    destroy_container(<< cast(*Container2) child);
                case .Model;
                    destroy_model(<< cast(*Model) child);
                case .Container3;
                    destroy_container(<< cast(*Container3) child);
            }
        }
    }

    array_free(container.renderables);
}

add_child :: (container: *Container2, renderable: *$T/Renderable) {
    array_add(*container.renderables, renderable);
}

remove_child :: (container: *Container2, renderable: *$T/Renderable) {
    array_ordered_remove_by_value(*container.renderables, renderable);
}

draw :: (container: Container2) {
    for child: container.renderables {
        if #complete child.type == {
            case .Sprite;
                draw(<< cast(*Sprite) child);
            case .Container2;
                draw(<< cast(*Container2) child);
            case .Model;
                draw(<< cast(*Model) child);
            case .Container3;
                draw(<< cast(*Container3) child);
        }
    }
}