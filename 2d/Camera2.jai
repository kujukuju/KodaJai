Camera2 :: struct {
    position: Vector2;
    rotation: float;
    scale: Vector2 = .{1, 1};
}

get_transform :: (using camera: Camera2) -> Matrix4 {
    screen := xy(cast(float) koda.width, cast(float) koda.height);

    rotation_quat := make_rotation_quaternion(.{0, 0, 1}, rotation);

    matrix := make_scale_matrix4(xyz(scale.x, scale.y, 1.0));
    matrix = translate(matrix, xyz(screen.x / 2.0, screen.y / 2.0, 0.0));
    matrix = rotate(matrix, rotation_quat);
    matrix = translate(matrix, xyz(-position.x, -position.y, 0.0));

    return matrix;
}
