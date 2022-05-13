Camera2 :: struct {
    transform: Matrix4;
}

get_position :: (using camera: *Camera2) -> Vector2 {
    // position := Vector4;
    position := multiply(transform, .{0, 0, 0, 0});

    return position.xy;
}



