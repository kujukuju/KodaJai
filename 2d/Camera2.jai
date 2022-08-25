Camera2 :: struct {
    position: Vector2;
    rotation: float;
}

get_transform :: (using camera: Camera2) -> Matrix4 {
    quat := make_rotation_quaternion(.{0, 0, 1}, rotation);

    matrix: Matrix4 = Matrix4_Identity;
    matrix = rotate(matrix, quat);
    matrix = translate(matrix, -xyz(position.x, position.y, 0.0));

    return matrix;
}
