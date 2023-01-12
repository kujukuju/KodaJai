Container3 :: struct {
    using #as renderable: Renderable;
    renderable.type = .Container3;
    renderables: [..] *Renderable;
    position: Vector3;
    rotation: Quaternion;
}

destroy_container :: (container: Container3, destroy_children: bool = false) {
    if destroy_children {
        for child: container.renderables {
            if #complete child.type == {
                case .Sprite;
                    destroy_sprite(<< cast(*Sprite) child);
                case .Container2;
                    destroy_container(<< cast(*Container2) child, destroy_children);
                case .Model;
                    destroy_model(<< cast(*Model) child);
                case .Container3;
                    destroy_container(<< cast(*Container3) child, destroy_children);
            }
        }
    }

    array_free(container.renderables);
}

add_child :: (container: *Container3, renderable: *$T/Renderable) {
    array_add(*container.renderables, renderable);
}

remove_child :: (container: *Container3, renderable: *$T/Renderable) {
    array_ordered_remove_by_value(*container.renderables, renderable);
}

draw :: (container: Container3, transform: Matrix4 = Matrix4Identity) {
    applied := rotate(transform, container.rotation);
    applied = translate(applied, container.position);

    // TODO relative offsets
    for child: container.renderables {
        if #complete child.type == {
            case .Sprite;
                draw(<< cast(*Sprite) child, applied);
            case .Container2;
                draw(<< cast(*Container2) child, applied);
            case .Model;
                draw(<< cast(*Model) child, applied);
            case .Container3;
                draw(<< cast(*Container3) child, applied);
        }
    }
}