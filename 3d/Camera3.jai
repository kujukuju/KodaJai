Camera3 :: struct {
    position: Vector3;
    rotation: Quaternion;
}

get_transform :: (using camera: Camera3) -> Matrix4 {
    matrix: Matrix4 = Matrix4_Identity;
    matrix = rotate(matrix, rotation);
    matrix = translate(matrix, -position);

    return matrix;
}

get_forward_vector :: (using camera: Camera3) -> Vector3 {
    forward := rotate(Vector3.{0, 0, -1}, conjugate(rotation));

    return forward;
}

get_up_vector :: (using camera: Camera3) -> Vector3 {
    up := rotate(Vector3.{0, 1, 0}, conjugate(rotation));

    return up;
}

get_right_vector :: (using camera: Camera3) -> Vector3 {
    right := rotate(Vector3.{1, 0, 0}, conjugate(rotation));

    return right;
}

look_at :: (using camera: *Camera3, target: Vector3) {
    assert(false, "This doesn't seem to work in the way I want.");
    look_at_matrix := make_look_at_matrix(position, target, .{0, 1, 0}, false);
    rotation = get_rotation(look_at_matrix);
}
