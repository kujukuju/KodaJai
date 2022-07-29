Pass :: struct {
    shader: *Shader;
    textures: [] *Texture;
    render_texture: [] *RenderTexture;
    pass_tags: u32;
}

draw :: (pass: Pass, renderables: [..] *Renderable) {
    for child: renderables {
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
